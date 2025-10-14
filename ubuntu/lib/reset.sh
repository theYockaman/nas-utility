sync
#!/usr/bin/env bash
# Ubuntu Reset Script
# Improved: safer, configurable, and backs up before destructive actions

set -euo pipefail
IFS=$'\n\t'

SCRIPT_NAME=$(basename "$0")
LOGFILE="/var/log/ubuntu-reset.log"
DRY_RUN=0
ASSUME_YES=0
PRESERVE_SSH_KEYS=1
SKIP_PACKAGE_REMOVE=0
KEEP_USERS=("root" "ubuntu")

usage(){
    cat <<EOF
Usage: $SCRIPT_NAME [options]

Options:
  --yes                Assume yes to all prompts
  --dry-run            Show actions without executing
  --preserve-ssh-keys  Keep /etc/ssh/ssh_host_* (default)
  --no-preserve-ssh-keys  Remove host keys so they will be regenerated
  --skip-packages      Do not perform package autoremove/clean
  --keep-user USER     Preserve additional user (can be used multiple times)
  -h, --help           Show this help
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --yes) ASSUME_YES=1; shift ;;
        --dry-run) DRY_RUN=1; shift ;;
        --preserve-ssh-keys) PRESERVE_SSH_KEYS=1; shift ;;
        --no-preserve-ssh-keys) PRESERVE_SSH_KEYS=0; shift ;;
        --skip-packages) SKIP_PACKAGE_REMOVE=1; shift ;;
        --keep-user) KEEP_USERS+=("$2"); shift 2 ;;
        -h|--help) usage; exit 0 ;;
        *) echo "Unknown option: $1"; usage; exit 2 ;;
    esac
done

log(){
    echo "$(date '+%F %T') - $*" | tee -a "$LOGFILE"
}

run(){
    if [[ $DRY_RUN -eq 1 ]]; then
        echo "+DRY-RUN: $*"
    else
        eval "$@"
    fi
}

require_root(){
    if [[ $EUID -ne 0 ]]; then
        echo "This script must be run as root (sudo)." >&2
        exit 1
    fi
}

confirm_or_die(){
    if [[ $ASSUME_YES -eq 1 ]]; then return 0; fi
    read -p "$1 (y/N): " resp
    if [[ ! "$resp" =~ ^[Yy]$ ]]; then
        log "Aborted by user."
        exit 0
    fi
}

timestamp="$(date +%Y%m%d-%H%M%S)"
BACKUP_DIR="/root/reset-backups/$timestamp"

backup_paths(){
    log "Creating backup directory: $BACKUP_DIR"
    run mkdir -p "$BACKUP_DIR"
    log "Archiving /home to $BACKUP_DIR/home.tar.gz"
    run tar -czf "$BACKUP_DIR/home.tar.gz" -C / home || true
    log "Archiving /etc to $BACKUP_DIR/etc.tar.gz"
    run tar -czf "$BACKUP_DIR/etc.tar.gz" -C / etc || true
    log "Archiving /var/log to $BACKUP_DIR/var-log.tar.gz"
    run tar -czf "$BACKUP_DIR/var-log.tar.gz" -C / var/log || true
}

step_clear_homes(){
    log "[1/6] Clearing user home directories (preserving: ${KEEP_USERS[*]})"
    for d in /home/*; do
        [[ ! -d "$d" ]] && continue
        user=$(basename "$d")
        if printf '%s\n' "${KEEP_USERS[@]}" | grep -qx "$user"; then
            log " - Preserving /home/$user"
            continue
        fi
        log " - Wiping /home/$user"
        run rm -rf "$d"/* || true
        run rm -rf "$d"/.[!.]* "$d"/?* 2>/dev/null || true
    done
}

step_clear_logs_tmp(){
    log "[2/6] Clearing logs and temp files"
    run rm -rf /var/log/* || true
    run rm -rf /tmp/* /var/tmp/* || true
    run journalctl --rotate || true
    run journalctl --vacuum-time=1s || true
}

step_packages(){
    if [[ $SKIP_PACKAGE_REMOVE -eq 1 ]]; then
        log "[3/6] Skipping package autoremove/clean as requested"
        return
    fi
    log "[3/6] Removing non-essential packages (autoremove/purge)"
    run apt update -y || true
    # Reinstall ssh packages to be safe
    run apt install --reinstall -y openssh-server openssh-client || true
    run apt autoremove --purge -y || true
    run apt clean || true
}

step_network(){
    log "[4/6] Resetting network settings and hostname"
    run mkdir -p /etc/netplan/backup
    run cp -a /etc/netplan/*.yaml /etc/netplan/backup/ 2>/dev/null || true
    run rm -f /etc/netplan/*.yaml || true
    run cat <<'EOF' >/etc/netplan/01-default.yaml
network:
  version: 2
  renderer: networkd
  ethernets:
    eth0:
      dhcp4: true
EOF
    run hostnamectl set-hostname ubuntu || true
    run netplan apply || true
}

step_users(){
    log "[5/6] Removing non-system users (preserving: ${KEEP_USERS[*]})"
    # UIDs >= 1000 are normal users on Ubuntu (excluding nobody)
    mapfile -t users < <(awk -F: '$3 >= 1000 {print $1}' /etc/passwd)
    for user in "${users[@]}"; do
        if printf '%s\n' "${KEEP_USERS[@]}" | grep -qx "$user"; then
            log " - Preserving user: $user"
            continue
        fi
        log " - Deleting user: $user"
        run deluser --remove-home "$user" || true
    done
}

step_cleanup(){
    log "[6/6] Final cleanup"
    if [[ $PRESERVE_SSH_KEYS -eq 0 ]]; then
        log " - Removing SSH host keys so they will be regenerated"
        run rm -f /etc/ssh/ssh_host_* || true
    else
        log " - Preserving SSH host keys"
    fi
    log " - Reconfiguring openssh-server"
    run dpkg-reconfigure openssh-server || true
    run sync || true
}

# --- Main ---
require_root

log "=== Ubuntu Reset Script started ==="
log "Dry-run: $DRY_RUN  Assume-yes: $ASSUME_YES  Preserve-SSH-keys: $PRESERVE_SSH_KEYS  Skip-packages: $SKIP_PACKAGE_REMOVE"

if [[ $ASSUME_YES -ne 1 ]]; then
    echo "This will erase user data and reset many system settings but will keep SSH (unless you disable preserve)."
    confirm_or_die "Are you sure you want to continue?"
fi

log "Starting system reset... (logging to $LOGFILE)"

# Ensure ssh remains running during the reset
run systemctl enable ssh || true
run systemctl start ssh || true

# Create backups
backup_paths

# Steps
step_clear_homes
step_clear_logs_tmp
step_packages
step_network
step_users
step_cleanup

log "System reset complete. Backup archive created at $BACKUP_DIR"
log "SSH should still be active (if preserved)."

exit 0
