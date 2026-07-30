#!/usr/bin/env bash
#
# platform-install-Ubuntu.sh
#
# Main installation entry point for Constellation Phase 1.
#
# Target hardware: Dell Optiplex 3040, Ubuntu Server 24.04 LTS, 16GB RAM.
#
# This script is the source of truth for rebuilding the platform from a
# fresh Ubuntu install. It orchestrates the smaller scripts under
# scripts/install/. No manual Docker commands are required afterward.
#
# Usage:
#   sudo ./platform-install-Ubuntu.sh
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/common.sh
source "${SCRIPT_DIR}/scripts/lib/common.sh"

REPO_ROOT="${SCRIPT_DIR}"
cd "${REPO_ROOT}"

mkdir -p logs
LOG_FILE="logs/install-$(date +%Y%m%d-%H%M%S).log"
exec > >(tee -a "${LOG_FILE}") 2>&1

log_info "Constellation Phase 1 installer starting. Log: ${LOG_FILE}"

require_root
check_ubuntu_version

STEPS=(
    "01-system-dependencies.sh"
    "02-docker.sh"
    "03-directories.sh"
    "04-config.sh"
    "05-deploy-platform.sh"
)

for step in "${STEPS[@]}"; do
    log_info "----------------------------------------------------------------"
    log_info "Running scripts/install/${step}"
    log_info "----------------------------------------------------------------"
    bash "${REPO_ROOT}/scripts/install/${step}"
done

log_info "----------------------------------------------------------------"
log_success "Constellation Phase 1 installation complete."
log_info "----------------------------------------------------------------"

# Resolve actual configured values for the summary below.
set -a
# shellcheck disable=SC1091
source "${REPO_ROOT}/.env"
set +a

cat <<EOF

  Services:
    PostgreSQL  -> 127.0.0.1:${POSTGRES_PORT:-5432}
    Qdrant      -> http://127.0.0.1:${QDRANT_HTTP_PORT:-6333}
    NATS        -> nats://127.0.0.1:${NATS_CLIENT_PORT:-4222}  (monitor: http://127.0.0.1:${NATS_MONITOR_PORT:-8222})

  Useful commands:
    ./scripts/status.sh    Check service health
    ./scripts/logs.sh      Tail service logs
    ./scripts/stop.sh      Stop the platform
    ./scripts/start.sh     Start the platform
    ./scripts/restart.sh   Restart the platform

  See docs/09-operations.md for full operational details.

  If you were just added to the docker group, log out and back in
  (or run 'newgrp docker') before running docker commands without sudo.

EOF
