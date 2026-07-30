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

1. Validate the OS
2. Install system dependencies
3. Install Docker Engine and the Docker Compose plugin
4. Create required data/log directories
5. Generate `.env` from `.env.example` (with a strong Postgres password)
6. Deploy the platform with Docker Compose
7. Wait for all services to report healthy and print a summary

No manual Docker commands are required after installation.

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

```bash
./scripts/backup.sh                 # one-off backup
sudo ./scripts/schedule-backups.sh  # enable automatic weekly backups
```

Kept to a 10%-of-disk / 52-week rolling budget, with the first backup ever taken
retained permanently. See `docs/09-operations.md` for the full policy.

## Keeping the Installer Up to Date

```bash
sudo ./scripts/audit-enable.sh  # once: capture ad hoc commands run on the host
./scripts/audit-review.sh       # periodically: review what should be folded into scripts/install/
```

Since `platform-install-Ubuntu.sh` is the source of truth for rebuilding
the platform, this closes the loop on manual fixes/tweaks that would
otherwise be lost on a rebuild. See `docs/09-operations.md` for details.

See `docs/09-operations.md` for full operational details.

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
