#!/bin/bash
set -e

# Stop and remove Nextcloud snap
if snap list | grep -q "^nextcloud "; then
    echo "Stopping Nextcloud snap..."
    sudo snap stop nextcloud
    echo "Removing Nextcloud snap..."
    sudo snap remove nextcloud
fi

# Optionally disconnect removable-media interface (not required, but clean)
if snap connections nextcloud | grep -q "removable-media"; then
    sudo snap disconnect nextcloud:removable-media || true
fi

echo "Nextcloud snap uninstalled. Data in /mnt/server/nextcloud-data was NOT deleted."