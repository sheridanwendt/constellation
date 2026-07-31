#!/usr/bin/env bash
# Pre-flight environment validation. Fails fast, before touching packages or
# Docker, if the host doesn't have enough disk/RAM or if the ports
# Constellation needs are already bound by something else.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "${SCRIPT_DIR}/../lib/common.sh"

REPO_ROOT="$(constellation_repo_root)"

MIN_DISK_GB=20
MIN_RAM_GB=4

log_info "Checking available disk space..."
AVAIL_KB="$(df --output=avail -k "${REPO_ROOT}" | tail -n1 | tr -d '[:space:]')"
AVAIL_GB=$(( AVAIL_KB / 1024 / 1024 ))
if [[ "${AVAIL_GB}" -lt "${MIN_DISK_GB}" ]]; then
    log_error "Only ${AVAIL_GB}GB free; Constellation needs at least ${MIN_DISK_GB}GB for images, data, and backups."
    exit 1
fi
log_success "Disk space OK (${AVAIL_GB}GB free)."

log_info "Checking available RAM..."
TOTAL_RAM_KB="$(awk '/MemTotal/{print $2}' /proc/meminfo)"
TOTAL_RAM_GB=$(( TOTAL_RAM_KB / 1024 / 1024 ))
if [[ "${TOTAL_RAM_GB}" -lt "${MIN_RAM_GB}" ]]; then
    log_error "Only ${TOTAL_RAM_GB}GB RAM detected; Constellation needs at least ${MIN_RAM_GB}GB."
    exit 1
elif [[ "${TOTAL_RAM_GB}" -lt 16 ]]; then
    log_warn "Detected ${TOTAL_RAM_GB}GB RAM; Phase 1 targets 16GB (see docs/15-resource-planning.md)."
    log_warn "Continuing, but consider lowering the *_MEM_LIMIT values in .env."
else
    log_success "RAM OK (${TOTAL_RAM_GB}GB)."
fi

log_info "Checking that required ports are free..."
if command_exists docker && docker ps --format '{{.Names}}' 2>/dev/null | grep -q '^constellation-'; then
    log_info "Constellation containers already present; skipping port-conflict check (re-install/upgrade run)."
else
    REQUIRED_PORTS=(5432 6333 6334 4222 8222)
    CONFLICTS=()
    for port in "${REQUIRED_PORTS[@]}"; do
        if port_in_use "${port}"; then
            CONFLICTS+=("${port}")
        fi
    done

    if [[ "${#CONFLICTS[@]}" -gt 0 ]]; then
        log_error "Port(s) already in use: ${CONFLICTS[*]}"
        log_error "Constellation binds these to 127.0.0.1 by default (Postgres/Qdrant/NATS)."
        log_error "Free them, or change the corresponding *_PORT values in .env.example before continuing."
        exit 1
    fi
    log_success "Required ports are free (${REQUIRED_PORTS[*]})."
fi

log_success "Pre-flight checks passed."
