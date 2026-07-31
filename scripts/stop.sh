#!/usr/bin/env bash
# Stops the Constellation infrastructure stack without deleting data.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

cd "$(constellation_repo_root)"
log_info "Stopping Constellation platform..."
docker compose stop
log_success "Platform stopped. Data volumes are preserved."
