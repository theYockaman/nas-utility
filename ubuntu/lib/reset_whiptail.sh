#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MAIN_SCRIPT="/usr/local/lib/nas-utility/reset.sh"

if ! command -v whiptail >/dev/null 2>&1; then
    echo "whiptail not found. Install 'whiptail' (package 'newt') to use this interactive helper."
    exit 2
fi

# Collect options
DRY_RUN=false
PRESERVE_KEYS=true
SKIP_PACKAGES=false
ASSUME_YES=false
KEEP_USERS=()

if whiptail --yesno "Perform a dry-run (show actions without executing)?" 8 60; then
    DRY_RUN=true
fi

if whiptail --yesno "Preserve SSH host keys? (recommended)" 8 60; then
    PRESERVE_KEYS=true
else
    PRESERVE_KEYS=false
fi

if whiptail --yesno "Skip package autoremove/clean?" 8 60; then
    SKIP_PACKAGES=true
fi

if whiptail --yesno "Assume yes to prompts? (non-interactive)" 8 60; then
    ASSUME_YES=true
fi

# Ask for any extra users to keep (comma separated)
USERS=$(whiptail --inputbox "Additional users to preserve (comma separated)" 10 60 "" 3>&1 1>&2 2>&3)
if [[ -n "$USERS" ]]; then
    IFS=',' read -ra ARR <<< "$USERS"
    for u in "${ARR[@]}"; do
        KEEP_USERS+=("$(echo "$u" | xargs)")
    done
fi

# Confirm
SUMMARY="dry-run: ${DRY_RUN}, preserve-keys: ${PRESERVE_KEYS}, skip-packages: ${SKIP_PACKAGES}, assume-yes: ${ASSUME_YES}, keep-users: ${KEEP_USERS[*]}"
if ! whiptail --yesno "Reset with settings:\n${SUMMARY}\n\nContinue?" 16 60; then
    echo "Aborted by user."
    exit 1
fi

# Build args
ARGS=()
$DRY_RUN && ARGS+=(--dry-run)
$ASSUME_YES && ARGS+=(--yes)
$PRESERVE_KEYS || ARGS+=(--no-preserve-ssh-keys)
$SKIP_PACKAGES && ARGS+=(--skip-packages)
for u in "${KEEP_USERS[@]}"; do
    ARGS+=(--keep-user "$u")
done

# Execute
exec sudo bash "$MAIN_SCRIPT" "${ARGS[@]}"
