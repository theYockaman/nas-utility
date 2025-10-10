#!/bin/bash
#============================================================
# Backup Cleanup Script
# Removes all files, directories, and cron jobs created
# by the rsync backup setup.
#============================================================

BACKUP_DIR="/backup"
CONFIG_FILE="/etc/backup_dirs.list"
LOG_FILE="/var/log/backup.log"
CRON_JOB="/etc/cron.weekly/rsync-backup"

#------------------------------------------------------------
# Check for root
#------------------------------------------------------------
if [ "$EUID" -ne 0 ]; then
    echo "❌ Please run as root"
    exit 1
fi

echo "⚠️  This will delete all backups, logs, and cron jobs created by the backup setup."
read -p "Are you sure you want to continue? (y/N): " CONFIRM
if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 0
fi

#------------------------------------------------------------
# Stop cron temporarily (optional safety)
#------------------------------------------------------------
systemctl stop cron

#------------------------------------------------------------
# Remove backup directory
#------------------------------------------------------------
if [ -d "$BACKUP_DIR" ]; then
    echo "🗑 Removing backup directory: $BACKUP_DIR"
    rm -rf "$BACKUP_DIR"
else
    echo "✅ No backup directory found."
fi

#------------------------------------------------------------
# Remove config file
#------------------------------------------------------------
if [ -f "$CONFIG_FILE" ]; then
    echo "🗑 Removing config file: $CONFIG_FILE"
    rm -f "$CONFIG_FILE"
else
    echo "✅ No config file found."
fi

#------------------------------------------------------------
# Remove log file
#------------------------------------------------------------
if [ -f "$LOG_FILE" ]; then
    echo "🗑 Removing log file: $LOG_FILE"
    rm -f "$LOG_FILE"
else
    echo "✅ No log file found."
fi

#------------------------------------------------------------
# Remove cron job
#------------------------------------------------------------
if [ -f "$CRON_JOB" ]; then
    echo "🗑 Removing cron job: $CRON_JOB"
    rm -f "$CRON_JOB"
else
    echo "✅ No cron job found."
fi

#------------------------------------------------------------
# Restart cron
#------------------------------------------------------------
systemctl start cron

echo "✅ All backup-related files have been removed successfully."
