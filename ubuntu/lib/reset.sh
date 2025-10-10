#!/bin/bash
# Ubuntu Reset Script
# Clears user data and resets the system without removing SSH

set -e

# --- Configuration ---
KEEP_PACKAGES=("openssh-server" "openssh-client")
LOGFILE="/var/log/ubuntu-reset.log"

echo "=== Ubuntu Reset Script ==="
echo "This will erase user data and reset most settings, but keep SSH access."
read -p "Are you sure you want to continue? (y/N): " confirm
if [[ $confirm != "y" && $confirm != "Y" ]]; then
    echo "Aborted."
    exit 0
fi

echo "Starting system reset... (logging to $LOGFILE)"
exec > >(tee -a "$LOGFILE") 2>&1

# --- Keep SSH running ---
sudo systemctl enable ssh
sudo systemctl start ssh

# --- Step 1: Clear user home directories (except root) ---
echo "[1/6] Clearing user home directories..."
for user in $(ls /home); do
    echo " - Wiping /home/$user"
    sudo rm -rf /home/$user/*
    sudo rm -rf /home/$user/.[!.]* /home/$user/..?* 2>/dev/null || true
done

# --- Step 2: Clear logs and temp files ---
echo "[2/6] Clearing logs and temp files..."
sudo rm -rf /var/log/* /tmp/* /var/tmp/*
sudo journalctl --rotate
sudo journalctl --vacuum-time=1s

# --- Step 3: Remove all packages except essential + SSH ---
echo "[3/6] Removing non-essential packages..."
sudo apt update -y
# Keep SSH and essential base packages
sudo apt install --reinstall -y "${KEEP_PACKAGES[@]}"
sudo apt autoremove --purge -y
sudo apt clean

# --- Step 4: Reset network and hostname ---
echo "[4/6] Resetting network settings..."
sudo rm -f /etc/netplan/*.yaml
sudo cat <<EOF >/etc/netplan/01-default.yaml
network:
  version: 2
  renderer: networkd
  ethernets:
    eth0:
      dhcp4: true
EOF
sudo hostnamectl set-hostname ubuntu
sudo netplan apply || true

# --- Step 5: Reset users (except root) ---
echo "[5/6] Removing all non-root users..."
for user in $(awk -F: '$3 >= 1000 {print $1}' /etc/passwd); do
    if [[ "$user" != "ubuntu" && "$user" != "root" ]]; then
        echo " - Deleting user: $user"
        sudo deluser --remove-home "$user" || true
    fi
done

# --- Step 6: Clean up ---
echo "[6/6] Final cleanup..."
sudo rm -rf /etc/ssh/ssh_host_*  # Optional: regenerate host keys
sudo dpkg-reconfigure openssh-server

sync
echo "System reset complete! SSH is still active."
echo "You may now reconnect via SSH if you were disconnected."
