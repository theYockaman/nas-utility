# Setup Filebrowser: -- https://aimerneige.com/en/post/linux/install-filebrowser-on-ubuntu-server/

print_usage() {
    cat <<EOF
Usage: $0 [--port PORT] [--server-dir DIR] [--backup-dir DIR] [--help]

Installs FileBrowser. Options:
  --port PORT         Port for FileBrowser (default: 8080)
  --server-dir DIR    Root directory for FileBrowser (default: /mnt/server/)
  --backup-dir DIR    Backup directory to restore from (default: /mnt/server/backups/)
  --help              Show this help
EOF
}

# Default values
PORT=8080
SERVER_DIR=/srv/
BACKUP_DIR=/backup/

# Parse args (simple, POSIX-friendly)
while [ "$#" -gt 0 ]; do
    case "$1" in
        --help|-h)
            print_usage
            exit 0
            ;;
        --port)
            shift
            PORT="$1"
            ;;
        --server-dir)
            shift
            SERVER_DIR="$1"
            ;;
        --backup-dir)
            shift
            BACKUP_DIR="$1"
            ;;
        --whiptail)
            # keep compatibility but ignore in non-interactive mode
            WHIPTAIL=true
            ;;
        *)
            echo "Unknown argument: $1"
            print_usage
            exit 2
            ;;
    esac
    shift
done

# Normalize trailing slashes
SERVER_DIR="${SERVER_DIR%/}/"
BACKUP_DIR="${BACKUP_DIR%/}/"

# Check if curl is installed
# Ensure required tools exist
command -v curl >/dev/null 2>&1 || { echo "curl not found, installing..."; sudo apt-get update; sudo apt-get install -y curl; }
command -v sqlite3 >/dev/null 2>&1 || { echo "sqlite3 not found, installing..."; sudo apt-get update; sudo apt-get install -y sqlite3; }

# Create Server Directory if it doesn't exist
if [ ! -d "$SERVER_DIR" ]; then
    sudo mkdir -p "$SERVER_DIR"
fi

# Create Backup Directory if it doesn't exist
if [ ! -d "$BACKUP_DIR" ]; then
    sudo mkdir -p "$BACKUP_DIR"
fi

# Register Filebrowser directories for backup
CONFIG_FILE="/etc/backup_dirs.list"
if [ ! -f "$CONFIG_FILE" ]; then
    sudo touch "$CONFIG_FILE"
    sudo chmod 0644 "$CONFIG_FILE"
fi
# Add server root
if ! sudo grep -Fxq "$SERVER_DIR" "$CONFIG_FILE"; then
    echo "Adding Filebrowser server root to $CONFIG_FILE"
    echo "$SERVER_DIR" | sudo tee -a "$CONFIG_FILE" >/dev/null
fi
# Add backup dir
if ! sudo grep -Fxq "$BACKUP_DIR" "$CONFIG_FILE"; then
    echo "Adding Filebrowser backup dir to $CONFIG_FILE"
    echo "$BACKUP_DIR" | sudo tee -a "$CONFIG_FILE" >/dev/null
fi
# Add config dir if present
FB_CONFIG_DIR="/etc/filebrowser"
if [ -d "$FB_CONFIG_DIR" ] && ! sudo grep -Fxq "$FB_CONFIG_DIR" "$CONFIG_FILE"; then
    echo "Adding Filebrowser config dir to $CONFIG_FILE"
    echo "$FB_CONFIG_DIR" | sudo tee -a "$CONFIG_FILE" >/dev/null
fi

# Install Filebrowser
if ! command -v filebrowser >/dev/null 2>&1; then
    sudo curl -fsSL https://raw.githubusercontent.com/filebrowser/get/master/get.sh | bash
    if [ $? -ne 0 ]; then
        echo "Failed to install Filebrowser"
        exit 1
    fi
else
    echo "Filebrowser is already installed."
fi


# Check Filebrowser Backup Directory
if [ -n "$BACKUP_DIR" ] && [ -d "$BACKUP_DIR/Filebrowser_Backup" ]; then
    FILEBROWSER_BACKUP_DIR=$(find "$BACKUP_DIR/Filebrowser_Backup" -maxdepth 1 -type d -name "filebrowser_backup_*" | sort -r | head -n 1)

    if [ -n "$FILEBROWSER_BACKUP_DIR" ]; then
        # Copy config, data, and optionally logs
        sudo rm -rf /etc/filebrowser
        sudo rm -rf /usr/local/bin/filebrowser
        sudo cp -a --no-preserve=ownership "$FILEBROWSER_BACKUP_DIR/etc/filebrowser" /etc || true
        sudo cp -a --no-preserve=ownership "$FILEBROWSER_BACKUP_DIR/usr/local/bin/filebrowser" /usr/local/bin/ || true
    fi
else
    # Create configuration directory
    sudo mkdir -p /etc/filebrowser/
fi

# Create configuration file (idempotent)
cat << EOF | sudo tee /etc/filebrowser/.filebrowser.yaml > /dev/null
port: ${PORT}
address: 0.0.0.0
root: ${SERVER_DIR}
database: /etc/filebrowser/filebrowser.db
EOF

#sudo filebrowser users update admin --password admin

# Create systemd service file
cat << EOF | sudo tee /etc/systemd/system/filebrowser.service > /dev/null
[Unit]
Description=File Browser Service
After=network.target

[Service]
Type=simple
Restart=on-failure
RestartSec=5s
ExecStart=/usr/local/bin/filebrowser

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd daemon and enable the service
sudo systemctl daemon-reload
sudo systemctl enable filebrowser
sudo systemctl start filebrowser

# Check if port is allowed through ufw, if not then allow it
echo "Allowing port $PORT through ufw..."
sudo ufw allow $PORT/tcp

echo "Filebrowser setup complete. (Username and Password Displayed Below)"
sudo systemctl status filebrowser
echo "Filebrowser installed and running on port $PORT"