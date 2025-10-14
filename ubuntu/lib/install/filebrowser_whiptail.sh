#!/usr/bin/env bash
# Interactive helper for filebrowser.sh using whiptail

set -euo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MAIN_SCRIPT="$SCRIPT_DIR/filebrowser.sh"

if ! command -v whiptail >/dev/null 2>&1; then
    echo "whiptail not found. Install 'whiptail' (part of 'newt') to use the interactive helper."
    exit 2
fi

PORT=$(whiptail --inputbox "Enter the port for File Browser" 10 60 "8080" 3>&1 1>&2 2>&3)
SERVER_DIR=$(whiptail --inputbox "Enter the directory to use for Filebrowser root" 12 60 "/mnt/server/" 3>&1 1>&2 2>&3)
BACKUP_DIR=$(whiptail --inputbox "Enter the backup directory for Filebrowser (optional)" 12 60 "/mnt/server/backups/" 3>&1 1>&2 2>&3)

# Confirm
if ! whiptail --yesno "Install FileBrowser with:\n\nPort: ${PORT}\nServer dir: ${SERVER_DIR}\nBackup dir: ${BACKUP_DIR}\n\nContinue?" 16 70; then
    echo "Aborted by user."
    exit 1
fi

exec sudo bash "$MAIN_SCRIPT" --port "${PORT}" --server-dir "${SERVER_DIR}" --backup-dir "${BACKUP_DIR}"
