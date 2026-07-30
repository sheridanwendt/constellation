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

PRE_DEPLOY_STEPS=(
    "00-preflight.sh"
    "01-system-dependencies.sh"
    "02-ssh.sh"
    "03-docker.sh"
    "04-directories.sh"
    "05-config.sh"
)

DEPLOY_STEPS=(
    "06-deploy-platform.sh"
    "07-verify.sh"
    "08-schedule-backups.sh"
)

run_step() {
    local step="$1"
    log_info "----------------------------------------------------------------"
    log_info "Running scripts/install/${step}"
    log_info "----------------------------------------------------------------"
    bash "${REPO_ROOT}/scripts/install/${step}"
}

# Three checkpoints, named for what state they capture:
#   initial      - before anything is touched (becomes the permanent baseline)
#   dependencies - host prepared (SSH/Docker/directories/config), platform not yet deployed
#   constellation - full platform deployed and verified
log_info "Taking an 'initial' backup before making any changes..."
"${REPO_ROOT}/scripts/backup.sh" initial

for step in "${PRE_DEPLOY_STEPS[@]}"; do
    run_step "${step}"
done

log_info "Dependencies installed. Taking a 'dependencies' backup before deploying Constellation..."
"${REPO_ROOT}/scripts/backup.sh" dependencies

for step in "${DEPLOY_STEPS[@]}"; do
    run_step "${step}"
done

log_info "Taking a final 'constellation' backup now that the platform is deployed..."
"${REPO_ROOT}/scripts/backup.sh" constellation

log_info "----------------------------------------------------------------"
log_success "Constellation Phase 1 installation complete."
log_info "----------------------------------------------------------------"

# Resolve actual configured values for the summary below.
set -a
# shellcheck disable=SC1091
source "${REPO_ROOT}/.env"
set +a

cat <<EOF

  Installed at: ${REPO_ROOT}
  (This is Constellation's canonical location; it's where the platform
  lives no matter where you originally cloned or ran the installer from.)

  Services:
    PostgreSQL  -> 127.0.0.1:${POSTGRES_PORT:-5432}
    Qdrant      -> http://127.0.0.1:${QDRANT_HTTP_PORT:-6333}
    NATS        -> nats://127.0.0.1:${NATS_CLIENT_PORT:-4222}  (monitor: http://127.0.0.1:${NATS_MONITOR_PORT:-8222})

  Useful commands (run from anywhere):
    ${REPO_ROOT}/scripts/status.sh    Check service health
    ${REPO_ROOT}/scripts/logs.sh      Tail service logs
    ${REPO_ROOT}/scripts/stop.sh      Stop the platform
    ${REPO_ROOT}/scripts/start.sh     Start the platform
    ${REPO_ROOT}/scripts/restart.sh   Restart the platform

  Already handled by this run:
    - Backups taken at 'initial', 'dependencies', and 'constellation'
      checkpoints (${REPO_ROOT}/backups/)
    - Weekly backups are scheduled (systemctl status constellation-backup.timer)
    - SSH is installed/configured; both password and key login work
      (deploy key: /etc/constellation/ssh/deploy_ed25519.pub)

  Recommended next step:
    sudo ${REPO_ROOT}/scripts/audit-enable.sh   Capture ad hoc commands so
                                      they can be folded back into
                                      scripts/install/ later. See
                                      docs/20-deployment-checklist.md.

  See docs/09-operations.md for full operational details.

  If you were just added to the docker group, log out and back in
  (or run 'newgrp docker') before running docker commands without sudo.

EOF
