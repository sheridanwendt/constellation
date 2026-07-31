#!/usr/bin/env bash
# Installs base system dependencies required before Docker can be installed.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "${SCRIPT_DIR}/../lib/common.sh"

require_root

log_info "Updating apt package index..."
apt-get update -y

log_info "Upgrading installed packages..."
DEBIAN_FRONTEND=noninteractive apt-get upgrade -y

log_info "Installing base dependencies (curl, ca-certificates, gnupg, git, jq)..."
apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    gnupg \
    git \
    jq

log_success "System dependencies installed."

if [[ -f /var/run/reboot-required ]]; then
    log_warn "A package upgrade requires a reboot (see /var/run/reboot-required)."
    log_warn "Finish this install, then reboot and re-run ./platform-install-Ubuntu.sh once to"
    log_warn "confirm services come back cleanly (see docs/20-deployment-checklist.md)."
fi
