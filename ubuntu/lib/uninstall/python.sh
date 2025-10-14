#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

REQ_DIR="/etc/nas-utility"
BACKUP_LIST="/etc/backup_dirs.list"

if [[ $EUID -ne 0 ]]; then
  echo "Please run as root (sudo)"
  exit 1
fi

read -p "Remove requirements snapshot directory ${REQ_DIR}? (y/N): " ans
if [[ "$ans" =~ ^[Yy]$ ]]; then
  rm -rf "$REQ_DIR" && echo "Removed $REQ_DIR"
fi

# Unregister any python-requirements files from backup list
if [[ -f "$BACKUP_LIST" ]]; then
  sudo cp "$BACKUP_LIST" "${BACKUP_LIST}.bak" || true
  sudo sed -i "/^\/etc\/nas-utility\/python-requirements-.*\$/d" "$BACKUP_LIST" || true
  echo "Updated $BACKUP_LIST (backup at ${BACKUP_LIST}.bak)"
fi

echo "Done."
