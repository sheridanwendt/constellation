#!/usr/bin/env bash
# Takes a simple point-in-time backup of Constellation's data and config.
#
# This is not a full backup system (no scheduling, retention, or restore
# automation yet) — it exists so you have something to fall back on the
# first time you break something while experimenting.
#
# Usage: ./scripts/backup.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

REPO_ROOT="$(constellation_repo_root)"
cd "${REPO_ROOT}"

TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP_DIR="backups/${TIMESTAMP}"
mkdir -p "${BACKUP_DIR}"

log_info "Writing backup to ${BACKUP_DIR}/"

# --- PostgreSQL ---
if [[ -n "$(docker compose ps --status running --quiet postgres)" ]]; then
    log_info "Dumping PostgreSQL database..."
    docker compose exec -T postgres sh -c 'pg_dump -U "$POSTGRES_USER" "$POSTGRES_DB"' \
        > "${BACKUP_DIR}/postgres.sql"
    log_success "PostgreSQL dump saved: ${BACKUP_DIR}/postgres.sql"
else
    log_warn "postgres container is not running, skipping database dump."
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
