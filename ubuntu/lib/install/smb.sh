#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

print_usage() {
    cat <<EOF
Usage: $0 [--share-dir DIR] [--share-name NAME] --users user1,user2[,userN] [--passwords p1,p2,...] [--help]

Installs and configures a Samba share. Passwords passed on the command line are visible to other users on the system; prefer using the interactive helper `smb_whiptail.sh` for entering passwords.

Options:
  --share-dir DIR       Directory to share (default: /srv/samba)
  --share-name NAME     Share name (default: Shared)
  --users USERLIST      Comma-separated list of usernames to create/allow (required)
  --passwords PASSLIST  Comma-separated list of passwords corresponding to users (optional)
  --help                Show this help
EOF
}

# Defaults
SHARE_DIR=/srv/samba
SHARE_NAME=Shared
USERS_CSV=""
PASSWORDS_CSV=""

# Parse args
while [ "$#" -gt 0 ]; do
    case "$1" in
        --help|-h)
            print_usage
            exit 0
            ;;
        --share-dir)
            shift; SHARE_DIR="$1" ;;
        --share-name)
            shift; SHARE_NAME="$1" ;;
        --users)
            shift; USERS_CSV="$1" ;;
        --passwords)
            shift; PASSWORDS_CSV="$1" ;;
        *)
            echo "Unknown argument: $1"
            print_usage
            exit 2
            ;;
    esac
    shift
done

if [ -z "$USERS_CSV" ]; then
    echo "Error: --users is required. Use smb_whiptail.sh for interactive input if you prefer not to pass passwords on the command line."
    exit 2
fi

# Normalize
SHARE_DIR="${SHARE_DIR%/}"

# Split users and passwords into arrays
IFS=',' read -ra USERS <<< "$USERS_CSV"
declare -A USER_PASSWORDS
if [ -n "$PASSWORDS_CSV" ]; then
    IFS=',' read -ra PASSWORDS <<< "$PASSWORDS_CSV"
    for i in "${!USERS[@]}"; do
        user=$(echo "${USERS[$i]}" | xargs)
        pass="${PASSWORDS[$i]:-}"
        USER_PASSWORDS["$user"]="$pass"
    done
fi

# Ensure Samba is installed
if ! dpkg -s samba >/dev/null 2>&1; then
    sudo apt update
    sudo apt install -y samba
fi

# Create the shared directory if it does not exist
if [ ! -d "$SHARE_DIR" ]; then
    sudo mkdir -p "$SHARE_DIR"
    sudo chown root:root "$SHARE_DIR"
    sudo chmod 0777 "$SHARE_DIR"
else
    echo "Directory $SHARE_DIR already exists. Skipping creation."
fi

# Ensure the backup config exists and include the share directory for backup
if [ -w /etc ] || [ -w "$(dirname "$CONFIG_FILE" 2>/dev/null)" ]; then
    : # likely writable by current user (rare)
fi
CONFIG_FILE="/etc/backup_dirs.list"
if [ ! -f "$CONFIG_FILE" ]; then
    sudo touch "$CONFIG_FILE"
    sudo chmod 0644 "$CONFIG_FILE"
fi
# Add SHARE_DIR to the config if not already present
if ! sudo grep -Fxq "$SHARE_DIR" "$CONFIG_FILE"; then
    echo "Adding $SHARE_DIR to $CONFIG_FILE"
    echo "$SHARE_DIR" | sudo tee -a "$CONFIG_FILE" >/dev/null
fi

# Create users, set system password to match Samba password, and add Samba password
for raw in "${USERS[@]}"; do
    USER=$(echo "$raw" | xargs)
    PASS="${USER_PASSWORDS[$USER]:-}"

    # Create system user if it doesn't exist
    if ! id "$USER" &>/dev/null; then
        sudo adduser --disabled-password --gecos "" "$USER"
    fi

    if [ -n "$PASS" ]; then
        # Set system password (chpasswd reads 'user:password' pairs from stdin)
        echo "$USER:$PASS" | sudo chpasswd

        # Set Samba password: try to add (-a) first; if that fails because the user exists, update it.
        # Use a here-string to provide the password twice to smbpasswd -s (silent)
        if sudo smbpasswd -s -a "$USER" >/dev/null 2>&1 <<< "$PASS\n$PASS"; then
            : # added successfully
        else
            # If adding failed, try to set/change the password for existing samba user
            if sudo smbpasswd -s "$USER" >/dev/null 2>&1 <<< "$PASS\n$PASS"; then
                : # updated successfully
            else
                echo "Warning: failed to set Samba password for user '$USER'"
            fi
        fi
    else
        echo "No password provided for user '$USER' — skipping password set."
    fi
done

# Backup smb.conf only once (keep the original)
if [ ! -f /etc/samba/smb.conf.orig ]; then
    sudo cp /etc/samba/smb.conf /etc/samba/smb.conf.orig || true
fi

# Add global section for protocol compatibility if not present
if ! grep -q "server min protocol" /etc/samba/smb.conf; then
    sudo bash -c "cat >> /etc/samba/smb.conf <<'EOF'

[global]
   # Allow SMB1 for legacy clients while supporting SMB2/3
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

# Build valid users string (space-separated)
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

# Restart Samba services (try common service names)
sudo systemctl restart smbd.service || sudo systemctl restart smb.service || true

# Allow Samba through UFW if ufw exists
if command -v ufw >/dev/null 2>&1; then
    sudo ufw allow samba || true
fi

SERVER_IP=$(hostname -I 2>/dev/null | awk '{print $1}')
echo "Samba share setup complete. Access via: \\\\$SERVER_IP\\$SHARE_NAME"