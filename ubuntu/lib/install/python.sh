#!/bin/bash
set -e

# Update and upgrade system packages
sudo apt update
sudo apt upgrade -y

# Install Python 3, pip, and venv
sudo apt install -y python3 python3-pip python3.12-venv

# Create a virtual environment in the user's home directory if it doesn't exist
VENV_DIR="$HOME/venv"
if [ ! -d "$VENV_DIR" ]; then
    python3 -m venv "$VENV_DIR"
    echo "Virtual environment created at $VENV_DIR"
else
    echo "Virtual environment already exists at $VENV_DIR"
fi

# Set ownership to the current user
sudo chown -R "$USER:$USER" "$VENV_DIR"

echo "To activate the virtual environment, run:"
echo "source ~/venv/bin/activate"

# --- Create a requirements snapshot and register it for backups ---
NAS_BACKUP_LIST="/etc/backup_dirs.list"
REQ_DIR="/etc/nas-utility"
REQ_FILE="$REQ_DIR/python-requirements-${USER}.txt"

register_path() {
    local p="$1"
    sudo mkdir -p "$(dirname "$NAS_BACKUP_LIST")"
    sudo touch "$NAS_BACKUP_LIST"
    if ! sudo grep -Fxq "$p" "$NAS_BACKUP_LIST"; then
        echo "$p" | sudo tee -a "$NAS_BACKUP_LIST" >/dev/null
    fi
}

sudo mkdir -p "$REQ_DIR"
if [[ -x "${VENV_DIR}/bin/pip" ]]; then
    # Capture installed packages from the venv
    "${VENV_DIR}/bin/pip" freeze | sudo tee "$REQ_FILE" >/dev/null
else
    # Fallback to system pip
    pip3 freeze | sudo tee "$REQ_FILE" >/dev/null || true
fi
sudo chown "$USER:$USER" "$REQ_FILE" || true

# Register only the requirements file for backup (we don't backup the whole venv)
register_path "$REQ_FILE"