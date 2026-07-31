#!/usr/bin/env bash
# Prepares runtime configuration: creates .env from .env.example if missing,
# and replaces the placeholder Postgres password with a strong generated one.
#
# Self-validates before exiting: .env must exist, have a real
# POSTGRES_PASSWORD, be safely sourceable by bash, and pass
# `docker compose config`. This stage burned the first real deployment
# (see docs/adr/0007-installer-status-framework.md): .env.example carried a
# UTF-8 BOM, which broke bash `source` two steps later with no clear error.
# Any BOM found here is stripped automatically - regenerating .env from a
# clean .env.example already avoids it, but this also self-heals a .env
# left over from an older, buggy run.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/checks.sh
source "${SCRIPT_DIR}/../lib/checks.sh"

REPO_ROOT="$(constellation_repo_root)"
cd "${REPO_ROOT}"

if [[ -f .env ]]; then
    log_success ".env already exists, leaving its contents untouched."
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

# Self-heal: strips a BOM whether .env was just created (inherited from a
# tainted .env.example) or already existed (left over from a prior run
# that hit the bug this guards against).
strip_bom_if_present .env

log_info "Validating generated configuration..."
check_env_file "${REPO_ROOT}"
check_docker_compose_config "${REPO_ROOT}"

log_success "Configuration ready and validated at ${REPO_ROOT}/.env"
