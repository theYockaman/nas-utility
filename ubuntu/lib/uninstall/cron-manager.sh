#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

SERVICE_NAME="cron-manager.service"
UNIT_FILE="/etc/systemd/system/${SERVICE_NAME}"
SERVICE_DIR="/opt/cron_service"
LOG_FILE="/var/log/cron_service.log"
BACKUP_LIST="/etc/backup_dirs.list"

if [[ $EUID -ne 0 ]]; then
  echo "Please run as root (sudo)"
  exit 1
fi

read -p "Stop and disable systemd service ${SERVICE_NAME}? (y/N): " ans
if [[ "$ans" =~ ^[Yy]$ ]]; then
  systemctl stop "$SERVICE_NAME" || true
  systemctl disable "$SERVICE_NAME" || true
fi

read -p "Remove unit file ${UNIT_FILE}? (y/N): " ans
if [[ "$ans" =~ ^[Yy]$ ]]; then
  rm -f "$UNIT_FILE" && systemctl daemon-reload || true
fi

read -p "Remove service directory ${SERVICE_DIR}? (y/N): " ans
if [[ "$ans" =~ ^[Yy]$ ]]; then
  rm -rf "$SERVICE_DIR" && echo "Removed $SERVICE_DIR"
fi

read -p "Remove log file ${LOG_FILE}? (y/N): " ans
if [[ "$ans" =~ ^[Yy]$ ]]; then
  rm -f "$LOG_FILE" && echo "Removed $LOG_FILE"
fi

# Unregister from backup list
if [[ -f "$BACKUP_LIST" ]]; then
  sudo cp "$BACKUP_LIST" "${BACKUP_LIST}.bak" || true
  sudo sed -i "/^\/opt\/cron_service\$/d" "$BACKUP_LIST" || true
  sudo sed -i "/^\/etc\/systemd\/system\/cron-manager.service\$/d" "$BACKUP_LIST" || true
  sudo sed -i "/^\/var\/log\/cron_service.log\$/d" "$BACKUP_LIST" || true
  sudo sed -i "/^\/srv\/programming\/variables\/pythonCronJobs.json\$/d" "$BACKUP_LIST" || true
  echo "Updated $BACKUP_LIST (backup at ${BACKUP_LIST}.bak)"
fi

echo "Done."
