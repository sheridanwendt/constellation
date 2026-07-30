#!/usr/bin/env bash
# Takes a simple point-in-time backup of Constellation's data and config,
# then enforces retention: the first backup ever taken is kept forever;
# beyond that, up to BACKUP_RETENTION_COUNT weekly backups are kept, and
# the oldest are pruned first if total backup storage exceeds
# BACKUP_MAX_TOTAL_PERCENT of the disk hosting this repo. See
# docs/09-operations.md for the full policy.
#
# This is still not a full backup system — there is no restore automation
# yet — but it now supports safe unattended/scheduled use (see
# scripts/schedule-backups.sh).
#
# Usage: ./scripts/backup.sh [label]
#   label   Optional, alphanumeric/dash/underscore only. Appended to the
#           backup directory name (e.g. "initial", "dependencies",
#           "constellation") so a human can tell checkpoints apart.
#           platform-install-Ubuntu.sh uses this to mark install-time
#           checkpoints; scheduled/manual runs typically omit it.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

REPO_ROOT="$(constellation_repo_root)"
cd "${REPO_ROOT}"

LABEL="${1:-}"
if [[ -n "${LABEL}" && ! "${LABEL}" =~ ^[A-Za-z0-9_-]+$ ]]; then
    log_error "Invalid label '${LABEL}': only letters, numbers, '-', and '_' are allowed."
    exit 1
fi

if [[ -f .env ]]; then
    set -a
    # shellcheck disable=SC1091
    source .env
    set +a
fi

BACKUP_RETENTION_COUNT="${BACKUP_RETENTION_COUNT:-52}"
BACKUP_MAX_TOTAL_PERCENT="${BACKUP_MAX_TOTAL_PERCENT:-10}"
if ! [[ "${BACKUP_MAX_TOTAL_PERCENT}" =~ ^[0-9]+$ ]] || [[ "${BACKUP_MAX_TOTAL_PERCENT}" -lt 1 ]] || [[ "${BACKUP_MAX_TOTAL_PERCENT}" -gt 100 ]]; then
    log_warn "BACKUP_MAX_TOTAL_PERCENT='${BACKUP_MAX_TOTAL_PERCENT}' is invalid (expected 1-100), defaulting to 10."
    BACKUP_MAX_TOTAL_PERCENT=10
fi
PERMANENT_MARKER="backups/.permanent"

mkdir -p backups

# Whether any backup already existed before this run, used below to decide
# whether the one we're about to create becomes the permanently kept copy.
PRIOR_BACKUP_EXISTS=false
if compgen -G "backups/[0-9]*-[0-9]*" >/dev/null 2>&1; then
    PRIOR_BACKUP_EXISTS=true
fi

TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
if [[ -n "${LABEL}" ]]; then
    BACKUP_DIR="backups/${TIMESTAMP}-${LABEL}"
else
    BACKUP_DIR="backups/${TIMESTAMP}"
fi
BACKUP_NAME="$(basename "${BACKUP_DIR}")"
mkdir -p "${BACKUP_DIR}"

log_info "Writing backup to ${BACKUP_DIR}/"

# --- PostgreSQL ---
if command_exists docker && [[ -n "$(docker compose ps --status running --quiet postgres 2>/dev/null)" ]]; then
    log_info "Dumping PostgreSQL database..."
    docker compose exec -T postgres sh -c 'pg_dump -U "$POSTGRES_USER" "$POSTGRES_DB"' \
        | gzip > "${BACKUP_DIR}/postgres.sql.gz"
    log_success "PostgreSQL dump saved: ${BACKUP_DIR}/postgres.sql.gz"
else
    log_warn "postgres container is not running (or Docker isn't installed yet), skipping database dump."
fi

# --- Qdrant ---
if [[ -d qdrant_storage ]]; then
    log_info "Archiving Qdrant storage..."
    tar -czf "${BACKUP_DIR}/qdrant_storage.tar.gz" qdrant_storage
    log_success "Qdrant storage archived: ${BACKUP_DIR}/qdrant_storage.tar.gz"
else
    log_warn "qdrant_storage/ not found, skipping."
fi

# --- Configs ---
log_info "Archiving configuration..."
CONFIG_PATHS=()
for path in .env docker-compose.yml config; do
    [[ -e "${path}" ]] && CONFIG_PATHS+=("${path}")
done

if [[ "${#CONFIG_PATHS[@]}" -gt 0 ]]; then
    tar -czf "${BACKUP_DIR}/configs.tar.gz" "${CONFIG_PATHS[@]}"
    chmod 600 "${BACKUP_DIR}/configs.tar.gz"
    log_success "Configuration archived: ${BACKUP_DIR}/configs.tar.gz (contains .env — keep it secret)"
else
    log_warn "No configuration files found to archive."
fi

log_success "Backup complete: ${REPO_ROOT}/${BACKUP_DIR}"

# --- Mark the first-ever backup as permanent ---
if [[ ! -f "${PERMANENT_MARKER}" && "${PRIOR_BACKUP_EXISTS}" == "false" ]]; then
    echo "${BACKUP_NAME}" > "${PERMANENT_MARKER}"
    log_success "Marked ${BACKUP_NAME} as the permanent backup (never auto-pruned)."
fi

# --- Retention: prune oldest backups by count, then by total size ---
PERMANENT_BACKUP=""
[[ -f "${PERMANENT_MARKER}" ]] && PERMANENT_BACKUP="$(cat "${PERMANENT_MARKER}")"

mapfile -t ALL_BACKUPS < <(find backups -maxdepth 1 -mindepth 1 -type d -printf '%f\n' | sort)

ROTATABLE=()
for dir in "${ALL_BACKUPS[@]}"; do
    [[ "${dir}" == "${PERMANENT_BACKUP}" ]] && continue
    ROTATABLE+=("${dir}")
done

while [[ "${#ROTATABLE[@]}" -gt "${BACKUP_RETENTION_COUNT}" ]]; do
    oldest="${ROTATABLE[0]}"
    log_warn "Retention limit (${BACKUP_RETENTION_COUNT} weekly backups) exceeded, removing oldest: ${oldest}"
    rm -rf "backups/${oldest}"
    ROTATABLE=("${ROTATABLE[@]:1}")
done

DISK_TOTAL_BYTES="$(df --output=size -B1 "${REPO_ROOT}" | tail -n1 | tr -d '[:space:]')"
MAX_BYTES=$(( DISK_TOTAL_BYTES * BACKUP_MAX_TOTAL_PERCENT / 100 ))
MAX_GB_DISPLAY=$(( MAX_BYTES / 1024 / 1024 / 1024 ))

log_info "Backup storage budget: ${BACKUP_MAX_TOTAL_PERCENT}% of disk (~${MAX_GB_DISPLAY}GB)"

while [[ "$(du -sb backups | cut -f1)" -gt "${MAX_BYTES}" && "${#ROTATABLE[@]}" -gt 0 ]]; do
    oldest="${ROTATABLE[0]}"
    log_warn "Backup storage budget (~${MAX_GB_DISPLAY}GB) exceeded, removing oldest: ${oldest}"
    rm -rf "backups/${oldest}"
    ROTATABLE=("${ROTATABLE[@]:1}")
done

TOTAL_SIZE="$(du -sh backups | cut -f1)"
log_info "Total backup storage in use: ${TOTAL_SIZE} (budget: ~${MAX_GB_DISPLAY}GB, ${BACKUP_MAX_TOTAL_PERCENT}% of disk)"

if [[ "$(du -sb backups | cut -f1)" -gt "${MAX_BYTES}" ]]; then
    log_warn "Backup storage still exceeds the ~${MAX_GB_DISPLAY}GB (${BACKUP_MAX_TOTAL_PERCENT}%) budget after pruning all rotatable backups."
    log_warn "Only the permanent backup (${PERMANENT_BACKUP:-none}) and/or the newest backup remain here; free disk space manually or lower BACKUP_MAX_TOTAL_PERCENT / BACKUP_RETENTION_COUNT."
fi
