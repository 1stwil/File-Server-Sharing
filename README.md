# File server sharing setup

Internal file sharing server configuration using Orange Pi 5 Pro with software RAID and automated incremental backup system.

## Hardware that i use

- **SBC**: Orange Pi 5 Pro
  - 8GB RAM
  - 512GB NVMe SSD (OS Drive)
  - OS: Ubuntu Server (Joshua-Riek build)
- **Storage Enclosure**: ORICO Multibay 8848RC3
  - 3x SATA SSD configured (i am using 512gb on each SATA)

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
ORICO Multibay's hardware RAID controller doesn't offer enough flexibility for this custom setup. Software RAID gives complete control over configuration and makes troubleshooting easier.

### Key Features

### Network File Sharing
- **Samba**: SMB/CIFS protocol for cross-platform file access over LAN
- **FACL (File Access Control Lists)**: Advanced permission system beyond standard Unix permissions
- **LAN-only access**: File sharing works within the same local network via Ethernet/WiFi
- **No internet required**: Direct connection between devices on the same network

**Network Requirements:**
- Devices must be connected to the same local network (router/switch)
- No remote access from outside network (by design for security)

#### Advanced Permission Management with FACL
Traditional Unix permissions (owner/group/others) are limited to 3 permission sets. FACL extends this with granular per-user and per-group control:

**Example use cases:**
- **Group X**: Read-only access to `/shared/reports`
- **Group Y**: Read + Write access to `/shared/reports`
- **Group Z**: No access (folder hidden from view)

This allows multiple user groups to share the same storage with different permission levels per folder, all managed at the filesystem level.

**Benefits over standard permissions:**
- Multiple groups with different permissions on same directory
- Per-user exceptions without creating new groups
- Inherited permissions for new files/folders
- Folder visibility control (hide folders from unauthorized users)

#### Automated Backup System
Built with `rsync` hardlink snapshots:
- **Daily automated backups** via cronjob - no manual intervention required
- **Incremental snapshots** using `--link-dest` (unchanged files are hardlinked, not duplicated)
- **14-day rolling retention** with automatic cleanup
- **Point-in-time recovery**: Restore accidentally deleted or modified files within 14-day window
- **Space-efficient**: Only stores file deltas between snapshots

#### RAID 1 Redundancy
- **Real-time mirror protection**: If one SSD fails, data remains accessible from the other drive
- **Hot-swappable recovery**: Replace failed drive without data loss or downtime
- **Automatic rebuild**: RAID array syncs data to replacement drive automatically

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
```
0 20 * * * /usr/local/bin/backup-raid.sh
```
Runs daily at 20:00 (8:00 PM). Adjust the hour field as needed for your preferred backup time.

