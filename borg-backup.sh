#!/bin/bash
#
# Borg Backup Script for madlab
# Backs up client to NFS share at 172.16.0.99/mnt/nfs/borg-backup/<hostname>-<date>T<time>
#

set -euo pipefail

# Configuration
CONFIG_FILE="${CONFIG_FILE:-/etc/borg-backup/config}"
LOG_FILE="${LOG_FILE:-/var/log/borg-backup.log}"

# Default configuration (can be overridden in config file)
NFS_SERVER="172.16.0.99"
NFS_PATH="/mnt/nfs/borg-backup"
HOSTNAME=$(hostname -s)
BACKUP_PATHS="/home /etc /var/log /root"
EXCLUDE_PATTERNS="*/.cache/* */tmp/* */.tmp/* */lost+found/* */__pycache__/*"
PRUNE_KEEP_DAILY=7
PRUNE_KEEP_WEEKLY=4
PRUNE_KEEP_MONTHLY=6
MOUNT_POINT="/mnt/borg-nfs"
BORG_PASSPHRASE=""

# Load configuration file if it exists
if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
fi

# Logging function
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Error handling
error_exit() {
    log "ERROR: $1"
    exit 1
}

# Cleanup function
cleanup() {
    if mountpoint -q "$MOUNT_POINT" 2>/dev/null; then
        log "Unmounting NFS share"
        umount "$MOUNT_POINT" || log "Warning: Failed to unmount $MOUNT_POINT"
    fi
}

# Set up signal handlers
trap cleanup EXIT INT TERM

# Check if borg is installed
if ! command -v borg >/dev/null 2>&1; then
    error_exit "borgbackup is not installed. Please install it first."
fi

# Check if running as root (recommended for system backups)
if [[ $EUID -ne 0 ]]; then
    log "Warning: Not running as root. Some files may be inaccessible."
fi

# Create mount point if it doesn't exist
if [[ ! -d "$MOUNT_POINT" ]]; then
    log "Creating mount point: $MOUNT_POINT"
    mkdir -p "$MOUNT_POINT" || error_exit "Failed to create mount point"
fi

# Mount NFS share
log "Mounting NFS share: $NFS_SERVER:$NFS_PATH"
if ! mount -t nfs "$NFS_SERVER:$NFS_PATH" "$MOUNT_POINT"; then
    error_exit "Failed to mount NFS share"
fi

# Generate repository path with hostname and timestamp
TIMESTAMP=$(date '+%Y%m%dT%H%M%S')
REPO_NAME="${HOSTNAME}-${TIMESTAMP}"
REPO_PATH="${MOUNT_POINT}/${REPO_NAME}"

log "Starting backup to repository: $REPO_PATH"

# Initialize repository if it doesn't exist
if [[ ! -d "$REPO_PATH" ]]; then
    log "Initializing new borg repository"
    export BORG_PASSPHRASE
    borg init --encryption=repokey "$REPO_PATH" || error_exit "Failed to initialize repository"
fi

# Create backup archive
ARCHIVE_NAME="${HOSTNAME}-$(date '+%Y-%m-%d-%H%M%S')"
log "Creating archive: $ARCHIVE_NAME"

# Build exclude parameters
EXCLUDE_ARGS=""
for pattern in $EXCLUDE_PATTERNS; do
    EXCLUDE_ARGS="$EXCLUDE_ARGS --exclude '$pattern'"
done

# Export passphrase for borg commands
export BORG_PASSPHRASE

# Create the backup
log "Backing up paths: $BACKUP_PATHS"
eval "borg create --verbose --filter AME --list --stats --show-rc --compression lz4 $EXCLUDE_ARGS '$REPO_PATH::$ARCHIVE_NAME' $BACKUP_PATHS" || error_exit "Backup creation failed"

# Prune old archives (only if this is a recurring backup, not timestamp-based)
# Note: Since we're creating timestamp-based repos, pruning happens at repo level
log "Listing archives in repository"
borg list "$REPO_PATH"

# Cleanup old repositories (keep based on timestamp in directory name)
log "Cleaning up old backup repositories"
find "$MOUNT_POINT" -maxdepth 1 -type d -name "${HOSTNAME}-*T*" -mtime +${PRUNE_KEEP_DAILY:-7} -exec rm -rf {} \; 2>/dev/null || true

# Verify backup
log "Verifying backup integrity"
borg check "$REPO_PATH" || log "Warning: Backup verification failed"

# Get backup info
log "Backup completed successfully!"
borg info "$REPO_PATH::$ARCHIVE_NAME"

log "Backup operation completed"