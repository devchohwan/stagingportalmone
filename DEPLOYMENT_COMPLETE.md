# 완전한 배포 명령어

## 환경변수 포함 배포 (권장)

```bash
# 로컬에서 한 번에 실행
docker build -t amuguona/portal-monemusic:latest . && \
docker push amuguona/portal-monemusic:latest && \
ssh -i ~/monemusic root@115.68.195.125 "docker stop portal-monemusic-manual; \
docker rm portal-monemusic-manual; \
docker pull amuguona/portal-monemusic:latest; \
docker run -d --name portal-monemusic-manual \
  --network kamal \
  -v portal_monemusic_storage:/rails/storage \
  -e RAILS_MASTER_KEY=d852cbb93057373a82518521ec2e24a0 \
  -e RAILS_ENV=production \
  -e SOLAPI_API_KEY=NCSEZDWSEGELZR7R \
  -e SOLAPI_API_SECRET=NP4GYWVKEENOKBRPCI022UUNHQHPUOLM \
  -e SOLAPI_SENDER_PHONE=07048337690 \
  --entrypoint '' \
  amuguona/portal-monemusic:latest \
  ./bin/thrust ./bin/rails server"
```

## 포함된 설정
- ✅ uploads 디렉토리 권한 (Dockerfile에 포함)
- ✅ 마이그레이션 (볼륨에 저장된 DB 사용)
- ✅ Solapi 환경변수
- ✅ Rails Master Key

## 주의사항
- 절대 `db:schema:load` 사용 금지
- 배포 전 백업 확인: `ssh -i ~/monemusic root@115.68.195.125 'ls -lh /root/backups/portal_monemusic/'`