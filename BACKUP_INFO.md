# 데이터베이스 백업 정보

## 자동 백업 설정 완료 ✅

### 백업 스케줄
- **매시간 정각** (1시간마다)
- 하루 24번 자동 백업
- 최대 1시간 이내 데이터로 복원 가능

### 백업 위치
- 서버: `115.68.195.125`
- 백업 디렉토리: `/root/backups/portal_monemusic/`
- 백업 파일명 형식: `production_YYYYMMDD_HHMMSS.sqlite3`

### 백업 관리
- 2일(48시간) 이상 된 백업은 자동 삭제
- 최대 48개 백업 파일 유지 (약 12MB)
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