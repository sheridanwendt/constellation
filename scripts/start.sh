#!/usr/bin/env bash
# Starts the Constellation infrastructure stack.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

cd "$(constellation_repo_root)"
log_info "Starting Constellation platform..."
docker compose up -d
docker compose ps
