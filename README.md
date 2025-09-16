# Madlab Borg Backup

Automated backup solution using BorgBackup to an NFS share.

## Overview

This system creates timestamped borg repositories on an NFS share at `172.16.0.99/mnt/nfs/borg-backup/` with the format: `<hostname>-<date>T<time>`

## Files

- `borg-backup.sh` - Main backup script
- `config` - Configuration file with backup settings
- `borg-backup.service` - Systemd service file
- `borg-backup.timer` - Systemd timer for daily backups
- `install.sh` - Installation script

## Installation

1. Run the installation script as root:
```bash
sudo ./install.sh
```

2. Edit the configuration file:
```bash
sudo nano /etc/borg-backup/config
```

3. Set a secure passphrase and customize backup paths.

4. Test the backup:
```bash
sudo systemctl start borg-backup.service
```

5. Enable daily backups:
```bash
sudo systemctl start borg-backup.timer
```

## Configuration

The main configuration options in `/etc/borg-backup/config`:

- `NFS_SERVER` - NFS server IP (default: 172.16.0.99)
- `NFS_PATH` - NFS export path (default: /mnt/nfs/borg-backup)
- `BACKUP_PATHS` - Directories to backup
- `EXCLUDE_PATTERNS` - File patterns to exclude
- `BORG_PASSPHRASE` - Repository encryption passphrase
- `PRUNE_KEEP_DAILY` - Number of daily backups to retain

## Usage

### Manual Backup
```bash
sudo systemctl start borg-backup.service
```

### Check Status
```bash
systemctl status borg-backup.service
systemctl status borg-backup.timer
```

### View Logs
```bash
journalctl -u borg-backup.service
tail -f /var/log/borg-backup.log
```

### List Backups
```bash
# Mount NFS share
sudo mount -t nfs 172.16.0.99:/mnt/nfs/borg-backup /mnt/borg-nfs

# List repository directories
ls -la /mnt/borg-nfs/

# List archives in a specific repository
borg list /mnt/borg-nfs/hostname-20240101T120000/
```

## Repository Structure

Each backup creates a new repository with timestamp:
```
/mnt/nfs/borg-backup/
├── hostname-20240101T120000/
├── hostname-20240102T120000/
└── hostname-20240103T120000/
```

## Troubleshooting

1. **NFS mount fails**: Ensure NFS server is accessible and nfs-utils is installed
2. **Permission denied**: Check that backup script runs as root
3. **Repository locked**: Previous backup may have failed, remove lock file
4. **Disk full**: Check available space on NFS share

## Security Notes

- Repository passphrase is stored in `/etc/borg-backup/config` (mode 600)
- Backups run as root to access all system files
- Network traffic to NFS server is unencrypted (consider VPN/secure network)
- Repository data is encrypted with the passphrase