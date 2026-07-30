# Constellation

A local-first, modular, containerized AI agent platform.

## Vision

Constellation provides the infrastructure for building, running, and evolving ecosystems of collaborating AI agents. It is not a chatbot, a single assistant, or an LLM wrapper — it is infrastructure for operating multiple AI agents.

The platform supports:

- Multiple AI agent frameworks
- Shared skills
- Shared memory
- Event-driven communication
- Local deployment
- Cloud migration

See `/docs` for full architecture and design documentation.

## Phase 1 Status

**Phase 1 — Infrastructure Foundation** is implemented.

Phase 1 delivers a reproducible, local-first installation that stands up the
core infrastructure services (PostgreSQL, Qdrant, NATS) via a single
installer script and Docker Compose. It does **not** implement agents,
skills, connectors, or the platform API layer — those are later phases (see
`docs/05-project-plan.md`).

## Hardware Assumptions

Phase 1 targets:

- Dell Optiplex 3040 (or similar)
- Ubuntu Server 24.04 LTS
- 16GB RAM
- 500GB HDD

Default resource limits (see `.env.example`) are sized conservatively to
leave headroom on this hardware.

## Installation

On a fresh Ubuntu Server 24.04 install, clone anywhere convenient — the
installer normalizes the install location for you (see
[Install Location](#install-location) below):

```bash
git clone <this-repo-url> constellation
cd constellation
sudo ./platform-install-Ubuntu.sh
```

This works the same way no matter what directory you're in when you run
it, and no matter where you cloned to. The installer will:

0. Relocate itself to the canonical install location if not already
   there (`/opt/constellation` by default), then continue from there
1. Take an `initial` backup checkpoint before touching anything
2. Validate the OS and check disk/RAM/port pre-conditions
3. Update apt packages and install system dependencies
4. Install and configure SSH (see [SSH](#ssh) below)
5. Install Docker Engine and the Docker Compose plugin
6. Create required data/log directories
7. Generate `.env` from `.env.example` (with a strong Postgres password)
8. Take a `dependencies` backup checkpoint (host prepared, platform not
   deployed yet)
9. Deploy the platform with Docker Compose
10. Run protocol-level health checks against every service (not just
    container status)
11. Enable the weekly backup timer
12. Take a final `constellation` backup checkpoint and print a summary

No manual Docker (or SSH, backup-scheduling, or install-location) commands
are required after installation. For everything that's still a manual,
human-judgment step (verifying SSH access out-of-band, deciding on a VM
snapshot, reviewing the installer before trusting it with root, reboot
verification, upgrades, etc.), see
**[docs/20-deployment-checklist.md](docs/20-deployment-checklist.md)**.

## Install Location

Constellation always ends up installed at **`/opt/constellation`**,
regardless of where you cloned the repo or what directory you ran
`sudo ./platform-install-Ubuntu.sh` from. If you didn't clone directly to
`/opt/constellation`, the installer copies the checkout there (leaving
your original clone untouched) and re-runs itself from that canonical
path before doing anything else.

This means:

- Every deployment lands in the same place, so data locations, backups,
  and any future tooling can assume a fixed path instead of guessing.
- All the `./scripts/*.sh` helpers work from anywhere once installed —
  they resolve their own location rather than relying on your current
  directory.

See [ADR-0006](docs/adr/0006-canonical-install-location.md) for the full
reasoning.

## SSH

`platform-install-Ubuntu.sh` ensures `openssh-server` is installed and
running, and generates two key pairs:

- A dedicated automation/deploy key at
  `/etc/constellation/ssh/deploy_ed25519` for future non-interactive use
  (not authorized for login anywhere by default).
- A personal login key for the operator running the installer
  (`~/.ssh/id_ed25519`), added to that user's own `authorized_keys`.

It deliberately leaves **both password and public-key login enabled** —
it only ever adds a login method, never removes one. See
[ADR-0005](docs/adr/0005-ssh-bootstrap.md) for the full reasoning and why
hardening (disabling password auth) is intentionally left as a separate,
explicit, human-initiated action rather than something the installer does
on its own.

## Starting the Platform

```bash
./scripts/start.sh
```

## Stopping the Platform

```bash
./scripts/stop.sh
```

Data is preserved in `postgres_data/`, `qdrant_storage/`, and `data/nats/`.

## Restarting the Platform

```bash
./scripts/restart.sh
```

## Checking Health

```bash
./scripts/status.sh
./scripts/logs.sh          # all services
./scripts/logs.sh postgres # single service
```

## Backups

The installer takes three named checkpoint backups automatically during
every install — `initial` (before anything is touched, becomes the
permanent baseline), `dependencies` (host prepared, platform not deployed
yet), and `constellation` (fully deployed and verified) — plus enables the
weekly automated timer (`constellation-backup.timer`). No separate step
needed after install.

```bash
./scripts/backup.sh                 # run a one-off backup any time
./scripts/backup.sh my-label        # optional label (letters/digits/-/_)
                                     # for a human-readable checkpoint name
sudo ./scripts/schedule-backups.sh  # re-run standalone, e.g. after changing
                                     # BACKUP_* settings in .env
```

Kept to a 10%-of-disk / 52-week rolling budget, with the first backup ever taken
retained permanently. See `docs/09-operations.md` for the full policy.

## Installer Feedback Loop

**Why it exists:** per `CLAUDE.md`, `platform-install-Ubuntu.sh` is the
source of truth for rebuilding Constellation from scratch. But real
administration happens on the running host too — a one-off `apt install`,
a config tweak, a firewall rule — and none of that gets captured unless
something is watching. Left alone, that drift means a from-scratch rebuild
silently *doesn't* reproduce the box you're actually running. This is how
the installer is meant to get more complete after every real deployment,
not just at design time.

**When to enable it:** once, right after a successful install:

```bash
sudo ./scripts/audit-enable.sh
```

This installs a small `/etc/profile.d/` hook that logs every interactive
shell command (timestamp, user, working directory) to
`logs/command-audit.log`. It's a development aid, not a security/compliance
tool — avoid typing secrets on the command line while it's on, and turn it
off with `sudo ./scripts/audit-disable.sh` if you don't want it running.

**When to review it:** periodically, whenever you've done any hands-on
administration since the last review:

```bash
./scripts/audit-review.sh
```

This filters out routine/read-only noise (`cd`, `ls`, `git status`, …),
dedupes and counts what's left, flags (`✓`) anything that already exists
somewhere under `scripts/install/`, and suggests which script a new
candidate likely belongs in. Use `--all` to see the unfiltered raw log.

**How it improves Constellation over time:** for each surviving candidate,
you make an explicit human call — fold it into the right
`scripts/install/0X-*.sh` (or another automation script) and re-run the
installer end-to-end to confirm it's still idempotent, or decide it was
genuinely one-off and leave it out. Nothing is applied automatically; the
loop only ever proposes, a person always decides. That's what keeps the
installer honest as the single source of truth instead of just one more
place configuration can drift from reality.

See [docs/20-deployment-checklist.md](docs/20-deployment-checklist.md) for
where this fits in the full deployment checklist, and
`docs/09-operations.md` for full operational details.

## Current Services

| Service    | Purpose                     | Default Address              |
|------------|------------------------------|-------------------------------|
| PostgreSQL | Operational data             | `127.0.0.1:5432`               |
| Qdrant     | Vector / semantic storage     | `http://127.0.0.1:6333`        |
| NATS       | Event bus (JetStream enabled) | `nats://127.0.0.1:4222`        |

## Repository Structure

```
platform/    Core platform services (Phase 2+)
services/    Supporting infrastructure services
agents/      Agent implementations (future)
skills/      Reusable platform skills (future)
connectors/  External interface connectors (future)
knowledge/   Shared knowledge sources (future)
config/      Service configuration files
scripts/     Installation and operations scripts
tests/       Automated tests
docs/        Architecture and design documentation
```
