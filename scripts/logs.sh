#!/usr/bin/env bash
# Tails logs for the Constellation platform, or a single service if named.
# Usage: ./scripts/logs.sh [postgres|qdrant|nats]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

cd "$(constellation_repo_root)"
docker compose logs -f --tail=200 "$@"
