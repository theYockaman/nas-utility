#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# Uninstall script for pythonRefresh cron installer
TARGET_BIN="/usr/local/bin/pythonRefresh.sh"
LOG_FILE="/var/log/pythonRefresh.log"
BACKUP_LIST="/etc/backup_dirs.list"

if [[ $EUID -ne 0 ]]; then
  echo "Please run as root (sudo)"
  exit 1
fi

read -p "Remove installed script $TARGET_BIN? (y/N): " ans
if [[ "$ans" =~ ^[Yy]$ ]]; then
  rm -f "$TARGET_BIN" && echo "Removed $TARGET_BIN"
fi

read -p "Remove log file $LOG_FILE? (y/N): " ans
if [[ "$ans" =~ ^[Yy]$ ]]; then
  rm -f "$LOG_FILE" && echo "Removed $LOG_FILE"
fi

# Remove cron lines referencing the command
read -p "Remove cron entries that run $TARGET_BIN from root crontab? (y/N): " ans
if [[ "$ans" =~ ^[Yy]$ ]]; then
  sudo crontab -l 2>/dev/null | grep -v -F "$TARGET_BIN" | sudo crontab - || true
fi

# Unregister from backup list
if [[ -f "$BACKUP_LIST" ]]; then
  sudo cp "$BACKUP_LIST" "${BACKUP_LIST}.bak" || true
  sudo sed -i "/^\/usr\/local\/bin\/pythonRefresh.sh\$/d" "$BACKUP_LIST" || true
  sudo sed -i "/^\/var\/log\/pythonRefresh.log\$/d" "$BACKUP_LIST" || true
  echo "Updated $BACKUP_LIST (backup at ${BACKUP_LIST}.bak)"
fi

echo "Done."
