#!/usr/bin/env bash
# Prepares runtime configuration: creates .env from .env.example if missing,
# and replaces the placeholder Postgres password with a strong generated one.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "${SCRIPT_DIR}/../lib/common.sh"

REPO_ROOT="$(constellation_repo_root)"
cd "${REPO_ROOT}"

if [[ -f .env ]]; then
    log_success ".env already exists, leaving it untouched."
else
    log_info "Creating .env from .env.example..."
    cp .env.example .env
    chmod 600 .env

    if grep -q '^POSTGRES_PASSWORD=change-me$' .env; then
        log_info "Generating a strong POSTGRES_PASSWORD..."
        if command_exists openssl; then
            GENERATED_PASSWORD="$(openssl rand -base64 24 | tr -d '\n/+=')"
        else
            GENERATED_PASSWORD="$(head -c 32 /dev/urandom | base64 | tr -dc 'A-Za-z0-9' | head -c 32)"
        fi
        sed -i "s|^POSTGRES_PASSWORD=change-me$|POSTGRES_PASSWORD=${GENERATED_PASSWORD}|" .env
        log_success "Generated POSTGRES_PASSWORD and wrote it to .env (not committed to git)."
    fi
fi

log_success "Configuration ready at ${REPO_ROOT}/.env"
