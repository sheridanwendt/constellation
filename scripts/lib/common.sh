#!/usr/bin/env bash
# Shared helpers for Constellation install/operations scripts.
# Intended to be sourced, not executed directly.

set -euo pipefail

COLOR_RESET='\033[0m'
COLOR_RED='\033[0;31m'
COLOR_GREEN='\033[0;32m'
COLOR_YELLOW='\033[0;33m'
COLOR_BLUE='\033[0;34m'

log_info() {
    echo -e "${COLOR_BLUE}[INFO]${COLOR_RESET} $*"
}

log_success() {
    echo -e "${COLOR_GREEN}[ OK ]${COLOR_RESET} $*"
}

log_warn() {
    echo -e "${COLOR_YELLOW}[WARN]${COLOR_RESET} $*" >&2
}

log_error() {
    echo -e "${COLOR_RED}[FAIL]${COLOR_RESET} $*" >&2
}

require_root() {
    if [[ "${EUID}" -ne 0 ]]; then
        log_error "This step requires root privileges. Re-run with sudo."
        exit 1
    fi
}

# Resolves the repository root regardless of the caller's working directory.
constellation_repo_root() {
    cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd
}

check_ubuntu_version() {
    if [[ ! -f /etc/os-release ]]; then
        log_error "/etc/os-release not found. This installer supports Ubuntu only."
        exit 1
    fi

    # shellcheck disable=SC1091
    source /etc/os-release

    if [[ "${ID:-}" != "ubuntu" ]]; then
        log_error "Unsupported OS '${ID:-unknown}'. This installer supports Ubuntu only."
        exit 1
    fi

    if [[ "${VERSION_ID:-}" != "24.04" ]]; then
        log_warn "Detected Ubuntu ${VERSION_ID:-unknown}. Constellation Phase 1 targets Ubuntu 24.04 LTS."
        log_warn "Continuing, but you may encounter untested behavior."
    else
        log_success "Detected Ubuntu 24.04 LTS."
    fi
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}
