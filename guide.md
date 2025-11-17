# Samba NAS Setup Guide

## Prerequisites
- Ubuntu Server with root/sudo access
- Network connectivity

---

## 1. Samba Installation

### Install Samba package
```bash
sudo apt update
sudo apt install samba acl -y
```

### Verify installation
```bash
smbd --version
```

### Start and enable Samba service
```bash
sudo systemctl start smbd
sudo systemctl enable smbd
sudo systemctl status smbd
```

---

## 2. User Management

### Create System User (Samba-only, no shell access)
```bash
sudo useradd -M -s /sbin/nologin username
```
**Flags:**
- `-M` : Don't create home directory
- `-s /sbin/nologin` : No shell access (security best practice)

### Set Samba Password
```bash
sudo smbpasswd -a username
```
Enter password when prompted.

### Enable Samba User
```bash
sudo smbpasswd -e username
```

### List All Samba Users
```bash
sudo pdbedit -L
```

### List Samba Users (Detailed)
```bash
sudo pdbedit -L -v
```

### List All System Users
```bash
cat /etc/passwd | cut -d: -f1
```

### List System Users (Exclude System Accounts)
```bash
grep -v "/sbin/nologin\|/bin/false" /etc/passwd
```

### Delete Samba User
```bash
sudo smbpasswd -x username
sudo userdel username
```

---

## 3. Group Management

### Create Group
```bash
sudo groupadd groupname
```

### Create Group with Specific GID (Recommended)
```bash
sudo groupadd -g 3001 groupname
```
**Why specific GID?**
- Easier to track and organize
- Consistent across system reinstalls
- Recommended range: 3000-3999 for custom groups

### List Specific Group
```bash
getent group groupname
```

### List All Groups
```bash
getent group
```

### Check Group Members
```bash
getent group groupname
```

---

## 4. User-Group Assignment

### Add User to Group (Secondary Group)
```bash
sudo usermod -a -G groupname username
```
**Flags:**
- `-a` : Append (don't remove from other groups)
- `-G` : Secondary group

**IMPORTANT:** Always use `-a` flag to avoid removing user from existing groups.

### Change User Primary Group (Not Recommended for Samba)
```bash
sudo usermod -g groupname username
```
Only use if you understand primary vs secondary groups.

### Remove User from Group
```bash
sudo gpasswd -d username groupname
```

### Verify User Groups
```bash
groups username
id username
```

---

## 5. Group Modification

### Rename Group
```bash
sudo groupmod -n newgroupname oldgroupname
```

### Change Group ID
```bash
sudo groupmod -g 3002 groupname
```

### Delete Group
```bash
sudo groupdel groupname
```
**Warning:** Ensure no users depend on this group for permissions.

---

## 6. Permission Verification

### Check File/Folder Permissions
```bash
ls -lah /path/to/directory
```

### Check Detailed Permissions (with FACL)
```bash
getfacl /path/to/directory
```

---

## 7. RAID Management (mdadm)
# RAID 1 Setup Guide (mdadm)

Complete guide for setting up software RAID 1 on Ubuntu Server using mdadm.

---

## Prerequisites

- Two identical (or similar size) drives
- Ubuntu Server with root/sudo access
- **WARNING:** This process will WIPE ALL DATA on the selected drives

---

## Step 1: Identify Available Disks

List all available disks:
```bash
lsblk
```

Check detailed disk information:
```bash
sudo fdisk -l /dev/sda
sudo fdisk -l /dev/sdb
```

**IMPORTANT:** 
- Verify disk names (`/dev/sda`, `/dev/sdb`, etc.) - yours may differ
- Ensure disks are empty or backup data first
- Creating RAID will destroy all existing data

---

## Step 2: Create RAID 1 Array

Create RAID 1 mirror with two drives:
```bash
sudo mdadm --create --verbose /dev/md0 \
  --level=1 \
  --raid-devices=2 \
  /dev/sda /dev/sdb
```

**Command breakdown:**
- `--create` : Create new RAID array
- `--verbose` : Show detailed output
- `/dev/md0` : RAID device name
- `--level=1` : RAID 1 (mirror)
- `--raid-devices=2` : Number of drives in array
- `/dev/sda /dev/sdb` : The two drives to mirror

**Confirmation prompt:**
```
Continue creating array? (y/n)
```
Type: `y`

---

## Step 3: Monitor RAID Synchronization

Check sync status:
```bash
cat /proc/mdstat
```

**Expected output:**
```
md0 : active raid1 sdb[1] sda[0]
      976762584 blocks super 1.2 [2/2] [UU]
      [==>..................]  resync = 12.6% (123034432/976762584)
```

**Real-time monitoring:**
```bash
watch -n 1 cat /proc/mdstat
```
Press `Ctrl+C` to exit watch.

**Note:** Initial sync can take several hours for large drives. This is normal.

---

## Step 4: Verify RAID Details

Check detailed RAID information:
```bash
sudo mdadm --detail /dev/md0
```

**Output shows:**
- RAID Level
- Array Size
- Number of Devices
- Active Devices
- Working Devices
- State (clean, syncing, degraded)

---

## Step 5: Save RAID Configuration

Scan and save RAID configuration:
```bash
sudo mdadm --detail --scan | sudo tee -a /etc/mdadm/mdadm.conf
```

Verify saved configuration:
```bash
cat /etc/mdadm/mdadm.conf
```

**Update initramfs (CRITICAL for boot):**
```bash
sudo update-initramfs -u
```

**Why this matters:** Without updating initramfs, RAID won't auto-assemble on boot.

---

## Step 6: Create Filesystem

### Option A: Standard ext4
```bash
sudo mkfs.ext4 /dev/md0
```

### Option B: Optimized for NAS (Recommended)
```bash
sudo mkfs.ext4 -L STORAGE -m 0 -T largefile4 /dev/md0
```

**Flags explained:**
- `-L STORAGE` : Label the filesystem
- `-m 0` : Reserve 0% for root (default 5% wastes space on data drives)
- `-T largefile4` : Optimize for large files

**Example:** On 1TB drive, `-m 0` saves ~50GB of usable space.

---

## Step 7: Create Mount Point

Create directory for mounting RAID:
```bash
sudo mkdir -p /mnt/STORAGE
```

---

## Step 8: Mount RAID Array

Mount the RAID device:
```bash
sudo mount /dev/md0 /mnt/STORAGE
```

Verify mount:
```bash
df -h | grep STORAGE
mount | grep md0
```

---

## Step 9: Configure Auto-Mount on Boot

Backup current fstab:
```bash
sudo cp /etc/fstab /etc/fstab.backup
```

Add RAID to fstab:
```bash
echo '/dev/md0 /mnt/STORAGE ext4 defaults,nofail 0 2' | sudo tee -a /etc/fstab
```

**fstab options explained:**
- `defaults` : Standard mount options
- `nofail` : System boots even if RAID fails to mount
- `0` : No dump backup
- `2` : Filesystem check order (after root filesystem)

Test fstab configuration:
```bash
sudo umount /mnt/STORAGE
sudo mount -a
```

Verify successful mount:
```bash
df -h | grep STORAGE
```

---

## Step 10: Set Initial Permissions

Set root ownership:
```bash
sudo chown root:root /mnt/STORAGE
sudo chmod 755 /mnt/STORAGE
```

Create initial directory structure:
```bash
sudo mkdir -p /mnt/STORAGE/shared
sudo mkdir -p /mnt/STORAGE/departments
sudo mkdir -p /mnt/STORAGE/backups
```

---

## Verification Checklist

Run these commands to verify successful setup:

### Check RAID status
```bash
cat /proc/mdstat
```
Expected: `[UU]` indicates both drives active

### Check RAID details
```bash
sudo mdadm --detail /dev/md0
```
Expected: State should be `clean`

### Check filesystem and space
```bash
df -h | grep STORAGE
```

### Check mount options
```bash
mount | grep md0
```

### Verify fstab entry
```bash
grep md0 /etc/fstab
```

### Test reboot persistence
```bash
sudo reboot
```
After reboot, verify mount:
```bash
df -h | grep STORAGE
```

---

## Common Issues & Troubleshooting

### RAID not auto-assembling on boot
```bash
# Reassemble manually
sudo mdadm --assemble --scan

# Check if mdadm.conf is configured
cat /etc/mdadm/mdadm.conf

# Update initramfs
sudo update-initramfs -u
```

### Check for RAID errors
```bash
sudo mdadm --detail /dev/md0 | grep -i error
```

### Force RAID read-write mode
```bash
sudo mdadm --readwrite /dev/md0
```

### One drive failed - check status
```bash
cat /proc/mdstat
sudo mdadm --detail /dev/md0
```

---

## Important Notes

1. **Disk identification:** Always verify disk names with `lsblk` before creating array. Using wrong disks will cause data loss.

2. **Sync time:** Initial synchronization can take 4-12 hours depending on drive size. Don't interrupt this process.

3. **Reserved space (`-m 0`):** Default ext4 reserves 5% for root. On data drives, this wastes space. Use `-m 0` to reclaim it.

4. **`nofail` option:** Prevents boot failure if RAID has issues. System will boot normally, and you can troubleshoot RAID separately.

5. **initramfs update:** CRITICAL step. Skip this and RAID won't auto-assemble on boot.

6. **Monitoring:** Regularly check RAID status with `cat /proc/mdstat` to catch drive failures early.

---

## Next Steps

After RAID setup is complete:
1. Configure Samba for network sharing
2. Set up FACL for advanced permissions
3. Configure automated backups
4. Set up monitoring/alerts for RAID health

---

### Check RAID Status
```bash
cat /proc/mdstat
```
Shows active RAID arrays and their member disks.

### Check Mount Status
```bash
mount | grep STORAGE
```
Replace `STORAGE` with your mount point name.

### Examine RAID Members
```bash
sudo mdadm --examine /dev/sda /dev/sdb /dev/sdc
```
Shows RAID metadata for each disk.

### Stop RAID Before Power Off

**Step 1:** Unmount the filesystem
```bash
sudo umount /mnt/STORAGE
```

**Step 2:** Stop RAID array
```bash
sudo mdadm --stop /dev/md0
```

**IMPORTANT:** Always unmount before stopping RAID to prevent data corruption.

---

## 8. RAID Recovery (After Power Loss)

### Reassemble RAID Array
```bash
sudo mdadm --assemble --scan
```
Automatically detects and assembles RAID arrays.

### Mount RAID Manually
```bash
sudo mount /dev/md0 /mnt/STORAGE
```

### Mount All (Using fstab)
```bash
sudo mount -a
```

### Set RAID to Read-Write Mode
```bash
sudo mdadm --readwrite /dev/md0
```
Use if array is stuck in read-only mode.

---

## 9. FACL (Advanced Permissions)

### Basic FACL Syntax
```bash
sudo setfacl -m [target]:[name]:[permissions] /path/to/directory
```

**Target types:**
- `u:username` - Specific user
- `g:groupname` - Specific group
- `o` - Others

**Permissions:**
- `r` - Read
- `w` - Write
- `x` - Execute

### Example: Multi-Group Permission Setup

**Scenario:** `/mnt/STORAGE/DEPARTMENTS/finance` folder needs:
- IT team: Full access (rwx)
- Finance team: Full access (rwx)
- Accounting team: Read-only (r-x)
- HR team: No access
```bash
# Set group ownership
sudo chgrp it_team /mnt/STORAGE/DEPARTMENTS/finance
sudo chmod 2775 /mnt/STORAGE/DEPARTMENTS/finance

# Grant permissions to existing files/folders
sudo setfacl -R -m g:it_team:rwx /mnt/STORAGE/DEPARTMENTS/finance
sudo setfacl -R -m g:finance_team:rwx /mnt/STORAGE/DEPARTMENTS/finance
sudo setfacl -R -m g:accounting_team:r-x /mnt/STORAGE/DEPARTMENTS/finance

# Set default permissions for NEW files/folders
sudo setfacl -R -m d:g:it_team:rwx /mnt/STORAGE/DEPARTMENTS/finance
sudo setfacl -R -m d:g:finance_team:rwx /mnt/STORAGE/DEPARTMENTS/finance
sudo setfacl -R -m d:g:accounting_team:r-x /mnt/STORAGE/DEPARTMENTS/finance
```

**Flags explained:**
- `-R` : Recursive (apply to all files/folders inside)
- `-m` : Modify ACL
- `d:` : Default ACL (inherited by new files/folders)
- `2775` : SetGID bit + rwxrwxr-x permissions

### Verify FACL Permissions
```bash
getfacl /mnt/STORAGE/DEPARTMENTS/finance
```

### Remove FACL Entry
```bash
sudo setfacl -x g:groupname /path/to/directory
```

### Remove All FACL Entries
```bash
sudo setfacl -b /path/to/directory
```

---

## 10. Process Management

### Check Which Process is Using Directory
```bash
sudo fuser -m /mnt/STORAGE
```

### Force Kill Processes Using Directory
```bash
sudo fuser -km /mnt/STORAGE
```
**Warning:** This forcefully terminates processes. Use with caution.

---

## 11. Samba Configuration

### Main Configuration File
```bash
sudo nano /etc/samba/smb.conf
```

### Legacy Windows Compatibility (Windows 7/XP)
Add to `[global]` section:
```ini
[global]
min protocol = NT1
max protocol = SMB3
ntlm auth = yes
```

**Note:** Only enable if you have legacy Windows clients. NT1 is outdated and less secure.

### Restart Samba After Config Changes
```bash
sudo systemctl restart smbd
sudo systemctl restart nmbd
```

### Test Samba Configuration
```bash
testparm
```

---

## 12. Backup System

### Backup Script Location
```bash
sudo nano /usr/local/bin/backup-raid.sh
```

### Edit Cronjob
```bash
sudo crontab -e
```

### View Backup Logs
```bash
tail -f /var/log/backup-raid.log
```

### View Last 50 Log Lines
```bash
tail -n 50 /var/log/backup-raid.log
```

---

## Quick Reference Commands

| Task | Command |
|------|---------|
| Create Samba user | `sudo useradd -M -s /sbin/nologin user` |
| Set Samba password | `sudo smbpasswd -a user` |
| Enable Samba user | `sudo smbpasswd -e user` |
| List Samba users | `sudo pdbedit -L` |
| Create group (with GID) | `sudo groupadd -g 3001 group` |
| Add user to group | `sudo usermod -a -G group user` |
| Remove user from group | `sudo gpasswd -d user group` |
| List group members | `getent group group` |
| Check user groups | `groups user` |
| Delete group | `sudo groupdel group` |
| Check RAID status | `cat /proc/mdstat` |
| Stop RAID safely | `sudo umount /mnt/STORAGE && sudo mdadm --stop /dev/md0` |
| Reassemble RAID | `sudo mdadm --assemble --scan` |
| Apply FACL | `sudo setfacl -R -m g:group:rwx /path` |
| Check FACL | `getfacl /path` |
| Kill processes on mount | `sudo fuser -km /mnt/STORAGE` |
| Restart Samba | `sudo systemctl restart smbd` |

---

## Recommended Group ID Ranges
- **1000-2999**: Regular user primary groups
- **3000-3999**: Custom Samba groups (recommended)
- **4000+**: Reserved for future use

## FACL Permission Examples

### Read-Write Access
```bash
sudo setfacl -R -m g:team_rw:rwx /mnt/STORAGE/shared
sudo setfacl -R -m d:g:team_rw:rwx /mnt/STORAGE/shared
```

### Read-Only Access
```bash
sudo setfacl -R -m g:team_ro:r-x /mnt/STORAGE/shared
sudo setfacl -R -m d:g:team_ro:r-x /mnt/STORAGE/shared
```

### No Access (Hidden)
Simply don't grant any permissions. Without execute permission on parent directory, folder won't be accessible or visible.

---

## Notes
- Always unmount before stopping RAID array
- Use `--assemble --scan` after unexpected shutdowns
- FACL `d:` prefix is crucial for inheritance on new files
- SetGID bit (2xxx) ensures new files inherit group ownership
- Test permissions with different user accounts before deployment
- Keep backup of `/etc/samba/smb.conf` before major changes
