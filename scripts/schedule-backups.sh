#!/usr/bin/env bash
# Installs a systemd service + timer that runs scripts/backup.sh weekly,
# so backups happen automatically without a cron job or manual reminders.
#
# Usage: sudo ./scripts/schedule-backups.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

require_root

REPO_ROOT="$(constellation_repo_root)"
TARGET_USER="${SUDO_USER:-$(id -un)}"

SERVICE_FILE=/etc/systemd/system/constellation-backup.service
TIMER_FILE=/etc/systemd/system/constellation-backup.timer

log_info "Installing ${SERVICE_FILE} (runs as ${TARGET_USER})..."
cat > "${SERVICE_FILE}" <<EOF
[Unit]
Description=Constellation platform backup
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
User=${TARGET_USER}
WorkingDirectory=${REPO_ROOT}
ExecStart=${REPO_ROOT}/scripts/backup.sh
EOF

log_info "Installing ${TIMER_FILE} (weekly, catches up missed runs)..."
cat > "${TIMER_FILE}" <<EOF
[Unit]
Description=Weekly schedule for Constellation backups

[Timer]
OnCalendar=weekly
Persistent=true

[Install]
WantedBy=timers.target
EOF

systemctl daemon-reload
systemctl enable --now constellation-backup.timer

log_success "Weekly backup timer installed and enabled."
log_info "Check status:  systemctl status constellation-backup.timer"
log_info "Next run:      systemctl list-timers constellation-backup.timer"
log_info "View logs:     journalctl -u constellation-backup.service"
log_info "Disable:       sudo systemctl disable --now constellation-backup.timer"
