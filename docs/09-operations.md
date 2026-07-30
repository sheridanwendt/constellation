# Operations

Constellation should be rebuildable from scratch.

The system supports:

- Fresh Ubuntu installation
- Automated dependency installation
- Container deployment
- Data restoration
- Health checks

## Recovery Goal

A new machine is recoverable using:

- This repository
- `platform-install-Ubuntu.sh` and `scripts/install/`
- The `data/` directories restored from backup (`postgres_data/`, `qdrant_storage/`, `data/nats/`)
- A `.env` file (generated fresh, or restored from a secure backup)

## Fresh Install

```bash
git clone <this-repo-url> constellation
cd constellation
sudo ./platform-install-Ubuntu.sh
```

This runs, in order:

1. `scripts/install/01-system-dependencies.sh` — base apt packages
2. `scripts/install/02-docker.sh` — Docker Engine + Compose plugin
3. `scripts/install/03-directories.sh` — persistent data/log directories
4. `scripts/install/04-config.sh` — generates `.env` from `.env.example`
5. `scripts/install/05-deploy-platform.sh` — `docker compose up -d` and health-check wait

Installer output is also written to `logs/install-<timestamp>.log`.

## Starting

```bash
./scripts/start.sh
```

Equivalent to `docker compose up -d`.

## Stopping

```bash
./scripts/stop.sh
```

Equivalent to `docker compose stop`. Containers are stopped but not removed;
data volumes are untouched.

## Restarting

```bash
./scripts/restart.sh
```

## Health Checks

```bash
./scripts/status.sh
```

Shows `docker compose ps` output plus the Docker healthcheck status
(`healthy` / `unhealthy` / `starting`) for each service. All three services
(`constellation-postgres`, `constellation-qdrant`, `constellation-nats`)
define container-level healthchecks in `docker-compose.yml`.

## Logs

```bash
./scripts/logs.sh            # all services, follow mode
./scripts/logs.sh postgres   # single service
./scripts/logs.sh qdrant
./scripts/logs.sh nats
```

Container logs are also rotated automatically via the `json-file` logging
driver (`max-size: 10m`, `max-file: 3`) configured in `docker-compose.yml`.

## Backups

```bash
./scripts/backup.sh
```

Writes a timestamped backup to `backups/<timestamp>/`:

- `postgres.sql.gz` — gzipped `pg_dump` of the PostgreSQL database
- `qdrant_storage.tar.gz` — archive of `qdrant_storage/`
- `configs.tar.gz` — archive of `.env`, `docker-compose.yml`, and `config/`

This is still a simple point-in-time snapshot, not a full backup system —
there is no restore automation yet. `backups/` is gitignored; copy it
somewhere durable (off this machine) if it needs to survive a disk failure.
`configs.tar.gz` contains `.env`, so treat it as a secret.

### Automatic weekly backups

```bash
sudo ./scripts/schedule-backups.sh
```

Installs a systemd service + timer (`constellation-backup.service` /
`.timer`) that runs `scripts/backup.sh` weekly, with `Persistent=true` so a
missed run (machine off) catches up on next boot.

```bash
systemctl status constellation-backup.timer      # check schedule
systemctl list-timers constellation-backup.timer  # next run time
journalctl -u constellation-backup.service        # backup run logs
sudo systemctl disable --now constellation-backup.timer  # turn off
```

### Retention policy

Backups are capped at **50GB total** (`BACKUP_MAX_TOTAL_GB` in `.env`,
default `50`) and **52 rotating backups** (`BACKUP_RETENTION_COUNT`,
default `52`, i.e. a year of weekly backups). Every run of
`scripts/backup.sh`:

1. The **first backup ever taken** is marked permanent (recorded in
   `backups/.permanent`) and is never auto-deleted.
2. If more than `BACKUP_RETENTION_COUNT` non-permanent backups exist, the
   oldest are removed until back within the limit.
3. If total size in `backups/` still exceeds `BACKUP_MAX_TOTAL_GB`, the
   oldest non-permanent backups are removed further, even below the count
   limit, until back within budget (or only the permanent backup remains).

Both limits are configurable in `.env` without editing the script.

### Approximate backup size

In Phase 1 (no platform/agent data yet), each backup is a few MB at most —
mostly the Qdrant/Postgres empty-instance overhead and the small config
archive. Size will grow with real usage in later phases, roughly:

- **PostgreSQL**: proportional to rows of operational data (tasks, users,
  configuration) — plain-text SQL, gzipped, typically small relative to
  vector data for a single-user deployment.
- **Qdrant**: dominated by embeddings — roughly `dimensions × 4 bytes`
  per vector plus index overhead (~1.5–2x), e.g. ~100k vectors at 1536
  dimensions is on the order of several hundred MB.

At 53 retained backups (1 permanent + 52 weekly) and a 50GB budget, that's
an average of just under **1GB per backup** available before the oldest
rotating backups start getting pruned early to stay under budget — ample
headroom for a single-user Phase 1/2 deployment on this hardware.

## Data Locations

| Directory          | Contents                         |
|---------------------|-----------------------------------|
| `postgres_data/`    | PostgreSQL data directory          |
| `qdrant_storage/`    | Qdrant collections/storage         |
| `data/nats/`         | NATS JetStream store                |
| `logs/`              | Installer run logs                  |

All of the above are excluded from git via `.gitignore`.

## Container Naming

Containers use a `constellation-` prefix (`constellation-postgres`,
`constellation-qdrant`, `constellation-nats`) so they are unambiguous
alongside other Docker workloads on the same host.

## Future Operational Tools

Not yet implemented; planned for a later phase:

- Restore automation (from `scripts/backup.sh` output)
- Update / upgrade tooling
- Deeper diagnostics
