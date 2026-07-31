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
# Runs correctly no matter what directory it's invoked from, and always
# installs into the canonical location (${CONSTELLATION_HOME}, see below) -
# relocating itself there first if run from a different checkout. See
# docs/adr/0006-canonical-install-location.md.
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

require_root
check_ubuntu_version

# --- Canonical install location -------------------------------------------
# Regardless of where this checkout lives or what directory the operator
# ran the command from, Constellation always ends up installed at the same
# default location so data/config/backups are reproducible and easy to
# find. If we're not already running from there, relocate a copy of the
# repository there and re-exec, so every step below (and every future
# re-run) operates against one consistent path.
CONSTELLATION_HOME="${CONSTELLATION_HOME:-/opt/constellation}"

if [[ "${REPO_ROOT}" != "${CONSTELLATION_HOME}" ]]; then
    if [[ -e "${CONSTELLATION_HOME}" && ! -f "${CONSTELLATION_HOME}/platform-install-Ubuntu.sh" ]]; then
        log_error "${CONSTELLATION_HOME} already exists and doesn't look like a Constellation checkout."
        log_error "Move it aside or remove it, then re-run the installer."
        exit 1
    fi

    log_info "Running from ${REPO_ROOT}; Constellation's default install location is ${CONSTELLATION_HOME}."
    log_info "Copying this checkout into ${CONSTELLATION_HOME} for a consistent install path..."

    mkdir -p "${CONSTELLATION_HOME}"

    # Never carry over runtime data/logs/backups/secrets from the source
    # checkout - the canonical location manages its own (05-config.sh
    # generates its own .env there if one doesn't already exist).
    SKIP_ENTRIES=(postgres_data qdrant_storage data logs backups \
        node_modules venv __pycache__ .vscode .idea .env .env.local)

    shopt -s nullglob
    for entry in "${REPO_ROOT}"/* "${REPO_ROOT}"/.[!.]*; do
        name="$(basename "${entry}")"
        skip=false
        for s in "${SKIP_ENTRIES[@]}"; do
            [[ "${name}" == "${s}" ]] && skip=true && break
        done
        [[ "${skip}" == "true" ]] && continue
        cp -a "${entry}" "${CONSTELLATION_HOME}/"
    done
    shopt -u nullglob

    chmod +x "${CONSTELLATION_HOME}/platform-install-Ubuntu.sh" "${CONSTELLATION_HOME}"/scripts/install/*.sh "${CONSTELLATION_HOME}"/scripts/*.sh

    log_success "Repository installed at ${CONSTELLATION_HOME}."
    log_info "Re-running the installer from the canonical location..."
    exec "${CONSTELLATION_HOME}/platform-install-Ubuntu.sh" "$@"
fi

mkdir -p logs
LOG_FILE="logs/install-$(date +%Y%m%d-%H%M%S).log"
exec > >(tee -a "${LOG_FILE}") 2>&1

log_info "Constellation Phase 1 installer starting at ${REPO_ROOT}. Log: ${LOG_FILE}"

# shellcheck source=scripts/lib/report.sh
source "${SCRIPT_DIR}/scripts/lib/report.sh"

report_init "Constellation Deployment Summary"
report_set_category_order "Infrastructure" "Docker" "Configuration" "Platform Services" "Verification" "Backups"
# Safety net: if something crashes before report_print_human_summary runs
# (a bug, an uncaught error), print whatever was recorded instead of dying
# silently like the first real deployment did (see ADR-0007).
trap report_emergency_summary_trap EXIT

# name|category - the mapping from install script to summary section.
PRE_DEPLOY_STEPS=(
    "00-preflight.sh|Infrastructure"
    "01-system-dependencies.sh|Infrastructure"
    "02-ssh.sh|Infrastructure"
    "03-docker.sh|Docker"
    "04-directories.sh|Configuration"
    "05-config.sh|Configuration"
)

DEPLOY_STEPS=(
    "06-deploy-platform.sh|Platform Services"
    "07-verify.sh|Verification"
    "08-schedule-backups.sh|Backups"
)

INSTALL_FAILED=false

# Fail fast: once a step fails, every remaining step (and checkpoint) is
# recorded as SKIPPED rather than attempted, so a broken prerequisite can
# never let a later stage run against a half-configured host.
run_or_skip_step() {
    local name="$1" category="$2"
    if [[ "${INSTALL_FAILED}" == "true" ]]; then
        report_mark_skipped "${name}" "${category}"
        return
    fi
    if ! report_run_step "${name}" "${category}" -- bash "${REPO_ROOT}/scripts/install/${name}"; then
        INSTALL_FAILED=true
    fi
}

run_or_skip_backup() {
    local label="$1"
    local name="backup (${label})"
    if [[ "${INSTALL_FAILED}" == "true" ]]; then
        report_mark_skipped "${name}" "Backups"
        return
    fi
    if ! report_run_step "${name}" "Backups" -- "${REPO_ROOT}/scripts/backup.sh" "${label}"; then
        INSTALL_FAILED=true
    fi
}

# Three checkpoints, named for what state they capture:
#   initial      - before anything is touched (becomes the permanent baseline)
#   dependencies - host prepared (SSH/Docker/directories/config), platform not yet deployed
#   constellation - full platform deployed and verified
run_or_skip_backup "initial"

for entry in "${PRE_DEPLOY_STEPS[@]}"; do
    IFS='|' read -r name category <<< "${entry}"
    run_or_skip_step "${name}" "${category}"
done

run_or_skip_backup "dependencies"

for entry in "${DEPLOY_STEPS[@]}"; do
    IFS='|' read -r name category <<< "${entry}"
    run_or_skip_step "${name}" "${category}"
done

run_or_skip_backup "constellation"

if [[ "${INSTALL_FAILED}" == "true" ]]; then
    report_add_recommendation "Fix the FAILED step above, then re-run: sudo ${REPO_ROOT}/platform-install-Ubuntu.sh (safe to re-run - earlier successful steps are idempotent)."
    report_add_recommendation "Run ${REPO_ROOT}/scripts/doctor.sh for a focused, read-only diagnostic."
else
    report_add_recommendation "Run ${REPO_ROOT}/scripts/status.sh to see service health and connection details."
    report_add_recommendation "Run sudo ${REPO_ROOT}/scripts/audit-enable.sh to start the installer feedback loop (see docs/20-deployment-checklist.md)."
fi

report_print_human_summary
report_write_json "${REPO_ROOT}/logs/install-summary.json"
log_info "Machine-readable report: ${REPO_ROOT}/logs/install-summary.json"

if [[ "${INSTALL_FAILED}" == "true" ]]; then
    exit 1
fi
exit 0
