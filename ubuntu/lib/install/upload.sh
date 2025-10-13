#!/bin/bash
# Upload all backups (or the latest backup) from /backup to a remote destination.
# Supports rsync over SSH or uploading to AWS S3 via aws CLI.

set -euo pipefail
IFS=$'\n\t'

BACKUP_ROOT="/backup"
LOG_FILE="/var/log/backup-upload.log"

usage() {
    cat <<EOF
Usage: $(basename "$0") [options]

Options:
  --dest user@host:/path     Upload via rsync over SSH to target path
  --s3-bucket s3://bucket/prefix  Upload to S3 using aws CLI
  --all                      Upload all dated backup subdirectories (default: latest only)
  --dry-run                  Show what would be uploaded but don't transfer
  --confirm                  Skip interactive confirmation
  --help                     Show this help
    --usb-label LABEL          Use USB device by label (mount and upload to it)
    --usb-device /dev/sdX1     Use specific USB device node (mount and upload to it)
    --mountpoint /path         Mountpoint to use for USB device (default: /mnt/usb-backups)

Examples:
  # Upload latest backup to remote host
  $(basename "$0") --dest backupuser@remote.example.com:/backups

  # Upload all backups to S3
  $(basename "$0") --s3-bucket s3://my-bucket/backups --all
EOF
}

log() { echo "$(date '+%F %T') - $*" | tee -a "$LOG_FILE"; }

die() { echo "$*" >&2; exit 1; }

# Parse args
DEST_RSYNCH=""
S3_BUCKET=""
UPLOAD_ALL=false
DRY_RUN=false
CONFIRM=false
USB_LABEL=""
USB_DEVICE=""
USB_MOUNTPOINT="/mnt/usb-backups"
MOUNTED_BY_SCRIPT=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dest)
            DEST_RSYNCH="$2"; shift 2;;
        --s3-bucket)
            S3_BUCKET="$2"; shift 2;;
        --all)
            UPLOAD_ALL=true; shift;;
        --dry-run)
            DRY_RUN=true; shift;;
        --confirm)
            CONFIRM=true; shift;;
        --usb-label)
            USB_LABEL="$2"; shift 2;;
        --usb-device)
            USB_DEVICE="$2"; shift 2;;
        --mountpoint)
            USB_MOUNTPOINT="$2"; shift 2;;
        -h|--help)
            usage; exit 0;;
        *)
            die "Unknown option: $1";
    esac
done

# Validate options
if [[ -z "$DEST_RSYNCH" && -z "$S3_BUCKET" && -z "$USB_LABEL" && -z "$USB_DEVICE" ]]; then
    usage
    die "Specify one of --dest, --s3-bucket, --usb-label or --usb-device"
fi

if [[ -n "$DEST_RSYNCH" && -n "$S3_BUCKET" ]] || [[ -n "$DEST_RSYNCH" && (-n "$USB_LABEL" || -n "$USB_DEVICE") ]] || [[ -n "$S3_BUCKET" && (-n "$USB_LABEL" || -n "$USB_DEVICE") ]]; then
    die "Specify only one target: --dest, --s3-bucket, or USB options"
fi

# Find backup directories
if [[ ! -d "$BACKUP_ROOT" ]]; then
    die "Backup root not found: $BACKUP_ROOT"
fi

mapfile -t BACKUP_DIRS < <(find "$BACKUP_ROOT" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort -r)
if [[ ${#BACKUP_DIRS[@]} -eq 0 ]]; then
    die "No backups found in $BACKUP_ROOT"
fi

if [[ "$UPLOAD_ALL" == false ]]; then
    TARGETS=("${BACKUP_DIRS[0]}")
else
    TARGETS=("${BACKUP_DIRS[@]}")
fi

log "Starting upload. Targets: ${TARGETS[*]}"

if [[ "$DRY_RUN" == true ]]; then
    log "Dry run mode enabled. No files will be transferred."
fi

if [[ "$CONFIRM" == false ]]; then
    echo "About to upload ${#TARGETS[@]} backup(s) from $BACKUP_ROOT to"
    if [[ -n "$DEST_RSYNCH" ]]; then
        echo "  rsync destination: $DEST_RSYNCH"
    else
        echo "  s3 destination: $S3_BUCKET"
    fi
    read -r -p "Proceed? [y/N]: " ans
    case "$ans" in
        [Yy]*) ;;
        *) log "Aborted by user."; exit 1;;
    esac
fi

# If USB options were provided, detect and mount device (sets DEST_RSYNCH to mountpoint)
if [[ -n "$USB_LABEL" || -n "$USB_DEVICE" ]]; then
    # detect device by label if requested
    if [[ -n "$USB_LABEL" && -z "$USB_DEVICE" ]]; then
        USB_DEVICE=$(blkid -o device -t LABEL="$USB_LABEL" || true)
        if [[ -z "$USB_DEVICE" ]]; then
            die "No block device found with LABEL=$USB_LABEL"
        fi
    fi

    if [[ -n "$USB_DEVICE" && ! -b "$USB_DEVICE" ]]; then
        die "Specified USB device is not a block device: $USB_DEVICE"
    fi

    sudo mkdir -p "$USB_MOUNTPOINT"
    # If not already mounted, mount it
    if ! mountpoint -q "$USB_MOUNTPOINT"; then
        log "Mounting $USB_DEVICE -> $USB_MOUNTPOINT"
        sudo mount "$USB_DEVICE" "$USB_MOUNTPOINT" || die "Failed to mount $USB_DEVICE to $USB_MOUNTPOINT"
        MOUNTED_BY_SCRIPT=true
    else
        log "$USB_MOUNTPOINT already mounted, using existing mount"
    fi

    # Use the mounted path as the rsync destination
    DEST_RSYNCH="$USB_MOUNTPOINT"
fi

# Upload loop
for t in "${TARGETS[@]}"; do
    SRC="$BACKUP_ROOT/$t/"
    if [[ -n "$DEST_RSYNCH" ]]; then
        # handle local path destinations (absolute path) vs remote rsync targets
        if [[ "$DEST_RSYNCH" == */*:* || "$DEST_RSYNCH" =~ @.*: ]]; then
            # remote rsync (user@host:/path)
            DEST_PATH="$DEST_RSYNCH/$t/"
        else
            # local filesystem destination
            DEST_PATH="$DEST_RSYNCH/$t/"
            sudo mkdir -p "$DEST_PATH"
            sudo chown --reference "$BACKUP_ROOT/$t" "$DEST_PATH" 2>/dev/null || true
        fi
        RSYNC_OPTS=( -a --delete )
        if [[ "$DRY_RUN" == true ]]; then
            RSYNC_OPTS+=(--dry-run -v)
        fi
        log "Uploading $SRC -> $DEST_PATH via rsync"
        rsync "${RSYNC_OPTS[@]}" "$SRC" "$DEST_PATH" 2>&1 | tee -a "$LOG_FILE"
    else
        # S3 upload - requires aws cli
        if ! command -v aws &> /dev/null; then
            die "aws CLI not found. Install and configure it to use --s3-bucket option."
        fi
        S3_PREFIX="$S3_BUCKET/$t/"
        if [[ "$DRY_RUN" == true ]]; then
            log "(dry-run) aws s3 sync $SRC $S3_PREFIX --delete"
            aws s3 sync "$SRC" "$S3_PREFIX" --delete --dryrun 2>&1 | tee -a "$LOG_FILE"
        else
            log "Uploading $SRC -> $S3_PREFIX via aws s3 sync"
            aws s3 sync "$SRC" "$S3_PREFIX" --delete 2>&1 | tee -a "$LOG_FILE"
        fi
    fi
done

log "Upload completed"

# If we mounted a USB device, unmount it now
if [[ "$MOUNTED_BY_SCRIPT" == true ]]; then
    log "Unmounting $USB_MOUNTPOINT"
    sudo umount "$USB_MOUNTPOINT" || log "Warning: failed to unmount $USB_MOUNTPOINT"
fi

exit 0
