# Portal Monemusic 배포 가이드

## 서버 정보
- **Production Server**: 115.68.195.125
- **Domain**: portal.monemusic.com
- **SSH Access**: `ssh -i ~/monemusic root@115.68.195.125`

## Docker 설정
- **이미지**: amuguona/portal-monemusic:manual-fix
- **컨테이너 이름**: portal-monemusic-manual
- **네트워크**: kamal
- **볼륨**: portal_monemusic_storage:/rails/storage (SQLite DB 저장)
- **환경변수**:
  - RAILS_MASTER_KEY=d852cbb93057373a82518521ec2e24a0
  - RAILS_ENV=production
  - SOLAPI_API_KEY=NCSEZDWSEGELZR7R
  - SOLAPI_API_SECRET=NP4GYWVKEENOKBRPCI022UUNHQHPUOLM
  - SOLAPI_SENDER_PHONE=07048337690

## 배포 절차

### 1. 로컬에서 코드 수정 및 커밋
```bash
# 코드 수정 후
git add -A
git commit -m "커밋 메시지"
git push origin main
```

### 2. Docker 이미지 빌드 및 푸시
```bash
# 이미지 빌드
docker build -t amuguona/portal-monemusic:manual-fix .

# Docker Hub에 푸시
docker push amuguona/portal-monemusic:manual-fix
```

### 3. Production 서버에 배포
```bash
# SSH로 서버 접속
ssh -i ~/monemusic root@115.68.195.125

# 기존 컨테이너 중지 및 삭제
docker stop portal-monemusic-manual
docker rm portal-monemusic-manual

# 최신 이미지 Pull
docker pull amuguona/portal-monemusic:manual-fix

# 새 컨테이너 실행
docker run -d --name portal-monemusic-manual \
  --network kamal \
  -v portal_monemusic_storage:/rails/storage \
  -e RAILS_MASTER_KEY=d852cbb93057373a82518521ec2e24a0 \
  -e RAILS_ENV=production \
  -e SOLAPI_API_KEY=NCSEZDWSEGELZR7R \
  -e SOLAPI_API_SECRET=NP4GYWVKEENOKBRPCI022UUNHQHPUOLM \
  -e SOLAPI_SENDER_PHONE=07048337690 \
  --entrypoint '' \
  amuguona/portal-monemusic:manual-fix \
  ./bin/thrust ./bin/rails server

# 컨테이너 상태 확인
docker ps | grep portal-monemusic-manual

# 로그 확인
docker logs portal-monemusic-manual --tail 20
```

### 4. 배포 확인
- 브라우저에서 https://portal.monemusic.com 접속
- 관리자 대시보드 및 주요 기능 테스트

## 한 줄 배포 스크립트
```bash
# 로컬에서 실행 (이미지 빌드 후)
docker build -t amuguona/portal-monemusic:manual-fix . && \
docker push amuguona/portal-monemusic:manual-fix && \
ssh -i ~/monemusic root@115.68.195.125 "docker stop portal-monemusic-manual; docker rm portal-monemusic-manual; docker pull amuguona/portal-monemusic:manual-fix; docker run -d --name portal-monemusic-manual --network kamal -v portal_monemusic_storage:/rails/storage -e RAILS_MASTER_KEY=d852cbb93057373a82518521ec2e24a0 -e RAILS_ENV=production -e SOLAPI_API_KEY=NCSEZDWSEGELZR7R -e SOLAPI_API_SECRET=NP4GYWVKEENOKBRPCI022UUNHQHPUOLM -e SOLAPI_SENDER_PHONE=07048337690 --entrypoint '' amuguona/portal-monemusic:manual-fix ./bin/thrust ./bin/rails server"
```

## 주의사항
- 포트 매핑은 Kamal 프록시가 처리하므로 docker run에 -p 옵션 불필요
- SQLite 데이터베이스는 볼륨에 저장되어 컨테이너 재시작 시에도 유지됨
- RAILS_MASTER_KEY는 반드시 정확히 입력해야 함

## 트러블슈팅
- 컨테이너가 실행되지 않을 때: `docker logs portal-monemusic-manual` 로그 확인
- 데이터베이스 오류: 볼륨 마운트 확인 `-v portal_monemusic_storage:/rails/storage`
- 네트워크 오류: kamal 네트워크 존재 확인 `docker network ls | grep kamal`