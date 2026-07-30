# ADR-0006: Canonical Install Location

Status:

Accepted


# Decision

`platform-install-Ubuntu.sh` always installs Constellation to
`/opt/constellation`, regardless of where the operator cloned the
repository or what directory they invoked the installer from.

If the script isn't already running from `/opt/constellation`, it:

1. Refuses and asks the operator to resolve it manually if
   `/opt/constellation` already exists and doesn't look like a
   Constellation checkout (no `platform-install-Ubuntu.sh` there).
2. Otherwise, copies the current checkout's tracked files and any
   uncommitted local changes into `/opt/constellation` — excluding
   runtime data/log/backup directories and `.env` (secrets and data are
   never carried across; the canonical location manages its own).
3. Re-execs itself from `/opt/constellation`, so every install step from
   that point on operates against one consistent, predictable path.

The override `CONSTELLATION_HOME` environment variable exists for testing
but is not part of the supported interface.


# Reasoning

Per `CLAUDE.md`: "the installer is the source of truth" and deployments
must be reproducible. Before this change, where Constellation actually
lived on disk (and therefore where `postgres_data/`, `qdrant_storage/`,
`backups/`, `.env`, etc. ended up) depended entirely on wherever the
operator happened to run `git clone`. Two deployments of the "same"
installer could disagree on install path, which makes automation
(scheduled backups, future tooling, documentation, support) harder to
reason about, and violates the "consistent (default preferred) location"
requirement identified during the Phase 1 deployment-experience review
(2026-07).

`/opt` is the standard FHS location for add-on application software on a
dedicated host, which matches Constellation's Phase 1 target (a single,
mostly-dedicated machine — `docs/15-resource-planning.md`).


# Why Copy-and-Re-exec, Not "Require Cloning to /opt"

An alternative was to simply document "clone to `/opt/constellation`" and
fail if the operator didn't. That fails the actual requirement: "no matter
what dir the CLI is in ... it will always execute without error." Cloning
to an arbitrary location and running the installer from there is a
realistic, common path (e.g. cloning to `~/constellation` first to review
it, per `docs/20-deployment-checklist.md` step 6), and the installer
should absorb that instead of erroring out.

Copying (not moving) the original checkout leaves it intact — nothing is
deleted from wherever the operator originally cloned to.


# Non-Goals

- No support for relocating an *existing, already-canonical* install to a
  different path. If you want Constellation somewhere other than
  `/opt/constellation`, that's a manual, deliberate choice outside the
  supported flow for now.
- No attempt to merge divergent installs if `/opt/constellation` already
  contains a different, unrelated Constellation checkout (e.g. a
  different branch/fork) — the installer only ever overwrites
  tracked-file-shaped content there, never deletes, and never guesses
  which of two conflicting checkouts should win.
