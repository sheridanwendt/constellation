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

- `postgres.sql` — `pg_dump` of the PostgreSQL database
- `qdrant_storage.tar.gz` — archive of `qdrant_storage/`
- `configs.tar.gz` — archive of `.env`, `docker-compose.yml`, and `config/`

This is a simple point-in-time snapshot, not a full backup system — there is
no scheduling, retention, or restore automation yet. `backups/` is
gitignored; copy it somewhere durable (off this machine) if it needs to
survive a disk failure. `configs.tar.gz` contains `.env`, so treat it as a
secret.

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
- Scheduled/automated backups and retention
- Update / upgrade tooling
- Deeper diagnostics
