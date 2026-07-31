# ADR-0007: Installer Status Framework, Fail-Fast, and the BOM Incident

Status:

Accepted


# Background: What Actually Happened

The first real deployment attempt (2026-07-31, fresh Ubuntu Server 24.04)
ran every step through `scripts/install/05-config.sh` successfully -
`.env` was created at the correct canonical location with a real,
generated `POSTGRES_PASSWORD`. It then died with:

```
.env: line 1: ﻿#: command not found
```

Root cause: `.env.example` carried a UTF-8 byte-order-mark (BOM) as its
first three bytes, ahead of the `#` comment on line 1. `cp .env.example
.env` copied it through verbatim. `scripts/backup.sh`'s `dependencies`
checkpoint then did `source .env` under `set -euo pipefail`; bash doesn't
recognize a BOM-prefixed `#` as a comment, tried to execute the BOM+`#`
bytes as a command, got "command not found" (exit 127), and `errexit`
killed the installer on the spot.

Two things made this worse than the bug itself:

1. **It failed silently.** No `[FAIL]` line, no summary, no indication the
   install had stopped rather than finished. The log just ends. The
   operator had to go looking for logs that didn't clearly say what
   happened or whether it was safe to re-run.
2. **`docker compose config` would not have caught it.** Verified
   empirically: Compose's own `.env` parser tolerates a BOM silently. Only
   bash's `source` chokes on it - meaning general "does compose parse this
   ini file" validation gives false confidence for this specific class of
   bug.


# Decision

## 1. Fix the actual bug

- Stripped the BOM from `.env.example`.
- `scripts/lib/common.sh` gained `strip_bom_if_present()` and
  `safe_source_env()`. Every place that sources a `.env` file
  (`scripts/backup.sh`, `scripts/doctor.sh`) uses `safe_source_env`
  instead of a bare `source`.
- `05-config.sh` calls `strip_bom_if_present` on the `.env` it just
  wrote/found unconditionally - including the "already exists, leaving it
  untouched" path, so a `.env` left over from a run that hit this exact
  bug self-heals on the next install run instead of staying broken forever.

## 2. A standardized step status framework

`scripts/lib/report.sh` (new) gives every installer step exactly one of
four statuses - **SUCCESS**, **WARNING**, **FAILED**, **SKIPPED** - derived
from the step's exit code plus whether it printed any `log_warn()`
`[WARN]` line. `platform-install-Ubuntu.sh` and `scripts/doctor.sh` both
collect these into one report instead of each inventing their own ad hoc
pass/fail signal.

## 3. Fail-fast, with visible skips

`platform-install-Ubuntu.sh` now stops attempting further work the moment
a step reports FAILED - but every step and checkpoint that would have run
afterward is explicitly recorded as SKIPPED rather than just silently
never appearing. The report always shows the full planned sequence: what
ran, what passed, what failed, and what was never attempted because of it.

## 4. Every stage validates its own output

`05-config.sh` now checks its own `.env` (exists, real password,
BOM-free, safely sourceable, and passes `docker compose config`) before
reporting success - directly closing the gap that let this bug travel two
steps downstream before surfacing. `06-deploy-platform.sh` explicitly
checks the containers it just started actually exist, not just that they
eventually report healthy. `07-verify.sh` already did protocol-level
checks against each service; it's unchanged in substance, just now
sharing its check logic with `scripts/doctor.sh` via `scripts/lib/checks.sh`.

## 5. One report, two forms, one shared engine

`report.sh` produces exactly one human-readable summary
(`report_print_human_summary`, grouped as Overall / Infrastructure /
Docker / Configuration / Platform Services / Verification / Backups /
Warnings / Recommendations) and one machine-readable one
(`report_write_json`, deliberately dependency-free - no `jq`/python -
since it must still work if an early step that would install `jq` is
itself the one that failed). `platform-install-Ubuntu.sh` prints exactly
one summary at the end; there is no separate legacy summary block.
`scripts/doctor.sh` reuses the identical engine and check functions
(`scripts/lib/checks.sh`), so its output is directly comparable to the
installer's.

## 6. A last-resort safety net

`report_emergency_summary_trap`, registered via `trap ... EXIT`, prints
whatever was recorded so far if the script exits without ever reaching
`report_print_human_summary` - i.e. a genuinely unexpected crash (a bug,
not a normal fail-fast stop, which always finalizes the report first).
This exists specifically so a repeat of "the log just stops with no
explanation" is structurally harder to produce, even for a failure mode
nobody anticipated.


# Consequences

- Every future `scripts/install/*.sh` step, and any future installer
  (Hermes, Athena, etc.) that sources `scripts/lib/report.sh`, gets
  status tracking, timing, a human summary, and JSON output for free
  without reimplementing any of it.
- `scripts/doctor.sh` can diagnose an existing deployment using the exact
  same check logic the installer validates itself with, instead of a
  second, potentially-drifted implementation.
- Reporting a failure clearly is not a substitute for fixing it - the BOM
  itself is fixed at its source, not just reported better.
