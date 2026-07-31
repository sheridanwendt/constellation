#!/usr/bin/env bash
# Reports container and health status for the Constellation platform.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

cd "$(constellation_repo_root)"
docker compose ps

echo
for container in constellation-postgres constellation-qdrant constellation-nats; do
    STATUS="$(docker inspect --format='{{.State.Health.Status}}' "${container}" 2>/dev/null || echo "not running")"
    echo "${container}: ${STATUS}"
done
