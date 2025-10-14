#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MAIN_SCRIPT="$SCRIPT_DIR/nextcloud.sh"

if ! command -v whiptail >/dev/null 2>&1; then
    echo "whiptail not found. Install 'whiptail' (package 'newt') to use this interactive helper."
    exit 2
fi

DATA_DIR=$(whiptail --inputbox "Enter the Nextcloud data directory" 10 60 "/mnt/server/nextcloud/" 3>&1 1>&2 2>&3)
BACKUP_DIR=$(whiptail --inputbox "Enter the backup directory for Nextcloud (optional)" 10 60 "/mnt/server/backups/" 3>&1 1>&2 2>&3)

if ! whiptail --yesno "Install/configure Nextcloud with:\n\nData dir: ${DATA_DIR}\nBackup dir: ${BACKUP_DIR}\n\nContinue?" 14 70; then
    echo "Aborted by user."
    exit 1
fi

exec sudo bash "$MAIN_SCRIPT" --data-dir "${DATA_DIR}" --backup-dir "${BACKUP_DIR}"
