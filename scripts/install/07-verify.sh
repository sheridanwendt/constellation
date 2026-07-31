#!/usr/bin/env bash
# Goes beyond Docker's container-level healthcheck status (already confirmed
# by 06-deploy-platform.sh) with a real protocol-level smoke test against
# each service, so the installer fails loudly if a service reports
# "healthy" but isn't actually answering requests.
#
# Logic lives in scripts/lib/checks.sh, shared with scripts/doctor.sh.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/checks.sh
source "${SCRIPT_DIR}/../lib/checks.sh"

REPO_ROOT="$(constellation_repo_root)"
cd "${REPO_ROOT}"
safe_source_env .env

log_info "Verifying PostgreSQL accepts queries..."
check_postgres_responds "${REPO_ROOT}"

log_info "Verifying Qdrant API responds..."
check_qdrant_responds "${REPO_ROOT}"

log_info "Verifying NATS monitoring endpoint responds..."
check_nats_responds "${REPO_ROOT}"

log_success "All services verified end-to-end (beyond container healthcheck status)."
