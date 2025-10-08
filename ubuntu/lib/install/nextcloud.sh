#!/bin/bash
set -e

# Get server directory from $1 or prompt
if [ $# -ge 1 ]; then
    if [[ $1 == "--help" ]]; then
        echo "Usage: $0 nextcloud [options]"
        echo "Installs Nextcloud with optional parameters:"
        echo "  arg1   = data directory"
        echo "  arg2   = backup directory"
        return 0
    fi

    DATA_DIR="$1"
else
    DATA_DIR=$(whiptail --inputbox "Enter the directory to use for Filebrowser root (default: /mnt/server/): "  10 60 3>&1 1>&2 2>&3)
    DATA_DIR=${DATA_DIR:-/mnt/server/nextcloud/}
fi

# Get backup directory from $2 or prompt
if [ $# -ge 2 ]; then
    BACKUP_DIR="$2"
else
    BACKUP_DIR=$(whiptail --inputbox "Enter the backup directory for Nextcloud (default: /mnt/server/backups/): "  10 60 3>&1 1>&2 2>&3)
    BACKUP_DIR=${BACKUP_DIR:-/mnt/server/backups/}
fi




# Install Nextcloud via snap if not already installed
if ! snap list | grep -q "^nextcloud "; then
    sudo snap install nextcloud
fi

# Connect removable-media interface
sudo snap connect nextcloud:removable-media

# Create data directory if it doesn't exist
if [ ! -d "$DATA_DIR" ]; then
    sudo mkdir -p "$DATA_DIR"
    sudo chown -R root:root "$DATA_DIR"
    sudo chmod 0770 "$DATA_DIR"
fi

# Update config.php to use new data director
CONFIG_FILE="/var/snap/nextcloud/current/nextcloud/config/autoconfig.php"

if grep -q "'directory' =>" "$CONFIG_FILE"; then
    sudo sed -i "s|'directory' => '[^']*'|'directory' => '$DATA_DIR'|g" "$CONFIG_FILE"
else
    # Insert directory entry before the closing parenthesis and semicolon
    sudo sed -i "/);/i\    'directory' => '$DATA_DIR'," "$CONFIG_FILE"
fi

# Start Nextcloud
sudo snap restart nextcloud.php-fpm

echo "Nextcloud installation and data directory setup complete."