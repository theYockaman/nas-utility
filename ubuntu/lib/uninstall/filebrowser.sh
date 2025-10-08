
# Stop the filebrowser service
sudo systemctl stop filebrowser

# Disable the filebrowser service
sudo systemctl disable filebrowser

# Remove the Filebrowser service file
sudo rm /etc/systemd/system/filebrowser.service

# Reload systemd daemon
sudo systemctl daemon-reload

# Remove the filebrowser directory
sudo rm -r /etc/filebrowser/

# Optionally, remove the filebrowser binary if it was installed in /usr/local/bin
sudo rm /usr/local/bin/filebrowser

# Remove Port 8080
if ! sudo ufw status | grep -q "8080/tcp"; then
    echo "Allowing port 8080 through ufw..."
    sudo ufw delete allow 8080/tcp
fi

echo "Filebrowser has been uninstalled."