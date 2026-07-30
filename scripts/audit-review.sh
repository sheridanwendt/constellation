#!/usr/bin/env bash
# Reviews commands captured by scripts/audit-enable.sh, filtering out
# routine/read-only noise so what's left is a shortlist of commands that
# changed system state and might belong in scripts/install/*.sh.
#
# Usage:
#   ./scripts/audit-review.sh          # filtered candidates
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
NOISE_PATTERN='^(cd|ls|ll|la|pwd|clear|history|man|less|more|cat|tail|head|vim?|nano|exit|logout|whoami|top|htop|w|who|df|du|free|echo|git (status|diff|log|show)|\./scripts/(status|logs)\.sh)( |$)'

TMP_FILE="$(mktemp)"
trap 'rm -f "${TMP_FILE}"' EXIT

sed -E 's/^[^]]*\] //' "${AUDIT_LOG}" \
    | grep -Ev "${NOISE_PATTERN}" \
    | sort | uniq -c | sort -rn > "${TMP_FILE}" || true

if [[ ! -s "${TMP_FILE}" ]]; then
    log_success "No non-routine commands captured yet."
    exit 0
fi

log_info "Candidate commands (count, command) — decide whether each belongs in scripts/install/*.sh:"
echo

while read -r count cmd; do
    marker=" "
    if grep -qrF -- "${cmd}" scripts/install/ 2>/dev/null; then
        marker="✓"
    fi
    printf "  [%s] %4dx  %s\n" "${marker}" "${count}" "${cmd}"
done < "${TMP_FILE}"

echo
log_info "✓ = a matching line already exists somewhere in scripts/install/ (likely already covered)"
log_info "Use --all to see the full raw log, including filtered routine commands."
