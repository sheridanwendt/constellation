#!/usr/bin/env bash
# Shared installer status/reporting engine. Intended to be sourced, not
# executed directly.
#
# Every step reported through this library gets exactly one status:
# SUCCESS, WARNING, FAILED, or SKIPPED. platform-install-Ubuntu.sh and
# scripts/doctor.sh both use this so future installers (Hermes, Athena,
# etc.) inherit status tracking, timing, human-readable summaries, and
# JSON output for free instead of reimplementing it.
#
# Usage:
#   report_init "Constellation Phase 1 Install"
#   report_run_step "01-system-dependencies.sh" "Infrastructure" -- \
#       bash "${REPO_ROOT}/scripts/install/01-system-dependencies.sh"
#   ...
#   report_print_human_summary
#   report_write_json "logs/install-summary.json"

# Deliberately not named SCRIPT_DIR: this file is sourced alongside other
# scripts/lib/*.sh files that each resolve their own directory the same
# way, and a shared global name would clobber whichever one ran last.
_REPORT_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${_REPORT_LIB_DIR}/common.sh"

REPORT_TITLE=""
REPORT_START_EPOCH=0
REPORT_STEP_NAMES=()
REPORT_STEP_CATEGORIES=()
REPORT_STEP_STATUSES=()
REPORT_STEP_DURATIONS=()
REPORT_STEP_DETAILS=()
REPORT_WARNINGS=()
REPORT_RECOMMENDATIONS=()
REPORT_CATEGORY_ORDER=()
REPORT_FINALIZED=false

report_init() {
    REPORT_TITLE="$1"
    REPORT_START_EPOCH="$(date +%s)"
    REPORT_STEP_NAMES=()
    REPORT_STEP_CATEGORIES=()
    REPORT_STEP_STATUSES=()
    REPORT_STEP_DURATIONS=()
    REPORT_STEP_DETAILS=()
    REPORT_WARNINGS=()
    REPORT_RECOMMENDATIONS=()
    REPORT_FINALIZED=false
}

# Sets the fixed print order for report_print_human_summary. Categories
# encountered by report_run_step/report_mark_skipped that aren't in this
# list are appended after it, in first-seen order.
report_set_category_order() {
    REPORT_CATEGORY_ORDER=("$@")
}

report_add_warning() {
    REPORT_WARNINGS+=("$1")
}

report_add_recommendation() {
    REPORT_RECOMMENDATIONS+=("$1")
}

# report_mark_skipped <name> <category> [reason]
report_mark_skipped() {
    REPORT_STEP_NAMES+=("$1")
    REPORT_STEP_CATEGORIES+=("$2")
    REPORT_STEP_STATUSES+=("SKIPPED")
    REPORT_STEP_DURATIONS+=(0)
    REPORT_STEP_DETAILS+=("${3:-skipped after an earlier failure}")
}

# report_run_step <name> <category> -- <command...>
#
# Runs <command...> (must be a separate process, e.g. `bash script.sh` -
# this temporarily disables errexit in the CURRENT shell around the call,
# which would otherwise change same-shell function semantics). Classifies
# the step from the command's exit code and whether it printed any
# log_warn()-style "[WARN]" lines:
#   exit != 0                    -> FAILED
#   exit == 0, any [WARN] lines  -> WARNING (lines are added to the
#                                    Warnings summary automatically)
#   exit == 0, no [WARN] lines   -> SUCCESS
# Returns 0 for SUCCESS/WARNING, 1 for FAILED, so callers can fail-fast.
report_run_step() {
    local name="$1" category="$2"
    shift 2
    [[ "${1:-}" == "--" ]] && shift

    local step_log rc start_epoch end_epoch duration warn_count status detail

    step_log="$(mktemp)"
    start_epoch="$(date +%s)"

    set +e
    "$@" 2>&1 | tee -a "${step_log}"
    rc="${PIPESTATUS[0]}"
    set -e

    end_epoch="$(date +%s)"
    duration=$(( end_epoch - start_epoch ))

    warn_count="$(grep -c '\[WARN\]' "${step_log}" 2>/dev/null || true)"
    warn_count="${warn_count:-0}"

    if [[ "${rc}" -ne 0 ]]; then
        status="FAILED"
        detail="exit ${rc}"
    elif [[ "${warn_count}" -gt 0 ]]; then
        status="WARNING"
        detail="${warn_count} warning(s)"
        while IFS= read -r line; do
            REPORT_WARNINGS+=("${name}: ${line#*"[WARN] "}")
        done < <(sed -E 's/\x1b\[[0-9;]*m//g' "${step_log}" | grep '\[WARN\]')
    else
        status="SUCCESS"
        detail=""
    fi

    REPORT_STEP_NAMES+=("${name}")
    REPORT_STEP_CATEGORIES+=("${category}")
    REPORT_STEP_STATUSES+=("${status}")
    REPORT_STEP_DURATIONS+=("${duration}")
    REPORT_STEP_DETAILS+=("${detail}")

    rm -f "${step_log}"

    [[ "${status}" != "FAILED" ]]
}

report_overall_status() {
    local s
    for s in "${REPORT_STEP_STATUSES[@]}"; do
        [[ "${s}" == "FAILED" ]] && { echo "FAILED"; return; }
    done
    for s in "${REPORT_STEP_STATUSES[@]}"; do
        [[ "${s}" == "WARNING" ]] && { echo "WARNING"; return; }
    done
    if [[ "${#REPORT_STEP_NAMES[@]}" -eq 0 ]]; then
        echo "UNKNOWN"
    else
        echo "SUCCESS"
    fi
}

report_status_badge() {
    case "$1" in
        SUCCESS) echo -e "${COLOR_GREEN} OK ${COLOR_RESET}" ;;
        WARNING) echo -e "${COLOR_YELLOW}WARN${COLOR_RESET}" ;;
        FAILED)  echo -e "${COLOR_RED}FAIL${COLOR_RESET}" ;;
        SKIPPED) echo -e "SKIP" ;;
        *)       echo -e "????" ;;
    esac
}

report_format_duration() {
    local secs="$1"
    if [[ "${secs}" -ge 60 ]]; then
        printf '%dm%02ds' "$(( secs / 60 ))" "$(( secs % 60 ))"
    else
        printf '%ds' "${secs}"
    fi
}

# Category print order: explicit order first, then anything else
# encountered, in first-seen order.
report_ordered_categories() {
    local ordered=() c i seen
    for c in "${REPORT_CATEGORY_ORDER[@]}"; do
        ordered+=("${c}")
    done
    for c in "${REPORT_STEP_CATEGORIES[@]}"; do
        seen=false
        for i in "${ordered[@]}"; do
            [[ "${i}" == "${c}" ]] && seen=true && break
        done
        [[ "${seen}" == "false" ]] && ordered+=("${c}")
    done
    printf '%s\n' "${ordered[@]}"
}

report_print_human_summary() {
    local end_epoch elapsed overall cat i has_any w r

    end_epoch="$(date +%s)"
    elapsed=$(( end_epoch - REPORT_START_EPOCH ))
    overall="$(report_overall_status)"

    echo
    echo "================================================"
    echo "  ${REPORT_TITLE}"
    echo "================================================"
    echo
    echo -e "Overall: $(report_status_badge "${overall}")   (elapsed: $(report_format_duration "${elapsed}"))"
    echo

    while IFS= read -r cat; do
        [[ -z "${cat}" ]] && continue
        has_any=false
        for i in "${!REPORT_STEP_NAMES[@]}"; do
            [[ "${REPORT_STEP_CATEGORIES[$i]}" == "${cat}" ]] && has_any=true && break
        done
        [[ "${has_any}" == "false" ]] && continue

        echo "${cat}"
        for i in "${!REPORT_STEP_NAMES[@]}"; do
            [[ "${REPORT_STEP_CATEGORIES[$i]}" == "${cat}" ]] || continue
            local detail_suffix=""
            [[ -n "${REPORT_STEP_DETAILS[$i]}" ]] && detail_suffix=" - ${REPORT_STEP_DETAILS[$i]}"
            echo -e "  [$(report_status_badge "${REPORT_STEP_STATUSES[$i]}")] $(printf '%-30s' "${REPORT_STEP_NAMES[$i]}") $(report_format_duration "${REPORT_STEP_DURATIONS[$i]}")${detail_suffix}"
        done
        echo
    done < <(report_ordered_categories)

    if [[ "${#REPORT_WARNINGS[@]}" -gt 0 ]]; then
        echo "Warnings"
        for w in "${REPORT_WARNINGS[@]}"; do
            echo "  - ${w}"
        done
        echo
    fi

    if [[ "${#REPORT_RECOMMENDATIONS[@]}" -gt 0 ]]; then
        echo "Recommendations"
        for r in "${REPORT_RECOMMENDATIONS[@]}"; do
            echo "  - ${r}"
        done
        echo
    fi

    echo "================================================"

    REPORT_FINALIZED=true
}

# Escapes a string for embedding in a JSON string value. Deliberately
# dependency-free (no jq/python) since this must still work on a box where
# an early installer step (which might install jq) has itself failed.
report_json_escape() {
    local s="$1"
    s="$(printf '%s' "${s}" | sed -E 's/\x1b\[[0-9;]*m//g')"
    s="${s//\\/\\\\}"
    s="${s//\"/\\\"}"
    s="${s//$'\t'/\\t}"
    s="${s//$'\n'/\\n}"
    printf '%s' "${s}"
}

report_write_json() {
    local path="$1"
    local git_sha ubuntu_version overall elapsed end_epoch n i failed_step

    git_sha="unknown"
    if command_exists git && git -C "$(constellation_repo_root)" rev-parse --short HEAD >/dev/null 2>&1; then
        git_sha="$(git -C "$(constellation_repo_root)" rev-parse --short HEAD)"
    fi

    ubuntu_version="unknown"
    if [[ -f /etc/os-release ]]; then
        ubuntu_version="$(. /etc/os-release; echo "${VERSION_ID:-unknown}")"
    fi

    end_epoch="$(date +%s)"
    elapsed=$(( end_epoch - REPORT_START_EPOCH ))
    overall="$(report_overall_status)"

    failed_step=""
    for i in "${!REPORT_STEP_STATUSES[@]}"; do
        if [[ "${REPORT_STEP_STATUSES[$i]}" == "FAILED" ]]; then
            failed_step="${REPORT_STEP_NAMES[$i]}"
            break
        fi
    done

    mkdir -p "$(dirname "${path}")"

    {
        printf '{\n'
        printf '  "installer_version": "%s",\n' "$(report_json_escape "${git_sha}")"
        printf '  "install_timestamp": "%s",\n' "$(date -u -d "@${REPORT_START_EPOCH}" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u +%Y-%m-%dT%H:%M:%SZ)"
        printf '  "elapsed_seconds": %d,\n' "${elapsed}"
        printf '  "ubuntu_version": "%s",\n' "$(report_json_escape "${ubuntu_version}")"
        printf '  "overall_status": "%s",\n' "${overall}"

        printf '  "steps": [\n'
        n="${#REPORT_STEP_NAMES[@]}"
        for ((i = 0; i < n; i++)); do
            printf '    {"name": "%s", "category": "%s", "status": "%s", "duration_seconds": %d, "detail": "%s"}%s\n' \
                "$(report_json_escape "${REPORT_STEP_NAMES[$i]}")" \
                "$(report_json_escape "${REPORT_STEP_CATEGORIES[$i]}")" \
                "${REPORT_STEP_STATUSES[$i]}" \
                "${REPORT_STEP_DURATIONS[$i]}" \
                "$(report_json_escape "${REPORT_STEP_DETAILS[$i]}")" \
                "$([[ $((i + 1)) -lt ${n} ]] && echo ",")"
        done
        printf '  ],\n'

        printf '  "warnings": [\n'
        n="${#REPORT_WARNINGS[@]}"
        for ((i = 0; i < n; i++)); do
            printf '    "%s"%s\n' \
                "$(report_json_escape "${REPORT_WARNINGS[$i]}")" \
                "$([[ $((i + 1)) -lt ${n} ]] && echo ",")"
        done
        printf '  ],\n'

        printf '  "failed_step": "%s",\n' "$(report_json_escape "${failed_step}")"

        printf '  "recommendations": [\n'
        n="${#REPORT_RECOMMENDATIONS[@]}"
        for ((i = 0; i < n; i++)); do
            printf '    "%s"%s\n' \
                "$(report_json_escape "${REPORT_RECOMMENDATIONS[$i]}")" \
                "$([[ $((i + 1)) -lt ${n} ]] && echo ",")"
        done
        printf '  ]\n'
        printf '}\n'
    } > "${path}"
}

# Registered via `trap report_emergency_summary_trap EXIT`. Fires only if
# the script exits without ever calling report_print_human_summary - i.e.
# a genuinely unexpected crash (bug, uncaught error) rather than a normal
# fail-fast stop, which always finalizes the report before exiting. This
# exists because the first real deployment died with zero explanation
# (see docs/adr/0007-installer-status-framework.md) - the installer must
# never again go silent.
report_emergency_summary_trap() {
    local exit_code=$?
    if [[ "${REPORT_FINALIZED}" != "true" ]]; then
        echo
        echo "================================================" >&2
        echo "  ${REPORT_TITLE:-Constellation Installer}: UNEXPECTED TERMINATION" >&2
        echo "================================================" >&2
        echo "The installer exited (code ${exit_code}) without completing its normal" >&2
        echo "summary. This is itself unexpected - please report it." >&2
        if [[ "${#REPORT_STEP_NAMES[@]}" -gt 0 ]]; then
            echo >&2
            echo "Steps recorded before termination:" >&2
            local i
            for i in "${!REPORT_STEP_NAMES[@]}"; do
                echo "  [${REPORT_STEP_STATUSES[$i]}] ${REPORT_STEP_NAMES[$i]}" >&2
            done
        fi
        echo "================================================" >&2
    fi
}
