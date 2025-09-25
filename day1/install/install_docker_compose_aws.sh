#!/bin/bash
set -e

echo "📦 Amazon Linux 2023 기본 리포지터리에서 Docker 설치"

# 업데이트
sudo dnf update -y

# Docker 설치 (amazon-linux-extras가 없으니 dnf로 직접 설치)
sudo dnf install -y docker

# Docker 서비스 시작 및 부팅 시 자동 시작
sudo systemctl start docker
sudo systemctl enable docker

# 현재 사용자 docker 그룹에 추가
sudo usermod -aG docker "$USER"

# Docker 버전 확인
docker --version

# docker-compose 설치 (docker-compose-plugin이 없으므로, 별도 바이너리 설치)
echo "📥 docker-compose 최신 바이너리 설치"

COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep tag_name | cut -d '"' -f 4)

sudo curl -L "https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" \
    -o /usr/local/bin/docker-compose

sudo chmod +x /usr/local/bin/docker-compose

echo "docker-compose 버전:"
docker-compose --version

echo "✅ 설치 완료! 재로그인 후 sudo 없이 docker 사용 가능."

