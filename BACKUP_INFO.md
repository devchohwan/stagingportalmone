# 데이터베이스 백업 정보

## 자동 백업 설정 완료 ✅

### 백업 스케줄
- **매일 오전 3시** (새벽 시간대)
- **매일 오후 3시** (오후 시간대)
- 하루 2번 자동 백업

### 백업 위치
- 서버: `115.68.195.125`
- 백업 디렉토리: `/root/backups/portal_monemusic/`
- 백업 파일명 형식: `production_YYYYMMDD_HHMMSS.sqlite3`

### 백업 관리
- 30일 이상 된 백업은 자동 삭제
- 백업 로그: `/var/log/db_backup.log`

### 수동 백업 방법
```bash
ssh -i ~/monemusic root@115.68.195.125 '/root/backup_database.sh'
```

### 백업 확인 방법
```bash
ssh -i ~/monemusic root@115.68.195.125 'ls -lh /root/backups/portal_monemusic/'
```

### 백업 복원 방법
```bash
# 1. 백업 파일을 컨테이너로 복사
ssh -i ~/monemusic root@115.68.195.125 'docker cp /root/backups/portal_monemusic/production_YYYYMMDD_HHMMSS.sqlite3 portal-monemusic-manual:/rails/storage/production.sqlite3'

# 2. 컨테이너 재시작
ssh -i ~/monemusic root@115.68.195.125 'docker restart portal-monemusic-manual'
```

### 주의사항
- **절대 `db:schema:load` 사용 금지**
- 백업 복원 전 현재 데이터베이스도 백업
- 복원 후 필요한 컬럼 확인 (lesson_content, online_verification_image 등)