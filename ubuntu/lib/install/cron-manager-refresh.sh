#!/usr/bin/env bash
set -euo pipefail

# install-pythonRefresh-cron.sh
# Installs pythonRefresh.sh to /usr/local/bin and sets up a weekly cron entry.
# Run with sudo to install system-wide (root crontab). Use --user to install in the invoking user's crontab.

TARGET_BIN="/usr/local/bin/pythonRefresh.sh"
SRC_SCRIPT="ubuntu/lib/install/pythonRefresh.sh"
CRON_TIME_DEFAULT="0 3 * * 0" # weekly, Sunday 03:00
CRON_TIME="${CRON_TIME:-$CRON_TIME_DEFAULT}"
INSTALL_USER=0
DRY_RUN=0

print_help(){
  cat <<EOF
Usage: $0 [options]

Options:
  --src PATH       Path to source pythonRefresh.sh (default: $SRC_SCRIPT)
  --target PATH    Destination path (default: $TARGET_BIN)
  --time "CRON"    Cron schedule expression (default: "$CRON_TIME_DEFAULT")
  --user           Install crontab for the current user instead of root
  --dry-run        Print actions without making changes
  -h, --help       Show this help
EOF
}

while [[ ${#} -gt 0 ]]; do
  case "$1" in
    --src) SRC_SCRIPT="$2"; shift 2;;
    --target) TARGET_BIN="$2"; shift 2;;
    --time) CRON_TIME="$2"; shift 2;;
    --user) INSTALL_USER=1; shift;;
    --dry-run) DRY_RUN=1; shift;;
    -h|--help) print_help; exit 0;;
    --) shift; break;;
    *) echo "Unknown option: $1"; print_help; exit 2;;
  esac
done

run_cmd(){
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "+ $*"
  else
    echo "+ $*"
    eval "$@"
  fi
}

echo "Installer: will copy $SRC_SCRIPT -> $TARGET_BIN and install weekly cron ($CRON_TIME)"

# Find full paths
SRC_ABS="$PWD/$SRC_SCRIPT"
if [ ! -f "$SRC_ABS" ]; then
  echo "Source script not found: $SRC_ABS" >&2
  exit 1
fi

echo "Copying script to $TARGET_BIN"
run_cmd sudo mkdir -p "$(dirname "$TARGET_BIN")"
run_cmd sudo cp -f "$SRC_ABS" "$TARGET_BIN"
run_cmd sudo chmod 755 "$TARGET_BIN"

# Prepare cron line
CRON_CMD="$TARGET_BIN >> /var/log/pythonRefresh.log 2>&1"
CRON_LINE="$CRON_TIME $CRON_CMD"

if [ "$INSTALL_USER" -eq 1 ]; then
  echo "Installing cron line into current user's crontab"
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "+ (user) crontab entry: $CRON_LINE"
  else
    # Modify the current user's crontab
    crontab -l 2>/dev/null | grep -v -F "$CRON_CMD" | { cat; echo "$CRON_LINE"; } | crontab -
    echo "User crontab updated"
  fi
else
  echo "Installing cron line into root crontab (requires sudo)"
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "+ (root) crontab entry: $CRON_LINE"
  else
    sudo crontab -l 2>/dev/null | grep -v -F "$CRON_CMD" | { cat; echo "$CRON_LINE"; } | sudo crontab -
    echo "Root crontab updated"
  fi
fi

echo "Done. Verify logs at /var/log/pythonRefresh.log after the job runs."

# Register important backup paths so the backup runner picks them up
BACKUP_LIST="/etc/backup_dirs.list"
register() {
  local path="$1"
  sudo mkdir -p "$(dirname "$BACKUP_LIST")"
  sudo touch "$BACKUP_LIST"
  if ! sudo grep -Fxq "$path" "$BACKUP_LIST"; then
    echo "$path" | sudo tee -a "$BACKUP_LIST" >/dev/null
  fi
}

# Register the installed script and its log, plus the nas-utility config dir
register "/usr/local/bin/pythonRefresh.sh"
register "/var/log/pythonRefresh.log"
# Include the directory where python requirement snapshots are stored
register "/etc/nas-utility"
