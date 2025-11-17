#!/bin/bash
SOURCE="/mnt/SOURCE/"
BACKUP_ROOT="/mnt/BACKUP/snapshots"
DATE=$(date +%Y-%m-%d)
LATEST_LINK="$BACKUP_ROOT/latest"
LOG_FILE="/var/log/backup-raid.log"
RETENTION_DAYS=14

CURRENT_BACKUP="$BACKUP_ROOT/$DATE"
START_TIME=$(date '+%Y-%m-%d %H:%M:%S')

log_info() {
    echo "[$(date '+%H:%M:%S')] $1" >> "$LOG_FILE"
}

log_error() {
    echo "[$(date '+%H:%M:%S')] ERROR: $1" >> "$LOG_FILE"
}

echo "" >> "$LOG_FILE"
echo "=== Backup Started: $START_TIME ===" >> "$LOG_FILE"

if ! mountpoint -q "$SOURCE"; then
    log_error "Source RAID not mounted"
    exit 1
fi

if ! mountpoint -q "/mnt/BACKUP"; then
    log_error "Backup disk not mounted"
    exit 1
fi

if [ ! "$(ls -A $SOURCE)" ]; then
    log_error "Source directory is empty"
    exit 1
fi

log_info "Pre-checks passed"

PREVIOUS_BACKUP=""
RSYNC_EXIT=0

if [ -L "$LATEST_LINK" ] && [ -d "$LATEST_LINK" ]; then
    PREVIOUS_BACKUP=$(readlink -f "$LATEST_LINK")
    log_info "Incremental backup from: $(basename $PREVIOUS_BACKUP)"
    RSYNC_OUTPUT=$(rsync -ah --delete --stats --link-dest="$PREVIOUS_BACKUP" "$SOURCE" "$CURRENT_BACKUP" 2>&1)
    RSYNC_EXIT=$?
else
    log_info "Full backup (no previous snapshot)"
    RSYNC_OUTPUT=$(rsync -ah --delete --stats "$SOURCE" "$CURRENT_BACKUP" 2>&1)
    RSYNC_EXIT=$?
fi

echo "$RSYNC_OUTPUT" | grep -E "(Number of files|Total file size|speedup)" >> "$LOG_FILE"

if [ $RSYNC_EXIT -eq 0 ]; then
    log_info "Backup completed successfully"
    
    rm -f "$LATEST_LINK"
    ln -s "$CURRENT_BACKUP" "$LATEST_LINK"
    
    DELETED=$(find "$BACKUP_ROOT" -maxdepth 1 -type d -name "20*" -ctime +$RETENTION_DAYS -print -exec rm -rf {} \;)
    if [ -n "$DELETED" ]; then
        echo "$DELETED" | while read folder; do
            log_info "Deleted old snapshot: $(basename $folder)"
        done
    fi
else
    log_error "Backup failed (exit code: $RSYNC_EXIT)"
fi

END_TIME=$(date '+%Y-%m-%d %H:%M:%S')
echo "=== Backup Finished: $END_TIME ===" >> "$LOG_FILE"
