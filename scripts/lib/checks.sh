#!/usr/bin/env bash
# Shared read-only diagnostic checks, used by both the installer's own
# stage self-validation (00-preflight.sh, 07-verify.sh) and
# scripts/doctor.sh. Nothing in this file modifies system state - a check
# that finds something fixable (e.g. a BOM in .env) reports it, it doesn't
# fix it. The one related exception, strip_bom_if_present(), lives in
# common.sh and is called explicitly by 05-config.sh, not from here.
#
# Every function follows report_run_step's calling convention: it logs via
# log_success/log_warn/log_error and returns 0 for pass (including pass
# with warnings) or non-zero for a hard failure - always via an explicit
# `return`, never relying on inherited `set -e`. That makes them safe to
# call as same-shell functions from report_run_step (which temporarily
# disables errexit around whatever it calls) as well as standalone.

# Deliberately not named SCRIPT_DIR: this file is sourced alongside other
# scripts/lib/*.sh files that each resolve their own directory the same
# way, and a shared global name would clobber whichever one ran last.
_CHECKS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${_CHECKS_LIB_DIR}/common.sh"

check_disk_space() {
    local min_gb="${1:-20}"
    local repo_root avail_kb avail_gb
    repo_root="$(constellation_repo_root)"
    avail_kb="$(df --output=avail -k "${repo_root}" | tail -n1 | tr -d '[:space:]')"
    avail_gb=$(( avail_kb / 1024 / 1024 ))
    if [[ "${avail_gb}" -lt "${min_gb}" ]]; then
        log_error "Only ${avail_gb}GB free; Constellation needs at least ${min_gb}GB for images, data, and backups."
        return 1
    fi
    log_success "Disk space OK (${avail_gb}GB free)."
    return 0
}

check_ram() {
    local min_gb="${1:-4}" target_gb="${2:-16}"
    local total_kb total_gb
    total_kb="$(awk '/MemTotal/{print $2}' /proc/meminfo)"
    total_gb=$(( total_kb / 1024 / 1024 ))
    if [[ "${total_gb}" -lt "${min_gb}" ]]; then
        log_error "Only ${total_gb}GB RAM detected; Constellation needs at least ${min_gb}GB."
        return 1
    elif [[ "${total_gb}" -lt "${target_gb}" ]]; then
        log_warn "Detected ${total_gb}GB RAM; Phase 1 targets ${target_gb}GB (see docs/15-resource-planning.md)."
        log_warn "Continuing, but consider lowering the *_MEM_LIMIT values in .env."
        return 0
    fi
    log_success "RAM OK (${total_gb}GB)."
    return 0
}

# True if Constellation's own containers are already up - used to skip the
# port check on a re-install/upgrade rather than treating our own
# already-bound ports as a conflict.
constellation_already_deployed() {
    command_exists docker && docker ps --format '{{.Names}}' 2>/dev/null | grep -q '^constellation-'
}

check_ports_free() {
    local ports=(5432 6333 6334 4222 8222)
    if constellation_already_deployed; then
        log_success "Constellation containers already present; port check not applicable."
        return 0
    fi
    local conflicts=() port
    for port in "${ports[@]}"; do
        port_in_use "${port}" && conflicts+=("${port}")
    done
    if [[ "${#conflicts[@]}" -gt 0 ]]; then
        log_error "Port(s) already in use: ${conflicts[*]}. Constellation binds these on 127.0.0.1 by default."
        return 1
    fi
    log_success "Required ports are free (${ports[*]})."
    return 0
}

check_docker_installed() {
    if ! command_exists docker; then
        log_error "Docker is not installed."
        return 1
    fi
    if ! docker compose version >/dev/null 2>&1; then
        log_error "Docker Compose plugin is not installed."
        return 1
    fi
    if command_exists systemctl && ! systemctl is-active --quiet docker 2>/dev/null; then
        log_error "Docker service is not running."
        return 1
    fi
    log_success "Docker installed and running: $(docker --version)."
    return 0
}

# Distinguishes "never added to the docker group" from "added, but this
# session predates it" - the two most common reasons `docker ps` fails
# with a permission error right after install, and the fix differs
# (usermod+relogin vs just `newgrp docker`).
check_docker_group_membership() {
    local target_user="${1:-${SUDO_USER:-$(id -un)}}"
    if [[ "${target_user}" == "root" ]]; then
        log_success "Running as root; docker group membership not applicable."
        return 0
    fi
    if ! getent group docker >/dev/null 2>&1; then
        log_warn "The 'docker' group does not exist yet (Docker may not be installed)."
        return 0
    fi
    if ! id -nG "${target_user}" 2>/dev/null | tr ' ' '\n' | grep -qx docker; then
        log_warn "${target_user} is not in the docker group. Run: sudo usermod -aG docker ${target_user}"
        log_warn "Then log out and back in (or run 'newgrp docker') before using docker without sudo."
        return 0
    fi
    if ! id -nG 2>/dev/null | tr ' ' '\n' | grep -qx docker; then
        log_warn "${target_user} is in the docker group, but this login session predates that change."
        log_warn "Run 'newgrp docker' to pick it up in this shell, or log out and back in."
        log_warn "Until then, docker commands need 'sudo' in this session."
        return 0
    fi
    log_success "${target_user} has active docker group access in this session."
    return 0
}

# Checks .env exists, has a real (non-placeholder) POSTGRES_PASSWORD, and
# is safely sourceable by bash. Read-only: reports a BOM, doesn't strip it
# (05-config.sh does that itself via strip_bom_if_present, since it's the
# one that just generated the file).
check_env_file() {
    local repo_root="${1:-$(constellation_repo_root)}"
    local env_file="${repo_root}/.env"

    if [[ ! -f "${env_file}" ]]; then
        log_error ".env not found at ${env_file}."
        return 1
    fi

    if grep -q '^POSTGRES_PASSWORD=change-me$' "${env_file}" 2>/dev/null; then
        log_error "POSTGRES_PASSWORD in ${env_file} is still the placeholder 'change-me'."
        return 1
    fi

    if ! grep -q '^POSTGRES_PASSWORD=.\+' "${env_file}" 2>/dev/null; then
        log_error "POSTGRES_PASSWORD is not set in ${env_file}."
        return 1
    fi

    local first_bytes
    first_bytes="$(head -c3 "${env_file}" | od -An -tx1 | tr -d ' \n')"
    if [[ "${first_bytes}" == "efbbbf" ]]; then
        log_error "${env_file} starts with a UTF-8 byte-order-mark, which breaks bash 'source' (see ADR-0007)."
        log_error "Re-run the installer's config step to self-heal, or strip it manually."
        return 1
    fi

    if ! bash -c "set -e; source '${env_file}'" >/dev/null 2>&1; then
        log_error "${env_file} did not source cleanly under bash - it may be malformed."
        return 1
    fi

    log_success ".env is present, has a real POSTGRES_PASSWORD, and sources cleanly."
    return 0
}

check_docker_compose_config() {
    local repo_root="${1:-$(constellation_repo_root)}"
    if ! command_exists docker; then
        log_error "Docker is not installed; cannot run 'docker compose config'."
        return 1
    fi
    if ! ( cd "${repo_root}" && docker compose config >/dev/null 2>&1 ); then
        log_error "'docker compose config' failed. Run it directly from ${repo_root} to see details."
        return 1
    fi
    log_success "docker compose config is valid."
    return 0
}

check_postgres_responds() {
    local repo_root="${1:-$(constellation_repo_root)}"
    if ! command_exists docker; then
        log_error "Docker is not installed; PostgreSQL cannot be running."
        return 1
    fi
    if [[ -z "$(cd "${repo_root}" && docker compose ps --status running --quiet postgres 2>/dev/null)" ]]; then
        log_error "PostgreSQL container is not running. Check: ${repo_root}/scripts/status.sh"
        return 1
    fi
    local pg_user="${POSTGRES_USER:-constellation}" pg_db="${POSTGRES_DB:-constellation}"
    if ! ( cd "${repo_root}" && docker compose exec -T postgres psql -U "${pg_user}" -d "${pg_db}" -c 'SELECT 1;' >/dev/null 2>&1 ); then
        log_error "PostgreSQL container is running but did not respond to a query."
        return 1
    fi
    log_success "PostgreSQL responds to queries."
    return 0
}

check_qdrant_responds() {
    local repo_root="${1:-$(constellation_repo_root)}"
    local port="${QDRANT_HTTP_PORT:-6333}"
    if ! curl -fsS "http://127.0.0.1:${port}/collections" >/dev/null 2>&1; then
        log_error "Qdrant API did not respond on 127.0.0.1:${port}. Check: ${repo_root}/scripts/status.sh"
        return 1
    fi
    log_success "Qdrant API responds."
    return 0
}

check_nats_responds() {
    local repo_root="${1:-$(constellation_repo_root)}"
    local port="${NATS_MONITOR_PORT:-8222}"
    if ! curl -fsS "http://127.0.0.1:${port}/varz" >/dev/null 2>&1; then
        log_error "NATS monitoring endpoint did not respond on 127.0.0.1:${port}. Check: ${repo_root}/scripts/status.sh"
        return 1
    fi
    log_success "NATS monitoring endpoint responds."
    return 0
}

check_backup_timer() {
    if ! command_exists systemctl; then
        log_warn "systemctl not available; cannot check the backup timer."
        return 0
    fi
    if systemctl is-enabled --quiet constellation-backup.timer 2>/dev/null \
        && systemctl is-active --quiet constellation-backup.timer 2>/dev/null; then
        log_success "Weekly backup timer (constellation-backup.timer) is enabled and active."
        return 0
    fi
    log_warn "constellation-backup.timer is not enabled/active. Run: sudo ./scripts/schedule-backups.sh"
    return 0
}

# Validates sshd config only as far as the current privilege level allows -
# `sshd -t` needs to read the (root-only) host key files for a fully
# definitive check, so a non-root run that fails is reported as
# inconclusive rather than a hard failure.
check_ssh() {
    if ! command_exists sshd; then
        log_error "openssh-server is not installed."
        return 1
    fi
    if command_exists systemctl && ! systemctl is-active --quiet ssh 2>/dev/null; then
        log_error "ssh service is not running."
        return 1
    fi
    if ! sshd -t 2>/dev/null; then
        if [[ "${EUID}" -ne 0 ]]; then
            log_warn "Could not fully validate sshd config as non-root. Re-run with sudo for a definitive check."
        else
            log_error "sshd configuration is invalid ('sshd -t' failed)."
            return 1
        fi
    fi

    local dropin=/etc/ssh/sshd_config.d/60-constellation.conf
    if [[ -f "${dropin}" ]] && grep -q '^PasswordAuthentication yes$' "${dropin}" && grep -q '^PubkeyAuthentication yes$' "${dropin}"; then
        log_success "SSH installed and running; both password and public-key auth enabled (ADR-0005)."
    else
        log_warn "${dropin} missing or doesn't match Constellation's expected SSH config (see ADR-0005)."
    fi
    return 0
}
