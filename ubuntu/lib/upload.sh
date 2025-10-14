#!/bin/bash
# Simple local uploader for backups created under /backup
# Copies dated backup directories to a local target directory (e.g. mounted USB)

set -euo pipefail
IFS=$'\n\t'

## Allow global configuration via /etc/nas-utility.conf
# If that file exists it can set BACKUP_DIR and optionally BACKUP_UPLOAD_LOG
NAS_CONF="/etc/nas-utility.conf"
if [[ -f "${NAS_CONF}" ]]; then
    # shellcheck disable=SC1090
    source "${NAS_CONF}"
fi

# BACKUP_DIR can be defined in the config; fall back to /backup
SOURCE_ROOT="${BACKUP_DIR:-/backup}"
# Allow overriding the upload log location from config as well
LOG_FILE="${BACKUP_UPLOAD_LOG:-/var/log/backup-upload.log}"

usage() {
    cat <<EOF
Usage: $(basename "$0") --target /path/to/mounted/drive [options]

Options:
  --target /path         Local target directory (required)
  --all                  Upload all dated backups (default: latest only)
  --date YYYY-MM-DD      Upload a specific dated backup
  --dry-run              Show what would be copied without transferring
        --confirm              Skip interactive confirmation
        --allow-root           Allow target to be the system root (/) — use with caution
    --backup-existing       Move existing destination paths to <path>.bak.<ts> before replacing
    --services-file /path   Path to file listing systemd services to stop before restore (one per line). Default: /etc/backup_restore_services.list
  --help                 Show this help

Example:
  sudo $(basename "$0") --target /mnt/usb-backups --all
EOF
}

log() { echo "$(date '+%F %T') - $*" | tee -a "$LOG_FILE"; }

die() { echo "$*" >&2; exit 1; }

# Parse args
TARGET=""
UPLOAD_ALL=false
SPECIFIC_DATE=""
DRY_RUN=false
CONFIRM=false
ALLOW_ROOT=false
BACKUP_EXISTING=false
SERVICES_FILE="/etc/backup_restore_services.list"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --target)
            TARGET="$2"; shift 2;;
        --all)
            UPLOAD_ALL=true; shift;;
        --date)
            SPECIFIC_DATE="$2"; shift 2;;
        --dry-run)
            DRY_RUN=true; shift;;
        --confirm)
            CONFIRM=true; shift;;
        --allow-root)
            ALLOW_ROOT=true; shift;;
        --backup-existing)
            BACKUP_EXISTING=true; shift;;
        --services-file)
            SERVICES_FILE="$2"; shift 2;;
        -h|--help)
            usage; exit 0;;
        *) die "Unknown option: $1";
    esac
done

if [[ -z "$TARGET" ]]; then
    usage; die "--target is required"
fi

if [[ ! -d "$TARGET" ]]; then
    die "Target directory does not exist or is not a directory: $TARGET"
fi

if [[ ! -d "$SOURCE_ROOT" ]]; then
    die "Source backup root not found: $SOURCE_ROOT"
fi

# Safety: restoring directly into system root is dangerous. Require explicit allow.
if [[ "$TARGET" == "/" ]]; then
    if [[ "$ALLOW_ROOT" != true ]]; then
        die "Target is / (system root). To proceed, re-run with --allow-root and be sure you understand this is destructive."
    fi
    log "Warning: proceeding to restore into system root (/). Ensure you have backups and have reviewed the config."
fi

# If destructive options are in use, ensure we're running as root
if [[ "$TARGET" == "/" || "$BACKUP_EXISTING" == true || -f "$SERVICES_FILE" ]]; then
    if [[ $EUID -ne 0 ]]; then
        die "This operation requires root. Please run with sudo."
    fi
fi

# Read configured backup paths so we can restore into the correct location names
# The installer writes paths into /etc/backup_dirs.list (one per line). We'll use that
# to map each backed-up basename back to its original absolute path.
CONFIG_FILE="/etc/backup_dirs.list"

# Build list of dated backups
if [[ -n "$SPECIFIC_DATE" ]]; then
    if [[ ! -d "$SOURCE_ROOT/$SPECIFIC_DATE" ]]; then
        die "Requested date not found: $SOURCE_ROOT/$SPECIFIC_DATE"
    fi
    TARGETS=("$SPECIFIC_DATE")
else
    mapfile -t ALL_DIRS < <(find "$SOURCE_ROOT" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort -r)
    if [[ ${#ALL_DIRS[@]} -eq 0 ]]; then
        die "No backups found in $SOURCE_ROOT"
    fi
    if [[ "$UPLOAD_ALL" == true ]]; then
        TARGETS=("${ALL_DIRS[@]}")
    else
        TARGETS=("${ALL_DIRS[0]}")
    fi
fi

if [[ ! -f "$CONFIG_FILE" ]]; then
    die "Backup config not found: $CONFIG_FILE"
fi

# Read configured paths (strip comments and empty lines)
mapfile -t CONFIG_PATHS < <(awk '{ gsub(/^[ \t]+|[ \t]+$/,"",$0); if ($0!~"^#" && $0!="") print $0 }' "$CONFIG_FILE")
if [[ ${#CONFIG_PATHS[@]} -eq 0 ]]; then
    die "No paths found in $CONFIG_FILE"
fi

log "Preparing to copy ${#TARGETS[@]} backup(s) to $TARGET"

if [[ "$CONFIRM" == false ]]; then
    echo "About to copy ${#TARGETS[@]} backup(s) from $SOURCE_ROOT to $TARGET"
    if [[ "$BACKUP_EXISTING" == true ]]; then
        echo "Existing destination paths will be moved to <path>.bak.<ts> before replacement"
    fi
    read -r -p "Proceed? [y/N]: " ans
    case "$ans" in
        [Yy]*) ;;
        *) log "Aborted by user."; exit 1;;
    esac
fi

# If services file exists (and list provided), stop services before restore
ACTIVE_SERVICES=()
if [[ -f "$SERVICES_FILE" ]]; then
    mapfile -t SERVICES_LIST < <(awk '{ gsub(/^[ \t]+|[ \t]+$/,"",$0); if ($0!~"^#" && $0!="") print $0 }' "$SERVICES_FILE")
    if [[ ${#SERVICES_LIST[@]} -gt 0 ]]; then
        log "Stopping services listed in $SERVICES_FILE"
        for svc in "${SERVICES_LIST[@]}"; do
            if systemctl is-active --quiet "$svc"; then
                ACTIVE_SERVICES+=("$svc")
                log "Stopping $svc"
                systemctl stop "$svc" || log "Warning: failed to stop $svc"
            else
                log "$svc is not active, skipping stop"
            fi
        done
    fi
fi

for d in "${TARGETS[@]}"; do
    DATE_DIR="$SOURCE_ROOT/$d"
    if [[ ! -d "$DATE_DIR" ]]; then
        log "Warning: date directory missing, skipping: $DATE_DIR"; continue
    fi

    # Copy config file into the upload target for traceability.
    if [[ ${#TARGETS[@]} -gt 1 ]]; then
        if [[ "$TARGET" == "/" ]]; then
            dest_config="/restore-backups/$d/backup_dirs.list"
        else
            dest_config="$TARGET/$d/backup_dirs.list"
        fi
    else
        if [[ "$TARGET" == "/" ]]; then
            dest_config="/backup-upload-config/backup_dirs.list"
        else
            dest_config="$TARGET/backup_dirs.list"
        fi
    fi

    if [[ "$DRY_RUN" == true ]]; then
        log "(dry-run) copy config $CONFIG_FILE -> $dest_config"
        else
            log "Copying config $CONFIG_FILE -> $dest_config"
            sudo mkdir -p "$(dirname "$dest_config")"
            sudo cp -a "$CONFIG_FILE" "$dest_config" || log "Warning: failed to copy config to $dest_config"
    fi

    # Prefer per-date mapping file (created by backup.sh). If present, it contains lines: encoded|original
    MAP_FILE="$DATE_DIR/backup_mapping.list"
    if [[ -f "$MAP_FILE" ]]; then
        log "Using mapping file $MAP_FILE for date $d"
        while IFS='|' read -r encoded orig; do
            [[ -z "$encoded" || -z "$orig" ]] && continue
            src_path="$DATE_DIR/$encoded/"

            if [[ "$TARGET" == "/" ]]; then
                if [[ ${#TARGETS[@]} -gt 1 ]]; then
                    dst_path="/restore-backups/$d$orig"
                else
                    dst_path="$orig"
                fi
            else
                if [[ ${#TARGETS[@]} -gt 1 ]]; then
                    dst_path="$TARGET/$d$orig"
                else
                    dst_path="$TARGET$orig"
                fi
            fi

            if [[ ! -d "$src_path" ]]; then
                log "Warning: source path not found in backup: $src_path (skipping)"; continue
            fi

            if [[ "$DRY_RUN" == true ]]; then
                log "(dry-run) rsync -aH --numeric-ids --delete \"$src_path\" \"$dst_path\""
                rsync -aH --numeric-ids --delete --dry-run "$src_path" "$dst_path" || true
            else
                log "Copying $src_path -> $dst_path"
                sudo mkdir -p "$(dirname "$dst_path")"
                if [[ "$BACKUP_EXISTING" == true && -e "$dst_path" ]]; then
                    ts=$(date +%s)
                    bakpath="${dst_path}.bak.${ts}"
                    log "Backing up existing path $dst_path -> $bakpath"
                    sudo mv "$dst_path" "$bakpath" || log "Warning: failed to move $dst_path to $bakpath"
                fi
                rsync -aH --numeric-ids --delete "$src_path" "$dst_path" 2>&1 | tee -a "$LOG_FILE" || log "rsync returned non-zero for $src_path -> $dst_path"
            fi
        done < "$MAP_FILE"
    else
        # Fallback: use configured original paths and assume backups used basenames
        for orig in "${CONFIG_PATHS[@]}"; do
            base=$(basename "$orig")
            src_path="$DATE_DIR/$base/"

            if [[ "$TARGET" == "/" ]]; then
                if [[ ${#TARGETS[@]} -gt 1 ]]; then
                    dst_path="/restore-backups/$d$orig"
                else
                    dst_path="$orig"
                fi
            else
                if [[ ${#TARGETS[@]} -gt 1 ]]; then
                    dst_path="$TARGET/$d$orig"
                else
                    dst_path="$TARGET$orig"
                fi
            fi

            if [[ ! -d "$src_path" ]]; then
                log "Warning: source path not found in backup: $src_path (skipping)"; continue
            fi

            if [[ "$DRY_RUN" == true ]]; then
                log "(dry-run) rsync -aH --numeric-ids --delete \"$src_path\" \"$dst_path\""
                rsync -aH --numeric-ids --delete --dry-run "$src_path" "$dst_path" || true
            else
                log "Copying $src_path -> $dst_path"
                sudo mkdir -p "$(dirname "$dst_path")"
                if [[ "$BACKUP_EXISTING" == true && -e "$dst_path" ]]; then
                    ts=$(date +%s)
                    bakpath="${dst_path}.bak.${ts}"
                    log "Backing up existing path $dst_path -> $bakpath"
                    sudo mv "$dst_path" "$bakpath" || log "Warning: failed to move $dst_path to $bakpath"
                fi
                rsync -aH --numeric-ids --delete "$src_path" "$dst_path" 2>&1 | tee -a "$LOG_FILE" || log "rsync returned non-zero for $src_path -> $dst_path"
            fi
        done
    fi
done

# Restart services that were active before restore
if [[ ${#ACTIVE_SERVICES[@]} -gt 0 ]]; then
    log "Restarting previously active services"
    for svc in "${ACTIVE_SERVICES[@]}"; do
        log "Starting $svc"
        systemctl start "$svc" || log "Warning: failed to start $svc"
    done
fi

log "Upload (copy) completed"

exit 0
