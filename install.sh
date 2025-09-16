#!/bin/bash
#
# Borg Backup Installation Script
# Installs and configures borg backup system for madlab
#

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    log_error "This script must be run as root"
    exit 1
fi

log_info "Starting Borg Backup installation..."

# Detect package manager and install borgbackup
if command -v zypper >/dev/null 2>&1; then
    # OpenSUSE/SLES
    log_info "Installing borgbackup via zypper..."
    zypper install -y borgbackup nfs-utils
elif command -v apt >/dev/null 2>&1; then
    # Debian/Ubuntu
    log_info "Installing borgbackup via apt..."
    apt update
    apt install -y borgbackup nfs-common
elif command -v yum >/dev/null 2>&1; then
    # RHEL/CentOS
    log_info "Installing borgbackup via yum..."
    yum install -y borgbackup nfs-utils
elif command -v dnf >/dev/null 2>&1; then
    # Fedora
    log_info "Installing borgbackup via dnf..."
    dnf install -y borgbackup nfs-utils
else
    log_error "Unsupported package manager. Please install borgbackup manually."
    exit 1
fi

# Verify borgbackup installation
if ! command -v borg >/dev/null 2>&1; then
    log_error "borgbackup installation failed"
    exit 1
fi

log_info "borgbackup installed successfully: $(borg --version)"

# Create configuration directory
log_info "Creating configuration directory..."
mkdir -p /etc/borg-backup
chmod 700 /etc/borg-backup

# Copy configuration file
log_info "Installing configuration file..."
cp config /etc/borg-backup/config
chmod 600 /etc/borg-backup/config

log_warn "Please edit /etc/borg-backup/config and set a secure BORG_PASSPHRASE!"

# Copy backup script
log_info "Installing backup script..."
cp borg-backup.sh /usr/local/bin/
chmod 755 /usr/local/bin/borg-backup.sh

# Install systemd service files
log_info "Installing systemd service files..."
cp borg-backup.service /etc/systemd/system/
cp borg-backup.timer /etc/systemd/system/

# Create log directory
log_info "Setting up logging..."
mkdir -p /var/log
touch /var/log/borg-backup.log
chmod 644 /var/log/borg-backup.log

# Create mount point
log_info "Creating NFS mount point..."
mkdir -p /mnt/borg-nfs

# Reload systemd
log_info "Reloading systemd..."
systemctl daemon-reload

# Enable but don't start the timer yet
log_info "Enabling borg backup timer..."
systemctl enable borg-backup.timer

log_info "Installation completed successfully!"
echo
log_info "Next steps:"
echo "1. Edit /etc/borg-backup/config and set a secure BORG_PASSPHRASE"
echo "2. Customize backup paths and exclusions in the config file"
echo "3. Test the backup manually: systemctl start borg-backup.service"
echo "4. Check logs: journalctl -u borg-backup.service"
echo "5. Start the timer: systemctl start borg-backup.timer"
echo "6. Verify timer status: systemctl status borg-backup.timer"
echo
log_warn "Important: Make sure the NFS server (172.16.0.99) is accessible and the path /mnt/nfs/borg-backup exists!"