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

On a fresh Ubuntu Server 24.04 install:

```bash
git clone <this-repo-url> constellation
cd constellation
sudo ./platform-install-Ubuntu.sh
```

The installer will:

1. Validate the OS and check disk/RAM/port pre-conditions
2. Update apt packages and install system dependencies
3. Install and configure SSH (see [SSH](#ssh) below)
4. Install Docker Engine and the Docker Compose plugin
5. Create required data/log directories
6. Generate `.env` from `.env.example` (with a strong Postgres password)
7. Deploy the platform with Docker Compose
8. Run protocol-level health checks against every service (not just
   container status) and print a summary
9. Enable the weekly backup timer

No manual Docker (or SSH, or backup-scheduling) commands are required
after installation. For everything that's still a manual, human-judgment
step (verifying SSH access out-of-band, deciding on a VM snapshot,
reviewing the installer before trusting it with root, reboot verification,
upgrades, etc.), see **[docs/20-deployment-checklist.md](docs/20-deployment-checklist.md)**.

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

Weekly automated backups are enabled by the installer itself
(`constellation-backup.timer`) — no separate step needed after install.

```bash
./scripts/backup.sh                 # run a one-off backup any time
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
