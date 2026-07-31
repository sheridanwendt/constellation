#!/usr/bin/env bash
# Read-only diagnostic for an existing (or attempted) Constellation
# deployment. Never modifies anything - every check just reports what it
# finds and, if something's wrong, what command would fix it.
#
# Shares its check logic with the installer's own stage validation
# (scripts/lib/checks.sh) and prints the same deployment-style report
# (scripts/lib/report.sh) that platform-install-Ubuntu.sh does, so the two
# are directly comparable.
#
# Usage:
#   ./scripts/doctor.sh
#
# Works without root. A couple of checks (full sshd config validation) are
# more complete run with sudo, since they need to read root-only files;
# without it they're reported as inconclusive rather than failed.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/checks.sh
source "${SCRIPT_DIR}/lib/checks.sh"
# shellcheck source=lib/report.sh
source "${SCRIPT_DIR}/lib/report.sh"

REPO_ROOT="$(constellation_repo_root)"
cd "${REPO_ROOT}"

if [[ -f .env ]]; then
    safe_source_env .env
fi

report_init "Constellation Doctor Report"
report_set_category_order "Infrastructure" "Docker" "Configuration" "Verification" "Backups"
trap report_emergency_summary_trap EXIT

# Every check below runs regardless of earlier results - unlike the
# installer, doctor.sh never fails fast, since the point is a complete
# picture in one pass. report_run_step returns non-zero on FAILED, which
# would otherwise trip this script's own `set -e`, so every call is
# followed by `|| true`.

# check_ubuntu_version (common.sh) calls exit directly on a hard failure,
# by design, for its normal use as a top-level installer precondition.
# Run it as a subprocess here so that exit only ends the subprocess, not
# this whole diagnostic run - report_run_step reads its exit code either way.
report_run_step "Ubuntu version" "Infrastructure" -- \
    bash -c "source '${SCRIPT_DIR}/lib/common.sh'; check_ubuntu_version" || true
report_run_step "Disk space" "Infrastructure" -- check_disk_space 20 || true
report_run_step "RAM" "Infrastructure" -- check_ram 4 16 || true
report_run_step "SSH" "Infrastructure" -- check_ssh || true

report_run_step "Docker installed" "Docker" -- check_docker_installed || true
report_run_step "Docker permissions" "Docker" -- check_docker_group_membership || true

report_run_step ".env" "Configuration" -- check_env_file "${REPO_ROOT}" || true
report_run_step "docker compose config" "Configuration" -- check_docker_compose_config "${REPO_ROOT}" || true

report_run_step "PostgreSQL" "Verification" -- check_postgres_responds "${REPO_ROOT}" || true
report_run_step "Qdrant" "Verification" -- check_qdrant_responds "${REPO_ROOT}" || true
report_run_step "NATS" "Verification" -- check_nats_responds "${REPO_ROOT}" || true

report_run_step "Backup schedule" "Backups" -- check_backup_timer || true

if [[ "${EUID}" -ne 0 ]]; then
    report_add_recommendation "Some checks are more complete with root: sudo ${REPO_ROOT}/scripts/doctor.sh"
fi

OVERALL="$(report_overall_status)"
if [[ "${OVERALL}" == "FAILED" ]]; then
    report_add_recommendation "Re-run the installer to fix failed checks: sudo ${REPO_ROOT}/platform-install-Ubuntu.sh (safe to re-run)."
fi

report_print_human_summary
report_write_json "${REPO_ROOT}/logs/doctor-report.json"
log_info "Machine-readable report: ${REPO_ROOT}/logs/doctor-report.json"

[[ "${OVERALL}" != "FAILED" ]]
