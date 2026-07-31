#!/usr/bin/env bash
# Enables a lightweight, system-wide log of every interactive shell command
# run on this host, so ad hoc commands run during/after installation (that
# aren't part of platform-install-Ubuntu.sh) can be reviewed later and,
# if they matter for reproducibility, folded into scripts/install/*.sh.
#
# This is a development feedback loop for keeping the installer the source
# of truth (per CLAUDE.md) — it is not a security/compliance audit tool.
#
# Usage: sudo ./scripts/audit-enable.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

require_root

REPO_ROOT="$(constellation_repo_root)"
mkdir -p "${REPO_ROOT}/logs"

AUDIT_LOG="${REPO_ROOT}/logs/command-audit.log"
touch "${AUDIT_LOG}"
# World-writable: any user's interactive shell (root or otherwise) must be
# able to append. This log only ever contains shell command lines typed on
# this host, not platform secrets.
chmod 666 "${AUDIT_LOG}"

PROFILE_SCRIPT=/etc/profile.d/constellation-command-audit.sh

log_info "Installing ${PROFILE_SCRIPT}..."
cat > "${PROFILE_SCRIPT}" <<EOF
# Installed by Constellation scripts/audit-enable.sh.
# Logs each interactive shell command to ${AUDIT_LOG} for later review
# via scripts/audit-review.sh. Remove with scripts/audit-disable.sh.
if [[ \$- == *i* ]]; then
    _constellation_audit_log() {
        local cmd
        cmd="\$(HISTTIMEFORMAT= history 1 | sed -e 's/^[ ]*[0-9]*[ ]*//')"
        if [[ -n "\${cmd}" && "\${cmd}" != "\${_CONSTELLATION_LAST_CMD:-}" ]]; then
            printf '%s %s@%s [%s] %s\n' \
                "\$(date '+%Y-%m-%d %H:%M:%S')" "\${USER}" "\$(hostname)" "\${PWD}" "\${cmd}" \
                >> "${AUDIT_LOG}" 2>/dev/null || true
            _CONSTELLATION_LAST_CMD="\${cmd}"
        fi
    }
    PROMPT_COMMAND="_constellation_audit_log\${PROMPT_COMMAND:+; \${PROMPT_COMMAND}}"
fi
EOF
chmod 644 "${PROFILE_SCRIPT}"

log_success "Command audit enabled."
log_info "Log file:     ${AUDIT_LOG}"
log_info "Takes effect in new shells (open a new terminal, or: source ${PROFILE_SCRIPT})"
log_info "Review with:  ./scripts/audit-review.sh"
log_info "Disable with: sudo ./scripts/audit-disable.sh"
