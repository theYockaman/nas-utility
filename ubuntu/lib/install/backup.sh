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
# Create config file if it doesn't exist
#------------------------------------------------------------
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Creating $CONFIG_FILE..."
    cat <<EOF > "$CONFIG_FILE"
# List of directories to back up (one per line)
# Example:
# /home
# /etc
# /var/www
EOF
fi

#------------------------------------------------------------
# Create backup directory and log file
#------------------------------------------------------------
mkdir -p "$BACKUP_DIR"
touch "$LOG_FILE"

#------------------------------------------------------------
# Create cron job script
#------------------------------------------------------------
cat <<'EOF' > "$CRON_JOB"
#!/bin/bash
BACKUP_DIR="/backup/$(date +%F)"
CONFIG_FILE="/etc/backup_dirs.list"
LOG_FILE="/var/log/backup.log"

mkdir -p "$BACKUP_DIR"

MAP_FILE="$BACKUP_DIR/backup_mapping.list"
> "$MAP_FILE"

echo "=== Backup started at $(date) ===" >> "$LOG_FILE"

while IFS= read -r DIR; do
    # Skip empty lines or comments
    [[ -z "$DIR" || "$DIR" =~ ^# ]] && continue
    echo "Backing up: $DIR" >> "$LOG_FILE"
    # Encode the original absolute path into a unique directory name under the backup
    # Remove leading slash, replace remaining slashes with plus signs
    ENCODED=$(echo "$DIR" | sed 's|^/||; s|/|+|g')
    DEST="$BACKUP_DIR/$ENCODED"
    mkdir -p "$DEST"
    # use trailing slash on source to copy contents into $DEST (avoid nested DIR/DIR)
    rsync -a --delete "$DIR/" "$DEST/" >> "$LOG_FILE" 2>&1
    # Record mapping: encoded|original
    echo "$ENCODED|$DIR" >> "$MAP_FILE"
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
