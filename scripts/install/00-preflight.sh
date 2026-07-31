#!/usr/bin/env bash
# Pre-flight environment validation. Fails fast, before touching packages or
# Docker, if the host doesn't have enough disk/RAM or if the ports
# Constellation needs are already bound by something else.
#
# Logic lives in scripts/lib/checks.sh, shared with scripts/doctor.sh.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/checks.sh
source "${SCRIPT_DIR}/../lib/checks.sh"

log_info "Checking available disk space..."
check_disk_space 20

log_info "Checking available RAM..."
check_ram 4 16

log_info "Checking that required ports are free..."
check_ports_free

log_success "Pre-flight checks passed."
