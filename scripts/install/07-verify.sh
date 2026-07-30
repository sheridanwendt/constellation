#!/usr/bin/env bash
# Goes beyond Docker's container-level healthcheck status (already confirmed
# by 06-deploy-platform.sh) with a real protocol-level smoke test against
# each service, so the installer fails loudly if a service reports
# "healthy" but isn't actually answering requests.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "${SCRIPT_DIR}/../lib/common.sh"

REPO_ROOT="$(constellation_repo_root)"
cd "${REPO_ROOT}"

set -a
# shellcheck disable=SC1091
source .env
set +a

log_info "Verifying PostgreSQL accepts queries..."
docker compose exec -T postgres psql -U "${POSTGRES_USER:-constellation}" -d "${POSTGRES_DB:-constellation}" -c 'SELECT 1;' >/dev/null
log_success "PostgreSQL query OK."

log_info "Verifying Qdrant API responds..."
curl -fsS "http://127.0.0.1:${QDRANT_HTTP_PORT:-6333}/collections" >/dev/null
log_success "Qdrant API OK."

log_info "Verifying NATS monitoring endpoint responds..."
curl -fsS "http://127.0.0.1:${NATS_MONITOR_PORT:-8222}/varz" >/dev/null
log_success "NATS monitoring endpoint OK."

log_success "All services verified end-to-end (beyond container healthcheck status)."
