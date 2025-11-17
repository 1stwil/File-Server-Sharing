# Orange Pi 5 Pro NAS Setup

Personal NAS (Network Attached Storage) configuration using Orange Pi 5 Pro with software RAID and automated incremental backup system.

## Hardware Specifications

- **SBC**: Orange Pi 5 Pro
  - 8GB RAM
  - 512GB NVMe SSD (OS Drive)
  - OS: Ubuntu Server (Joshua-Riek build)
- **Storage Enclosure**: ORICO Multibay 8848RC3
  - 3x SATA SSD configured

## Storage Architecture

### RAID Configuration
Using `mdadm` for software RAID management:

- **SSD 1 & 2**: RAID 1 (Mirror)
  - Primary storage pool
  - Real-time redundancy protection
- **SSD 3**: Backup storage
  - Automated daily snapshots
  - 14-day retention policy
  - Hardlink-based incremental backups

### Why Software RAID?
Hardware RAID controller dari ORICO Multibay terlalu rigid untuk kebutuhan setup kompleks. Software RAID memberikan fleksibilitas penuh untuk custom configuration dan troubleshooting.

## Key Features

### Network File Sharing
- **Samba**: SMB/CIFS protocol for cross-platform file access
- **FACL**: Fine-grained permission management for multi-user access control

### Automated Backup System
Built with `rsync` hardlink snapshots:
- **Daily automated backups** via cronjob
- **Incremental snapshots** using `--link-dest` (unchanged files are hardlinked, not duplicated)
- **14-day rolling retention** with automatic cleanup
- **Space-efficient**: Only stores file deltas between snapshots
- **Point-in-time recovery**: Each snapshot is a complete browsable directory

#### How It Works
The backup system uses `rsync` with hardlinks to create space-efficient snapshots:
1. First backup creates a full copy
2. Subsequent backups only copy changed files
3. Unchanged files are hardlinked to previous snapshot
4. Each snapshot appears as a full backup but shares unchanged data
5. Old snapshots (>14 days) are automatically pruned

Example disk usage:
- Day 1: 100GB backup → 100GB used
- Day 2: 5GB changes → 105GB total (not 200GB)
- Day 14: ~120GB total for 14 complete daily snapshots

## System Requirements

- Ubuntu Server 20.04+ (Joshua-Riek's Orange Pi build)
- `mdadm` for RAID management
- `rsync` for backup operations
- `samba` for network file sharing
- `acl` package for FACL support

## Implementation

### Backup Script
Located at `/usr/local/bin/backup-raid.sh`:
- Pre-flight checks (mount points, source validation)
- Incremental backup with hardlinks
- Comprehensive logging to `/var/log/backup-raid.log`
- Automatic cleanup of expired snapshots

### Cronjob Schedule
