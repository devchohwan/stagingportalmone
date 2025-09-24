#!/bin/bash

echo "🚀 Portal Monemusic 배포 시작..."

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 서버 정보
SERVER="115.68.195.125"
SSH_KEY="~/monemusic"
DOCKER_IMAGE="amuguona/portal-monemusic:manual-fix"
CONTAINER_NAME="portal-monemusic-manual"

echo -e "${YELLOW}1. 서버 접속 및 코드 업데이트 중...${NC}"
ssh -i $SSH_KEY root@$SERVER << 'ENDSSH'
cd /root/portal-monemusic
git pull origin main

echo "2. Docker 이미지 빌드 중..."
docker build -t amuguona/portal-monemusic:manual-fix .

echo "3. 기존 컨테이너 중지 및 삭제..."
docker stop portal-monemusic-manual 2>/dev/null || true
docker rm portal-monemusic-manual 2>/dev/null || true

echo "4. 새 컨테이너 실행..."
docker run -d \
  --name portal-monemusic-manual \
  --network kamal \
  -v portal_monemusic_storage:/rails/storage \
  -e RAILS_MASTER_KEY=d852cbb93057373a82518521ec2e24a0 \
  -e RAILS_ENV=production \
  --entrypoint '' \
  amuguona/portal-monemusic:manual-fix \
  ./bin/thrust ./bin/rails server

echo "5. 마이그레이션 실행 중..."
docker exec portal-monemusic-manual /rails/bin/rails db:migrate RAILS_ENV=production

echo "6. 컨테이너 상태 확인..."
docker ps | grep portal-monemusic-manual

echo "✅ 배포 완료!"
echo "로그 확인: docker logs -f portal-monemusic-manual --tail 50"
ENDSSH

echo -e "${GREEN}✅ 배포가 완료되었습니다!${NC}"
echo -e "${YELLOW}사이트 확인: https://portal.monemusic.com${NC}"