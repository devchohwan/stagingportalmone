#!/bin/bash

# 백업 디렉토리 설정
BACKUP_DIR="/root/backups/portal_monemusic"
DATE=$(date +%Y%m%d_%H%M%S)
CONTAINER_NAME="portal-monemusic-manual"
DB_FILE="/rails/storage/production.sqlite3"

# 백업 디렉토리 생성
mkdir -p $BACKUP_DIR

# 데이터베이스 백업
echo "Starting backup at $(date)"
docker exec $CONTAINER_NAME cat $DB_FILE > $BACKUP_DIR/production_$DATE.sqlite3

# 백업 확인
if [ -f "$BACKUP_DIR/production_$DATE.sqlite3" ]; then
    FILE_SIZE=$(ls -lh $BACKUP_DIR/production_$DATE.sqlite3 | awk '{print $5}')
    echo "Backup completed: production_$DATE.sqlite3 ($FILE_SIZE)"
    
    # 30일 이상 된 백업 삭제
    find $BACKUP_DIR -name "production_*.sqlite3" -mtime +30 -delete
    echo "Old backups cleaned up (older than 30 days)"
else
    echo "Backup failed!"
    exit 1
fi

# 백업 파일 목록
echo "Current backups:"
ls -lh $BACKUP_DIR/production_*.sqlite3 | tail -5