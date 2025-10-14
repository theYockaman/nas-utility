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
# Ask user which pieces to remove
#------------------------------------------------------------
echo "This uninstall will remove artifacts created by the backup installer."
echo "It will remove (if present):"
echo "  - Backup directory: $BACKUP_DIR"
echo "  - Per-date mapping files under each date directory"
echo "  - Config file: $CONFIG_FILE"
echo "  - Log file: $LOG_FILE"
echo "  - Cron job: $CRON_JOB"

read -p "Proceed and remove these items? (y/N): " CONFIRM
if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    echo "Aborted by user."
    exit 0
fi

# Optionally stop cron during removals
read -p "Stop cron while removing files? (recommended) (y/N): " STOP_CRON
if [[ "$STOP_CRON" =~ ^[Yy]$ ]]; then
    echo "Stopping cron..."
    systemctl stop cron || true
    CRON_STOPPED=true
else
    CRON_STOPPED=false
fi

# Remove backup directory (safe)
if [ -d "$BACKUP_DIR" ]; then
    echo "Removing backup directory: $BACKUP_DIR"
    rm -rf "$BACKUP_DIR"
else
    echo "No backup directory found at $BACKUP_DIR"
fi

# Remove config file
if [ -f "$CONFIG_FILE" ]; then
    echo "Removing config file: $CONFIG_FILE"
    rm -f "$CONFIG_FILE"
else
    echo "No config file found at $CONFIG_FILE"
fi

# Remove log file
if [ -f "$LOG_FILE" ]; then
    echo "Removing log file: $LOG_FILE"
    rm -f "$LOG_FILE"
else
    echo "No log file found at $LOG_FILE"
fi

# Remove cron job
if [ -f "$CRON_JOB" ]; then
    echo "Removing cron job: $CRON_JOB"
    rm -f "$CRON_JOB"
else
    echo "No cron job found at $CRON_JOB"
fi

# If cron was stopped by us, restart it
if [ "$CRON_STOPPED" = true ]; then
    echo "Starting cron..."
    systemctl start cron || true
fi

echo "Uninstall cleanup complete."
