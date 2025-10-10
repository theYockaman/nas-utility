
# Setup Filebrowser: -- https://aimerneige.com/en/post/linux/install-filebrowser-on-ubuntu-server/

if [ $# -ge 1 ]; then
    if [[ $1 == "--help" ]]; then
        echo "Usage: $0 filebrowser [options]"
        echo "Installs FileBrowser with optional parameters:"
        echo "  arg1   = filebrowser port"
        echo "  arg2   = server directory"
        echo "  arg3   = backup directory"
        return 0
    fi


    PORT="$1"
else

    if [[ $WHIPTAIL == true ]]; then
        PORT=$(whiptail --inputbox "Enter the port for File Browser (default: 8080): "  10 60 3>&1 1>&2 2>&3)
    fi
    PORT=${PORT:-8080}
    
fi


# Get server directory from $1 or prompt
if [ $# -ge 2 ]; then
    SERVER_DIR="$2"
else

    if [[ $WHIPTAIL == true ]]; then
        SERVER_DIR=$(whiptail --inputbox "Enter the directory to use for Filebrowser root (default: /mnt/server/): "  10 60 3>&1 1>&2 2>&3)
    fi
    SERVER_DIR=${SERVER_DIR:-/mnt/server/}
fi

# Get backup directory from $2 or prompt
if [ $# -ge 3 ]; then
    BACKUP_DIR="$3"
else

    if [[ $WHIPTAIL == true ]]; then
        BACKUP_DIR=$(whiptail --inputbox "Enter the backup directory for Filebrowser (default: /mnt/server/backups/): "  10 60 3>&1 1>&2 2>&3)
    fi
    BACKUP_DIR=${BACKUP_DIR:-/mnt/server/backups/}
fi

# Check if curl is installed
if ! command -v curl &> /dev/null; then
    echo "curl is not installed. Installing curl..."
    sudo apt-get update
    sudo apt-get install -y curl
fi

# Check if sqlite3 is installed
if ! command -v sqlite3 &> /dev/null; then
    echo "sqlite3 is not installed. Installing sqlite3..."
    sudo apt-get update
    sudo apt-get install -y sqlite3
fi

# Create Server Directory if it doesn't exist
if [ ! -d "$SERVER_DIR" ]; then
    sudo mkdir -p "$SERVER_DIR"
fi

# Create Backup Directory if it doesn't exist
if [ ! -d "$BACKUP_DIR" ]; then
    sudo mkdir -p "$BACKUP_DIR"
fi

# Install Filebrowser
if ! command -v filebrowser &> /dev/null; then
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

    FILEBROWSER_BACKUP_DIR=$(find $1/Filebrowser_Backup -maxdepth 1 -type d -name "filebrowser_backup_*" | sort -r | head -n 1)

    # Copy config, data, and optionally logs
    sudo rm -rf /etc/filebrowser
    sudo rm -rf /usr/local/bin/filebrowser
    
    sudo cp -a --no-preserve=ownership "$FILEBROWSER_BACKUP_DIR/etc/filebrowser" /etc
    sudo cp -a --no-preserve=ownership "$FILEBROWSER_BACKUP_DIR/usr/local/bin/filebrowser" /usr/local/bin/
    
else
    # Create configuration directory
    sudo mkdir -p /etc/filebrowser/

# Create configuration file
cat << EOF | sudo tee /etc/filebrowser/.filebrowser.yaml > /dev/null
port: $PORT
address: 0.0.0.0
root: $SERVER_DIR
database: /etc/filebrowser/filebrowser.db
EOF

fi

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