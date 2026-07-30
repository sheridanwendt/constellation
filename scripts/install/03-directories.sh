#!/usr/bin/env bash
# Creates the persistent, repo-relative directories used as bind mounts by
# docker-compose.yml, plus a directory for installer logs. These match the
# entries already present in .gitignore.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "${SCRIPT_DIR}/../lib/common.sh"

REPO_ROOT="$(constellation_repo_root)"
cd "${REPO_ROOT}"

DIRS=(
    "postgres_data"
    "qdrant_storage"
    "data/nats"
    "logs"
)

for dir in "${DIRS[@]}"; do
    if [[ -d "${dir}" ]]; then
        log_success "Directory already exists: ${dir}"
    else
        mkdir -p "${dir}"
        log_success "Created directory: ${dir}"
    fi
done

log_success "Required directories are in place under ${REPO_ROOT}."
