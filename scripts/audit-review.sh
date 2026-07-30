#!/usr/bin/env bash
# Reviews commands captured by scripts/audit-enable.sh, filtering out
# routine/read-only noise so what's left is a shortlist of commands that
# changed system state and might belong in scripts/install/*.sh.
#
# Usage:
#   ./scripts/audit-review.sh          # filtered candidates, categorized
#   ./scripts/audit-review.sh --all    # full raw log, unfiltered
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

REPO_ROOT="$(constellation_repo_root)"
cd "${REPO_ROOT}"

AUDIT_LOG="logs/command-audit.log"

if [[ ! -f "${AUDIT_LOG}" ]]; then
    log_warn "No audit log found at ${AUDIT_LOG}."
    log_warn "Run 'sudo ./scripts/audit-enable.sh' first, then work normally for a while."
    exit 0
fi

if [[ "${1:-}" == "--all" ]]; then
    cat "${AUDIT_LOG}"
    exit 0
fi

# Routine/read-only commands that aren't interesting for installer review.
NOISE_PATTERN='^(cd|ls|ll|la|pwd|clear|history|man|less|more|cat|tail|head|vim?|nano|exit|logout'\
'|whoami|id|groups|uname|hostname|date|which|type|alias|env|printenv'\
'|top|htop|w|who|df|du|free|ping|netstat|ss|echo'\
'|journalctl|systemctl (status|list-.*)'\
'|ssh|scp'\
'|git (status|diff|log|show)'\
'|docker (ps|images|logs|inspect)|docker compose (ps|logs)'\
'|\./scripts/(status|logs)\.sh)( |$)'

TMP_FILE="$(mktemp)"
trap 'rm -f "${TMP_FILE}"' EXIT

# Strip the "sudo" (and short flags like -E) prefix before filtering/grouping
# so 'sudo apt install X' and 'apt install X' aren't treated as different
# commands - scripts/install/*.sh all run as root anyway.
sed -E 's/^[^]]*\] //' "${AUDIT_LOG}" \
    | sed -E 's/^sudo(\s+-[A-Za-z]+)?\s+//' \
    | grep -Ev "${NOISE_PATTERN}" \
    | sort | uniq -c | sort -rn > "${TMP_FILE}" || true

if [[ ! -s "${TMP_FILE}" ]]; then
    log_success "No non-routine commands captured yet."
    exit 0
fi

# Best-effort guess at which install script a candidate command belongs in,
# purely to speed up triage - always eyeball the actual command before
# acting on the suggestion.
suggest_target() {
    local cmd="$1"
    case "${cmd}" in
        apt-get\ install*|apt\ install*|apt-get\ upgrade*|dpkg\ *)
            echo "01-system-dependencies.sh" ;;
        ssh-keygen*|sshd*|*sshd_config*)
            echo "02-ssh.sh" ;;
        docker\ compose\ up*|docker\ compose\ pull*)
            echo "06-deploy-platform.sh" ;;
        docker*)
            echo "03-docker.sh" ;;
        mkdir*|chown*|chmod*)
            echo "04-directories.sh" ;;
        *.env*)
            echo "05-config.sh" ;;
        systemctl\ enable*backup*|systemctl*constellation-backup*)
            echo "schedule-backups.sh" ;;
        ufw\ *|iptables\ *|nft\ *)
            echo "(new) firewall step - not yet automated" ;;
        *)
            echo "?" ;;
    esac
}

TOTAL_CANDIDATES=0
ALREADY_COVERED=0

log_info "Candidate commands (count, command, suggested target) - decide whether each belongs in scripts/install/*.sh:"
echo

while read -r count cmd; do
    TOTAL_CANDIDATES=$((TOTAL_CANDIDATES + 1))
    marker=" "
    if grep -qrF -- "${cmd}" scripts/install/ 2>/dev/null; then
        marker="✓"
        ALREADY_COVERED=$((ALREADY_COVERED + 1))
    fi
    target="$(suggest_target "${cmd}")"
    printf "  [%s] %4dx  %-60s -> %s\n" "${marker}" "${count}" "${cmd}" "${target}"
done < "${TMP_FILE}"

echo
log_info "Summary: ${TOTAL_CANDIDATES} candidate command(s), ${ALREADY_COVERED} already covered under scripts/install/."
log_info "✓ = a matching line already exists somewhere in scripts/install/ (likely already covered)"
log_info "-> = best-effort suggested target script; verify before acting on it"
log_info "Use --all to see the full raw log, including filtered routine commands."
