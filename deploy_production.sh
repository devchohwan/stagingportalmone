#!/bin/bash

echo "🚀 Production 배포 시작..."

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 배포 설정
SERVER="115.68.195.125"
SSH_KEY="~/monemusic"
DOCKER_IMAGE="amuguona/portal-monemusic:manual-fix"
CONTAINER_NAME="portal-monemusic-manual"

echo -e "${YELLOW}서버에서 직접 실행할 명령어:${NC}"
echo ""
echo "ssh -i $SSH_KEY root@$SERVER"
echo ""
echo "# 프로젝트 디렉토리 확인 및 생성"
echo "if [ ! -d /root/portal-monemusic ]; then"
echo "  cd /root"
echo "  git clone https://github.com/devchohwan/portal_monemusic.git portal-monemusic"
echo "else"
echo "  cd /root/portal-monemusic"
echo "  git pull origin main"
echo "fi"
echo ""
echo "# Docker 이미지 빌드"
echo "cd /root/portal-monemusic"
echo "docker build -t $DOCKER_IMAGE ."
echo ""
echo "# Docker Hub에 푸시 (선택사항)"
echo "docker push $DOCKER_IMAGE"
echo ""
echo "# 기존 컨테이너 중지 및 삭제"
echo "docker stop $CONTAINER_NAME 2>/dev/null || true"
echo "docker rm $CONTAINER_NAME 2>/dev/null || true"
echo ""
echo "# 새 컨테이너 실행"
echo "docker run -d \\"
echo "  --name $CONTAINER_NAME \\"
echo "  --network kamal \\"
echo "  -v portal_monemusic_storage:/rails/storage \\"
echo "  -e RAILS_MASTER_KEY=d852cbb93057373a82518521ec2e24a0 \\"
echo "  -e RAILS_ENV=production \\"
echo "  --entrypoint '' \\"
echo "  $DOCKER_IMAGE \\"
echo "  ./bin/thrust ./bin/rails server"
echo ""
echo "# 데이터베이스 마이그레이션 실행"
echo "docker exec $CONTAINER_NAME /rails/bin/rails db:migrate RAILS_ENV=production"
echo ""
echo "# 컨테이너 상태 확인"
echo "docker ps | grep $CONTAINER_NAME"
echo ""
echo "# 로그 확인"
echo "docker logs -f $CONTAINER_NAME --tail 50"

echo -e "${GREEN}===========================================${NC}"
echo -e "${GREEN}위 명령어를 복사해서 서버에서 실행하세요!${NC}"
echo -e "${GREEN}===========================================${NC}"