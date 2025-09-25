#!/bin/bash

# Docker 및 Docker Compose 설치 스크립트 (WSL 환경용)
# 
# ⚠️  주의사항:
# - 이 스크립트는 WSL 내부에 직접 Docker Engine을 설치합니다
# - Docker Desktop과는 별개의 설치 방식입니다
# - WSL 내부에서만 Docker 명령어를 사용할 수 있습니다
# - Windows와 WSL 간 파일 공유가 제한적일 수 있습니다
#
# 🐳 Docker Desktop 사용을 원한다면:
# - Windows에서 Docker Desktop을 설치하고
# - WSL2 통합을 활성화하세요

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 로그 함수
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

log_info "=== Docker 설치 시작 ==="

# 1. 기존 Docker 제거 (있는 경우)
if command -v docker &> /dev/null; then
    log_info "기존 Docker 제거 중..."
    sudo apt remove -y docker docker-engine docker.io containerd runc
    log_success "기존 Docker 제거 완료"
fi

# 2. 시스템 업데이트
log_info "시스템 패키지 업데이트 중..."
sudo apt update
sudo apt install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

# 3. Docker GPG 키 추가
log_info "Docker GPG 키 추가 중..."
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# 4. Docker 저장소 추가
log_info "Docker 저장소 추가 중..."
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# 5. 저장소 업데이트
log_info "패키지 저장소 업데이트 중..."
sudo apt update

# 6. Docker 설치
log_info "Docker 설치 중..."
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# 7. Docker 서비스 시작 및 활성화
log_info "Docker 서비스 시작 중..."
sudo systemctl start docker
sudo systemctl enable docker

# 8. 사용자를 docker 그룹에 추가
log_info "사용자를 docker 그룹에 추가 중..."
sudo usermod -aG docker $USER

# 9. Docker Compose 설치 (별도)
log_info "Docker Compose 설치 중..."
if ! command -v docker-compose &> /dev/null; then
    sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
    log_success "Docker Compose 설치 완료"
else
    log_info "Docker Compose가 이미 설치되어 있습니다: $(docker-compose --version)"
fi

# 10. 설치 확인
if command -v docker &> /dev/null; then
    log_success "Docker 설치 완료"
    log_info "버전: $(docker --version)"
    log_info "Docker Compose 버전: $(docker-compose --version)"
else
    log_error "Docker 설치에 실패했습니다."
    exit 1
fi

# 11. Docker 권한 테스트
log_info "Docker 권한 테스트 중..."
if sudo docker run hello-world &> /dev/null; then
    log_success "Docker 권한 테스트 성공"
else
    log_warning "Docker 권한 테스트 실패. 로그아웃 후 다시 로그인하세요."
fi

# 12. Docker 설정 안내
log_info "=== Docker 설정 안내 ==="
log_warning "Docker 그룹 권한을 적용하려면 다음 중 하나를 실행하세요:"
echo "1. 로그아웃 후 다시 로그인"
echo "2. 'newgrp docker' 명령어 실행"
echo "3. 'su - $USER' 명령어 실행"
echo ""
log_info "Docker 테스트 명령어:"
echo "docker run hello-world"
echo "docker --version"
echo "docker-compose --version"

log_success "Docker 설치 스크립트 완료"
