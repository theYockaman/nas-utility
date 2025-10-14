#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

print_usage() {
    cat <<EOF
Usage: $0 [--data-dir DIR] [--backup-dir DIR] [--help]

Installs or configures Nextcloud (snap). Options:
  --data-dir DIR       Data directory for Nextcloud (default: /mnt/server/nextcloud/)
  --backup-dir DIR     Backup directory to restore from (default: /mnt/server/backups/)
  --help               Show this help
EOF
}

# Defaults
DATA_DIR=/srv/nextcloud/
BACKUP_DIR=/srv/backups/

# Parse args
while [ "$#" -gt 0 ]; do
    case "$1" in
        --help|-h)
            print_usage
            exit 0
            ;;
        --data-dir)
            shift
            DATA_DIR="$1"
            ;;
        --backup-dir)
            shift
            BACKUP_DIR="$1"
            ;;
        *)
            echo "Unknown argument: $1"
            print_usage
            exit 2
            ;;
    esac
    shift
done

# Normalize
DATA_DIR="${DATA_DIR%/}/"
BACKUP_DIR="${BACKUP_DIR%/}/"

# Ensure snap is available
if ! command -v snap >/dev/null 2>&1; then
    echo "snap not found. Please install snapd on this system and re-run."
    exit 3
fi

# Install Nextcloud via snap if not already installed
if ! snap list | grep -q "^nextcloud "; then
    sudo snap install nextcloud
fi

# Connect removable-media interface (idempotent)
sudo snap connect nextcloud:removable-media || true

# Create data directory if it doesn't exist
if [ ! -d "$DATA_DIR" ]; then
    sudo mkdir -p "$DATA_DIR"
    sudo chown -R root:root "$DATA_DIR"
    sudo chmod 0770 "$DATA_DIR"
fi

# Register Nextcloud data directory in backup config
CONFIG_FILE="/etc/backup_dirs.list"
if [ ! -f "$CONFIG_FILE" ]; then
    sudo touch "$CONFIG_FILE"
    sudo chmod 0644 "$CONFIG_FILE"
fi
if ! sudo grep -Fxq "$DATA_DIR" "$CONFIG_FILE"; then
    echo "Adding Nextcloud data directory to $CONFIG_FILE"
    echo "$DATA_DIR" | sudo tee -a "$CONFIG_FILE" >/dev/null
fi

# Also attempt to register Nextcloud config directory if it exists
NC_CONFIG_DIR="/var/snap/nextcloud/current/nextcloud/config"
if [ -d "$NC_CONFIG_DIR" ]; then
    if ! sudo grep -Fxq "$NC_CONFIG_DIR" "$CONFIG_FILE"; then
        echo "Adding Nextcloud config directory to $CONFIG_FILE"
        echo "$NC_CONFIG_DIR" | sudo tee -a "$CONFIG_FILE" >/dev/null
    fi
fi

# Update autoconfig.php to use new data directory if the file exists
CONFIG_FILE="/var/snap/nextcloud/current/nextcloud/config/autoconfig.php"
if [ -f "$CONFIG_FILE" ]; then
    if grep -q "'directory' =>" "$CONFIG_FILE"; then
        sudo sed -i "s|'directory' => '[^']*'|'directory' => '$DATA_DIR'|g" "$CONFIG_FILE"
    else
        sudo sed -i "/);/i\    'directory' => '$DATA_DIR'," "$CONFIG_FILE" || true
    fi
else
    echo "Warning: $CONFIG_FILE not found; skipping autoconfig update."
fi

# Restart Nextcloud PHP service if present
if sudo snap services | grep -q "nextcloud.php-fpm"; then
    sudo snap restart nextcloud.php-fpm || true
fi

echo "Nextcloud installation/configuration complete. Data directory: ${DATA_DIR}"