#!/bin/bash
#============================================================
# Simple Backup Setup Script (rsync + cron)
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

#------------------------------------------------------------
# Install rsync if not installed
#------------------------------------------------------------
if ! command -v rsync &>/dev/null; then
    echo "Installing rsync..."
    apt update && apt install -y rsync
fi


#------------------------------------------------------------
# Create backup directory and log file
#------------------------------------------------------------
mkdir -p "$BACKUP_DIR"
touch "$LOG_FILE"

# Ensure backup config exists and register important files (but never register the backup storage itself)
if [ ! -f "$CONFIG_FILE" ]; then
    sudo touch "$CONFIG_FILE"
    sudo chmod 0644 "$CONFIG_FILE"
fi
# Helper: add path if it exists and not equal to BACKUP_DIR
add_if_needed() {
    p="$1"
    # normalize
    p_norm="${p%/}"
    backup_root_norm="${BACKUP_DIR%/}"
    if [ "$p_norm" = "$backup_root_norm" ]; then
        return
    fi
    if [ -e "$p" ] && ! sudo grep -Fxq "$p_norm" "$CONFIG_FILE"; then
        echo "Adding $p_norm to $CONFIG_FILE"
        echo "$p_norm" | sudo tee -a "$CONFIG_FILE" >/dev/null
    fi
}

# Register log and config file
add_if_needed "$LOG_FILE"
add_if_needed "$CONFIG_FILE"
# Register known service unit for filebrowser if present
add_if_needed "/etc/systemd/system/filebrowser.service"

#------------------------------------------------------------
# Create cron job script
#------------------------------------------------------------
cat <<'EOF' > "$CRON_JOB"
#!/bin/bash
# Backup root (source) - do not attempt to back up the backup storage itself
BACKUP_ROOT="/backup"
BACKUP_DIR="$BACKUP_ROOT/$(date +%F)"
CONFIG_FILE="/etc/backup_dirs.list"
LOG_FILE="/var/log/backup.log"

mkdir -p "$BACKUP_DIR"

MAP_FILE="$BACKUP_DIR/backup_mapping.list"
> "$MAP_FILE"

echo "=== Backup started at $(date) ===" >> "$LOG_FILE"

while IFS= read -r DIR; do
    # Skip empty lines or comments
    [[ -z "$DIR" || "$DIR" =~ ^# ]] && continue
    # normalize
    DIR_NORM="${DIR%/}"
    # Skip backing up the backup storage root itself or anything under it
    if [[ "$DIR_NORM" == "$BACKUP_ROOT" || "$DIR_NORM" == $BACKUP_ROOT/* ]]; then
        echo "Skipping backup of backup storage path: $DIR_NORM" >> "$LOG_FILE"
        continue
    fi
    echo "Backing up: $DIR_NORM" >> "$LOG_FILE"
    # Encode the original absolute path into a unique directory name under the backup
    # Remove leading slash, replace remaining slashes with plus signs
    ENCODED=$(echo "$DIR_NORM" | sed 's|^/||; s|/|+|g')
    DEST="$BACKUP_DIR/$ENCODED"
    mkdir -p "$DEST"
    # use trailing slash on source to copy contents into $DEST (avoid nested DIR/DIR)
    rsync -a --delete "$DIR_NORM/" "$DEST/" >> "$LOG_FILE" 2>&1
    # Record mapping: encoded|original
    echo "$ENCODED|$DIR_NORM" >> "$MAP_FILE"
done < "$CONFIG_FILE"

echo "=== Backup completed at $(date) ===" >> "$LOG_FILE"
EOF

chmod +x "$CRON_JOB"

#------------------------------------------------------------
# Make sure cron is enabled
#------------------------------------------------------------
systemctl enable cron
systemctl restart cron

#------------------------------------------------------------
# Summary
#------------------------------------------------------------
echo "✅ Backup system installed!"
echo "• Edit directories to back up in: $CONFIG_FILE"
echo "• Backups stored in: $BACKUP_DIR"
echo "• Logs stored in: $LOG_FILE"
echo "• Weekly job added: $CRON_JOB"
