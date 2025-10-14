#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MAIN_SCRIPT="$SCRIPT_DIR/smb.sh"

if ! command -v whiptail >/dev/null 2>&1; then
    echo "whiptail not found. Install 'whiptail' to use this interactive helper."
    exit 2
fi

SHARE_DIR=$(whiptail --inputbox "Directory to share" 10 60 "/mnt/server" 3>&1 1>&2 2>&3)
SHARE_NAME=$(whiptail --inputbox "Share name" 10 60 "Shared" 3>&1 1>&2 2>&3)
USERS=$(whiptail --inputbox "Comma-separated usernames to create/allow" 10 60 "alice,bob" 3>&1 1>&2 2>&3)

# Collect passwords interactively (avoid passing on CLI)
IFS=',' read -ra USER_ARR <<< "$USERS"
PASSWORDS=()
for u in "${USER_ARR[@]}"; do
    utrim=$(echo "$u" | xargs)
    pw=$(whiptail --passwordbox "Enter Samba password for ${utrim} (leave blank to skip)" 10 60 3>&1 1>&2 2>&3)
    PASSWORDS+=("$pw")
done

if ! whiptail --yesno "Create share '${SHARE_NAME}' at '${SHARE_DIR}' for users: ${USERS}\nContinue?" 14 70; then
    echo "Aborted by user."
    exit 1
fi

# Build comma-separated password string
PASSWORDS_CSV=$(IFS=','; echo "${PASSWORDS[*]}")

# Call main script with users and passwords (passwords on CLI are visible; warn user)
echo "Note: passwords passed on the command line are visible to other users while the command runs."
exec sudo bash "$MAIN_SCRIPT" --share-dir "$SHARE_DIR" --share-name "$SHARE_NAME" --users "$USERS" --passwords "$PASSWORDS_CSV"
