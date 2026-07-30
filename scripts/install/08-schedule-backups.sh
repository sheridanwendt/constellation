#!/usr/bin/env bash
# Enables the weekly backup timer as part of every install, so backups are
# on by default rather than an easily-forgotten manual step. The actual
# systemd unit installation lives in scripts/schedule-backups.sh (also safe
# to re-run standalone, e.g. after changing BACKUP_* settings in .env).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "${SCRIPT_DIR}/../lib/common.sh"

REPO_ROOT="$(constellation_repo_root)"
"${REPO_ROOT}/scripts/schedule-backups.sh"
