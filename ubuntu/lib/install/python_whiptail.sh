#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MAIN_SCRIPT="$SCRIPT_DIR/python.sh"

if ! command -v whiptail >/dev/null 2>&1; then
    echo "whiptail not found. Install 'whiptail' (package 'newt') to use the interactive helper."
    exit 2
fi

if ! whiptail --yesno "Install Python, create venv, capture requirements and register for backup?" 10 60; then
    echo "Aborted by user."
    exit 1
fi

exec sudo bash "$MAIN_SCRIPT"
