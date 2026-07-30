#!/usr/bin/env bash
# Pulls images and brings up the Constellation infrastructure stack, then
# waits for all services to report healthy.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "${SCRIPT_DIR}/../lib/common.sh"

REPO_ROOT="$(constellation_repo_root)"
cd "${REPO_ROOT}"

log_info "Pulling service images..."
docker compose pull

log_info "Starting Constellation infrastructure stack..."
docker compose up -d

SERVICES=(constellation-postgres constellation-qdrant constellation-nats)
MAX_WAIT_SECONDS=120
ELAPSED=0

log_info "Waiting for services to become healthy (timeout ${MAX_WAIT_SECONDS}s)..."
while true; do
    ALL_HEALTHY=true
    for container in "${SERVICES[@]}"; do
        STATUS="$(docker inspect --format='{{.State.Health.Status}}' "${container}" 2>/dev/null || echo "unknown")"
        if [[ "${STATUS}" != "healthy" ]]; then
            ALL_HEALTHY=false
        fi
    done

    if [[ "${ALL_HEALTHY}" == "true" ]]; then
        log_success "All services report healthy."
        break
    fi

    if [[ "${ELAPSED}" -ge "${MAX_WAIT_SECONDS}" ]]; then
        log_error "Timed out waiting for services to become healthy."
        docker compose ps
        exit 1
    fi

    sleep 5
    ELAPSED=$((ELAPSED + 5))
done

docker compose ps
log_success "Constellation platform deployed."
