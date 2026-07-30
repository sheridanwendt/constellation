#!/usr/bin/env bash
# Installs base system dependencies required before Docker can be installed.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "${SCRIPT_DIR}/../lib/common.sh"

require_root

log_info "Updating apt package index..."
apt-get update -y

log_info "Installing base dependencies (curl, ca-certificates, gnupg, git, jq)..."
apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    gnupg \
    git \
    jq

log_success "System dependencies installed."
