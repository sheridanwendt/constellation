#!/usr/bin/env bash
# Installs Docker Engine and the Docker Compose plugin from Docker's
# official apt repository, and enables the docker service.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "${SCRIPT_DIR}/../lib/common.sh"

require_root

if command_exists docker && docker compose version >/dev/null 2>&1; then
    log_success "Docker Engine and Compose plugin already installed, skipping."
else
    log_info "Adding Docker's official GPG key and apt repository..."
    install -m 0755 -d /etc/apt/keyrings

    if [[ ! -f /etc/apt/keyrings/docker.asc ]]; then
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
        chmod a+r /etc/apt/keyrings/docker.asc
    fi

    # shellcheck source=/etc/os-release
    source /etc/os-release
    ARCH="$(dpkg --print-architecture)"

    cat > /etc/apt/sources.list.d/docker.list <<EOF
deb [arch=${ARCH} signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu ${VERSION_CODENAME} stable
EOF

    log_info "Installing Docker Engine, CLI, containerd, buildx, and compose plugin..."
    apt-get update -y
    apt-get install -y --no-install-recommends \
        docker-ce \
        docker-ce-cli \
        containerd.io \
        docker-buildx-plugin \
        docker-compose-plugin

    log_success "Docker installed: $(docker --version)"
fi

log_info "Enabling and starting the docker service..."
systemctl enable docker >/dev/null
systemctl start docker

TARGET_USER="${SUDO_USER:-${USER}}"
if [[ "${TARGET_USER}" != "root" ]] && ! id -nG "${TARGET_USER}" | grep -qw docker; then
    log_info "Adding user '${TARGET_USER}' to the docker group..."
    usermod -aG docker "${TARGET_USER}"
    log_warn "You must log out and back in (or run 'newgrp docker') before running docker as ${TARGET_USER} without sudo."
fi

log_success "Docker Engine and Compose plugin ready."
