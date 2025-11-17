## Prerequisites
- Ubuntu Server with root/sudo access
- Network connectivity

---

## 1. Installation

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

---

## Recommended Group ID Ranges
- **1000-2999**: Regular user primary groups
- **3000-3999**: Custom Samba groups (recommended)
- **4000+**: Reserved for future use

Example structure:
