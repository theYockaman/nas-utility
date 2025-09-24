#!/bin/bash

# Get parameters or prompt for shared directory and share name
if [ -n "$1" ]; then
    SHARE_DIR="$1"
else
    SHARE_DIR=$(whiptail --inputbox "Enter the directory to share (default: /mnt/server): "  10 60 3>&1 1>&2 2>&3)
    SHARE_DIR=${SHARE_DIR:-/mnt/server}
fi

if [ -n "$2" ]; then
    SHARE_NAME="$2"
else
    SHARE_NAME=$(whiptail --inputbox "Enter the share name (default: Shared): "   10 60 3>&1 1>&2 2>&3)
    SHARE_NAME=${SHARE_NAME:-Shared}
fi

# Get users from $3 or prompt
if [ -n "$3" ]; then
    USER_INPUT="$3"
else
    USER_INPUT=$(whiptail --inputbox "Enter usernames to create and allow (comma separated): "   10 60 3>&1 1>&2 2>&3)
fi
IFS=',' read -ra USERS <<< "$USER_INPUT"

# Get passwords from $4 (comma separated) or prompt
if [ -n "$4" ]; then
    IFS=',' read -ra PASSWORDS <<< "$4"
    declare -A USER_PASSWORDS
    for i in "${!USERS[@]}"; do
        USER=$(echo "${USERS[$i]}" | xargs)
        PASSWORD="${PASSWORDS[$i]}"
        USER_PASSWORDS["$USER"]="$PASSWORD"
    done
else
    declare -A USER_PASSWORDS
    for USER in "${USERS[@]}"; do
        USER=$(echo "$USER" | xargs)
        PASSWORD=$(whiptail --inputbox "Enter Samba password for $USER: "   10 60 3>&1 1>&2 2>&3)
        echo
        USER_PASSWORDS["$USER"]="$PASSWORD"
    done
fi



# Check if Samba is installed, install if not
if ! dpkg -s samba >/dev/null 2>&1; then
    sudo apt update
    sudo apt install samba -y
fi

# Create the shared directory only if it does not exist
if [ ! -d "$SHARE_DIR" ]; then
    sudo mkdir -p "$SHARE_DIR"
    sudo chown root:root "$SHARE_DIR"
    sudo chmod 0777 "$SHARE_DIR"
else
    echo "Directory $SHARE_DIR already exists. Skipping creation."
fi

# Create users, set system password to match Samba password, and add Samba password
for USER in "${USERS[@]}"; do
    USER=$(echo "$USER" | xargs) # trim whitespace
    PASS="${USER_PASSWORDS[$USER]}"

    # Create system user if it doesn't exist
    if ! id "$USER" &>/dev/null; then
        sudo adduser --disabled-password --gecos "" "$USER"
    fi

    # If password is non-empty, set the system password (chpasswd) and Samba password
    if [ -n "$PASS" ]; then
        # Set system password so user can login (echo "user:pass" | sudo chpasswd)
        echo "$USER:$PASS" | sudo chpasswd

        # Set Samba password (provide password twice to smbpasswd)
        (echo "$PASS"; echo "$PASS") | sudo smbpasswd -a "$USER" >/dev/null 2>&1
    else
        # If no password provided, enable samba user with empty password disabled and skip chpasswd
        echo "No password provided for user '$USER' — skipping password set."
    fi
done

# Backup and configure smb.conf
sudo cp /etc/samba/smb.conf /etc/samba/smb.conf.bak

# Add global section for protocol compatibility if not present
if ! grep -q "server min protocol" /etc/samba/smb.conf; then
sudo bash -c "cat >> /etc/samba/smb.conf <<EOF

[global]
   # Allow SMB1 for XP, but support SMB2/3 for modern macOS
   server min protocol = NT1
   server max protocol = SMB3
   client min protocol = NT1
   client max protocol = SMB3
   security = user

   passdb backend = tdbsam
   unix password sync = yes
   encrypt passwords = yes
   obey pam restrictions = yes
EOF"
fi

# Build valid users string
VALID_USERS=$(printf "%s " "${USERS[@]}" | xargs)

# Only add the share section if it doesn't already exist
if ! grep -q "^\[$SHARE_NAME\]" /etc/samba/smb.conf; then
sudo bash -c "cat >> /etc/samba/smb.conf <<EOF

[$SHARE_NAME]
   path = $SHARE_DIR
   valid users = $VALID_USERS
   browsable = yes
   writable = yes
   guest ok = no
   read only = no
   create mask = 0777
   directory mask = 0777
   force user = root
EOF"
else
    echo "Share [$SHARE_NAME] already exists in smb.conf. Skipping addition."
fi

# Restart Samba and allow firewall access
sudo systemctl restart smb
sudo ufw allow samba

SERVER_IP=$(hostname -I | awk '{print $1}')

echo "Samba share setup complete. Access via: \\\\$SERVER_IP\\$SHARE_NAME"