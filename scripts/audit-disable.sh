#!/usr/bin/env bash
# Disables command auditing installed by scripts/audit-enable.sh.
# The captured log itself is left in place; remove it manually if desired.
#
# Usage: sudo ./scripts/audit-disable.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

require_root

PROFILE_SCRIPT=/etc/profile.d/constellation-command-audit.sh

if [[ -f "${PROFILE_SCRIPT}" ]]; then
    rm -f "${PROFILE_SCRIPT}"
    log_success "Removed ${PROFILE_SCRIPT}."
    log_info "Takes effect in new shells; already-open shells keep logging until closed."
else
    log_warn "${PROFILE_SCRIPT} not found, nothing to disable."
fi
