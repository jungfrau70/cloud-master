#!/bin/bash

# AWS CLI v2 설치 스크립트 (WSL 환경용)

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

log_info "=== AWS CLI v2 설치 시작 ==="

# 1. 기존 AWS CLI 제거 (있는 경우)
if command -v aws &> /dev/null; then
    log_info "기존 AWS CLI 제거 중..."
    if command -v apt &> /dev/null; then
        sudo apt remove -y awscli
    fi
    if [ -d "/usr/local/aws-cli" ]; then
        sudo rm -rf /usr/local/aws-cli
    fi
    if [ -f "/usr/local/bin/aws" ]; then
        sudo rm -f /usr/local/bin/aws
    fi
    log_success "기존 AWS CLI 제거 완료"
fi

# 2. 필수 패키지 설치
log_info "필수 패키지 설치 중..."
sudo apt update
sudo apt install -y curl unzip

# 3. AWS CLI v2 다운로드 및 설치
log_info "AWS CLI v2 다운로드 중..."
cd /tmp
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"

log_info "AWS CLI v2 설치 중..."
unzip -q awscliv2.zip
sudo ./aws/install --update

# 4. 설치 확인
if command -v aws &> /dev/null; then
    log_success "AWS CLI v2 설치 완료"
    log_info "버전: $(aws --version)"
else
    log_error "AWS CLI 설치에 실패했습니다."
    exit 1
fi

# 5. 정리
rm -rf aws awscliv2.zip

# 6. AWS 설정 안내
log_info "=== AWS 설정 안내 ==="
log_warning "AWS CLI 설정을 위해 다음 명령어를 실행하세요:"
echo "aws configure"
echo ""
log_info "설정할 정보:"
echo "- AWS Access Key ID"
echo "- AWS Secret Access Key"
echo "- Default region name (예: ap-northeast-2)"
echo "- Default output format (예: json)"

log_success "AWS CLI v2 설치 스크립트 완료"
