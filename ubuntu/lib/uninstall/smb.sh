#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

BACKUP_LIST="/etc/backup_dirs.list"

if [[ $EUID -ne 0 ]]; then
  echo "Please run as root (sudo)"
  exit 1
fi

read -p "Unregister SMB-related backup paths from $BACKUP_LIST? (y/N): " ans
if [[ "$ans" =~ ^[Yy]$ ]]; then
  sudo cp "$BACKUP_LIST" "${BACKUP_LIST}.bak" || true
  # Remove common smb lines (config, share paths may vary)
  sudo sed -i "/^\/etc\/samba\//d" "$BACKUP_LIST" || true
  sudo sed -i "/^\/srv\/.*/d" "$BACKUP_LIST" || true
  sudo sed -i "/^\/var\/lib\/samba\//d" "$BACKUP_LIST" || true
  echo "Updated $BACKUP_LIST (backup at ${BACKUP_LIST}.bak)"
fi

read -p "Optionally remove a share directory (specify path or leave blank): " share
if [[ -n "$share" ]]; then
  read -p "Remove $share now? (y/N): " ans2
  if [[ "$ans2" =~ ^[Yy]$ ]]; then
    rm -rf "$share" && echo "Removed $share"
  fi
fi

echo "Done."
