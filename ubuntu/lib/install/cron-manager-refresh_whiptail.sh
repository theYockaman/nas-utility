#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MAIN_SCRIPT="$SCRIPT_DIR/cron-manager-refresh.sh"

if ! command -v whiptail >/dev/null 2>&1; then
    echo "whiptail not found. Install 'whiptail' (package 'newt') to use the interactive helper."
    exit 2
fi

CRON_TIME=$(whiptail --inputbox "Cron schedule expression (e.g. '0 3 * * 0')" 10 60 "0 3 * * 0" 3>&1 1>&2 2>&3)

if whiptail --yesno "Install cron entry into current user's crontab? (No = root crontab)" 8 60; then
    INSTALL_USER="--user"
else
    INSTALL_USER=""
fi

if whiptail --yesno "Perform a dry-run (no changes) when installing?" 8 60; then
    DRY_RUN="--dry-run"
else
    DRY_RUN=""
fi

if ! whiptail --yesno "Install cron-manager-refresh with:\n\nCron time: ${CRON_TIME}\nUser crontab: ${INSTALL_USER:-no}\nDry-run: ${DRY_RUN:-no}\n\nContinue?" 16 70; then
    echo "Aborted by user."
    exit 1
fi

exec sudo bash "$MAIN_SCRIPT" --time "${CRON_TIME}" ${INSTALL_USER} ${DRY_RUN}
