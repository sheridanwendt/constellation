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

# True if something is already listening on the given TCP port.
port_in_use() {
    local port="$1"
    ss -H -ltn "sport = :${port}" 2>/dev/null | grep -q .
}

# Resolves the home directory of a system user without assuming /home/<user>.
user_home_dir() {
    getent passwd "$1" | cut -d: -f6
}

# Strips a leading UTF-8 byte-order-mark from a file in place, if present.
# A BOM before the '#' on line 1 breaks `source`/`.` (bash tries to execute
# the BOM+'#' bytes as a command instead of recognizing a comment), which is
# exactly what happened to the first real deployment: .env.example carried a
# BOM through into every generated .env, and `source .env` in scripts/backup.sh
# died with "command not found" the first time it ran against a real .env.
# Safe to call on any file, including ones without a BOM (no-op then).
strip_bom_if_present() {
    local file="$1"
    [[ -f "${file}" ]] || return 0

    local first_bytes
    first_bytes="$(head -c3 "${file}" | od -An -tx1 | tr -d ' \n')"
    if [[ "${first_bytes}" == "efbbbf" ]]; then
        log_warn "${file} starts with a UTF-8 byte-order-mark, which breaks bash 'source'. Stripping it."
        local orig_mode
        orig_mode="$(stat -c%a "${file}")"
        tail -c +4 "${file}" > "${file}.no-bom"
        chmod "${orig_mode}" "${file}.no-bom"
        mv "${file}.no-bom" "${file}"
    fi
}

# Sources a .env-style file safely: strips a BOM first (see
# strip_bom_if_present), then exports every variable it defines. Use this
# instead of a bare `source <file>` anywhere a .env needs to be loaded.
safe_source_env() {
    local file="$1"
    strip_bom_if_present "${file}"
    set -a
    # shellcheck disable=SC1090
    source "${file}"
    set +a
}
