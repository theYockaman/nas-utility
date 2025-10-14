#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MAIN_SCRIPT="$SCRIPT_DIR/cron-manager.sh"

if ! command -v whiptail >/dev/null 2>&1; then
    echo "whiptail not found. Install 'whiptail' (package 'newt') to use the interactive helper."
    exit 2
fi

BACKUP_SOURCE=$(whiptail --inputbox "If restoring from a backup directory, enter its parent path (leave blank to create fresh service)" 12 60 "" 3>&1 1>&2 2>&3)

if ! whiptail --yesno "Install cron-manager with:\n\nBackup source: ${BACKUP_SOURCE:-none}\n\nContinue?" 14 70; then
    echo "Aborted by user."
    exit 1
fi

if [[ -n "$BACKUP_SOURCE" ]]; then
    exec sudo bash "$MAIN_SCRIPT" "$BACKUP_SOURCE"
else
    exec sudo bash "$MAIN_SCRIPT"
fi
