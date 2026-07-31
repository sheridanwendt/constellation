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

This works regardless of what directory you're in or where you cloned to
— see [Install Location](#install-location) below. It then runs, in
order:

- **Relocate** to the canonical install location
  (`/opt/constellation` by default) if not already there, and re-exec
  from there (see [ADR-0006](adr/0006-canonical-install-location.md))
- **Backup checkpoint `initial`** — `scripts/backup.sh initial`, before
  anything is touched (becomes the permanent baseline; see
  [Backups](#backups))
0. `scripts/install/00-preflight.sh` — validates disk space, RAM, and that
   required ports are free before touching anything
1. `scripts/install/01-system-dependencies.sh` — `apt-get update`/`upgrade`,
   base apt packages
2. `scripts/install/02-ssh.sh` — installs/enables `openssh-server`, keeps
   both password and public-key auth enabled, generates the deploy and
   operator login keys (see [ADR-0005](adr/0005-ssh-bootstrap.md))
3. `scripts/install/03-docker.sh` — Docker Engine + Compose plugin
4. `scripts/install/04-directories.sh` — persistent data/log directories
5. `scripts/install/05-config.sh` — generates `.env` from `.env.example`
- **Backup checkpoint `dependencies`** — `scripts/backup.sh dependencies`,
  host prepared but the platform isn't deployed yet
6. `scripts/install/06-deploy-platform.sh` — `docker compose up -d` and
   container-health-check wait
7. `scripts/install/07-verify.sh` — protocol-level smoke test against each
   service (real query/API call, not just container health status)
8. `scripts/install/08-schedule-backups.sh` — enables the weekly backup
   timer (see [Backups](#backups) below)
- **Backup checkpoint `constellation`** — `scripts/backup.sh constellation`,
  the platform is fully deployed and verified

Installer output is also written to `logs/install-<timestamp>.log`.

## Install Location

`platform-install-Ubuntu.sh` always installs to `/opt/constellation`
(override via the `CONSTELLATION_HOME` environment variable, not part of
the supported interface), regardless of where the repository was cloned
or what directory the installer was run from. If it detects it isn't
already running from there, it copies the checkout over (excluding
runtime data/logs/backups/`.env`) and re-execs itself from the canonical
path before doing anything else. See
[ADR-0006](adr/0006-canonical-install-location.md) for the full reasoning
and edge cases (e.g. what happens if `/opt/constellation` already exists
and isn't a Constellation checkout).

## Recommended Post-Install Steps

Backups and SSH are handled automatically by the installer now (steps 2
and 8 above). What's left is a single manual step:

- **Enable Command Audit**: `sudo ./scripts/audit-enable.sh` (run once) —
  captures ad hoc commands for installer-drift review. See
  [Keeping the Installer as Source of Truth](#keeping-the-installer-as-source-of-truth)
  below.

See [docs/20-deployment-checklist.md](20-deployment-checklist.md) for the
complete operator checklist, including everything that's intentionally
*not* automated.

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
./scripts/backup.sh            # backups/<timestamp>/
./scripts/backup.sh <label>    # backups/<timestamp>-<label>/
```

`<label>` is optional, letters/digits/`-`/`_` only, and exists purely so a
human looking at `backups/` can tell checkpoints apart by name.
`platform-install-Ubuntu.sh` uses `initial`, `dependencies`, and
`constellation` for its three install-time checkpoints (see
[Fresh Install](#fresh-install) above); the weekly scheduled run and
ad hoc manual runs typically omit it.

Each backup directory contains:

- `postgres.sql.gz` — gzipped `pg_dump` of the PostgreSQL database (skipped
  if Postgres isn't installed/running yet, e.g. the `initial` checkpoint)
- `qdrant_storage.tar.gz` — archive of `qdrant_storage/` (skipped if it
  doesn't exist yet)
- `configs.tar.gz` — archive of `.env`, `docker-compose.yml`, and `config/`
  (whichever of those exist yet)

This is still a simple point-in-time snapshot, not a full backup system —
there is no restore automation yet. `backups/` is gitignored; copy it
somewhere durable (off this machine) if it needs to survive a disk failure.
`configs.tar.gz` contains `.env`, so treat it as a secret.

### Automatic weekly backups

Enabled automatically by `scripts/install/08-schedule-backups.sh` as the
last step of every install. Re-run it directly any time (e.g. after
changing `BACKUP_*` settings in `.env`):

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

Backups are capped at **10% of total disk space**
(`BACKUP_MAX_TOTAL_PERCENT` in `.env`, default `10`) and **52 rotating
backups** (`BACKUP_RETENTION_COUNT`, default `52`, i.e. a year of weekly
backups). The size budget is computed fresh on every run via `df` against
the disk hosting this repo, so it scales automatically if you move to
different or larger hardware — on the 500GB Optiplex target, 10% is
~50GB. Every run of `scripts/backup.sh`:

1. The **first backup ever taken** is marked permanent (recorded in
   `backups/.permanent`) and is never auto-deleted.
2. If more than `BACKUP_RETENTION_COUNT` non-permanent backups exist, the
   oldest are removed until back within the limit.
3. If total size in `backups/` still exceeds the computed percentage
   budget, the oldest non-permanent backups are removed further, even
   below the count limit, until back within budget (or only the permanent
   backup remains).

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

At 53 retained backups (1 permanent + 52 weekly) and a ~50GB budget (10%
of a 500GB disk), that's an average of just under **1GB per backup**
available before the oldest rotating backups start getting pruned early
to stay under budget — ample headroom for a single-user Phase 1/2
deployment on this hardware.

## SSH

Installed and configured automatically by `scripts/install/02-ssh.sh`.
Full reasoning in [ADR-0005](adr/0005-ssh-bootstrap.md); summary:

- `openssh-server` is installed and enabled if not already present.
- Both `PasswordAuthentication` and `PubkeyAuthentication` are explicitly
  kept enabled via `/etc/ssh/sshd_config.d/60-constellation.conf` — the
  installer only ever adds a login method, never removes one.
- A dedicated automation/deploy key is generated at
  `/etc/constellation/ssh/deploy_ed25519` for future non-interactive use.
  It is not authorized for login anywhere by default.
- A personal login key is generated for the operator running the
  installer (`~/.ssh/id_ed25519`, only if one doesn't already exist) and
  added to that user's own `~/.ssh/authorized_keys`.
- Host key fingerprints are printed on every install run for out-of-band
  verification (see [Deployment Checklist § Verify SSH access](20-deployment-checklist.md)).

Deliberately out of scope for the installer: disabling password auth,
restricting to specific keys, or any other hardening. That remains a
separate, explicit, operator-initiated action.

## Keeping the Installer as Source of Truth

Per `CLAUDE.md`, "anything required to rebuild a working platform from a
fresh Ubuntu installation must be automated." In practice, day-to-day
troubleshooting on the running machine (installing a missing package,
tweaking a systemd unit, running a one-off `docker` command) happens
outside `platform-install-Ubuntu.sh` — and if it's never fed back into the
installer, a rebuild from scratch won't reproduce it.

`scripts/audit-*.sh` is a feedback loop for catching that drift:

```bash
sudo ./scripts/audit-enable.sh   # once: start capturing interactive commands
./scripts/audit-review.sh        # periodically: see what ran outside the installer
sudo ./scripts/audit-disable.sh  # optional: stop capturing
```

- `audit-enable.sh` installs a small `/etc/profile.d/` hook that appends
  every interactive shell command (timestamp, user, working directory) to
  `logs/command-audit.log`. It takes effect in new shells.
- `audit-review.sh` filters out routine/read-only commands (`cd`, `ls`,
  `cat`, `git status`, etc.), deduplicates and counts what's left, and
  flags (`✓`) any command that already appears somewhere under
  `scripts/install/` so you're only evaluating genuinely new ones. Pass
  `--all` to see the unfiltered raw log instead.

The review step is manual by design — nothing here decides automatically
whether a command belongs in the installer. For each candidate, either:

1. Fold it into the appropriate `scripts/install/0X-*.sh` (and re-run the
   installer end-to-end to confirm it's idempotent), or
2. Decide it was one-off/exploratory and ignore it.

This is a development aid, not a security/compliance audit tool — the log
is world-writable/readable and captures whatever was typed, so avoid
typing secrets directly on the command line while it's enabled.

## Data Locations

All paths below are relative to the install root, which is
`/opt/constellation` by default (see [Install Location](#install-location)):

| Directory          | Contents                         |
|---------------------|-----------------------------------|
| `postgres_data/`    | PostgreSQL data directory          |
| `qdrant_storage/`    | Qdrant collections/storage         |
| `data/nats/`         | NATS JetStream store                |
| `logs/`              | Installer run logs                  |
| `backups/`           | Backup checkpoints (see [Backups](#backups)) |

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
