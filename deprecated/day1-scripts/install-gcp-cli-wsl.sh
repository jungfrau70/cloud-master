#!/bin/bash

# GCP CLI 설치 스크립트 (WSL 환경용)

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

log_info "=== GCP CLI 설치 시작 ==="

# 1. 기존 GCP CLI 제거 (있는 경우)
if command -v gcloud &> /dev/null; then
    log_info "기존 GCP CLI 제거 중..."
    sudo apt remove -y google-cloud-cli
    log_success "기존 GCP CLI 제거 완료"
fi

# 2. 시스템 업데이트
log_info "시스템 패키지 업데이트 중..."
sudo apt update

# 3. GCP CLI GPG 키 추가
log_info "GCP CLI GPG 키 추가 중..."
curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -

# 4. GCP CLI 저장소 추가
log_info "GCP CLI 저장소 추가 중..."
echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | sudo tee -a /etc/apt/sources.list.d/google-cloud-sdk.list

# 5. GPG 키를 키링에 추가
curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg

# 6. 저장소 업데이트
log_info "패키지 저장소 업데이트 중..."
sudo apt update

# 7. GCP CLI 설치
log_info "GCP CLI 설치 중..."
sudo apt install -y google-cloud-cli

# 8. 설치 확인
if command -v gcloud &> /dev/null; then
    log_success "GCP CLI 설치 완료"
    log_info "버전: $(gcloud --version | head -1)"
else
    log_error "GCP CLI 설치에 실패했습니다."
    exit 1
fi

# 9. GCP 설정 안내
log_info "=== GCP 설정 안내 ==="
log_warning "GCP CLI 설정을 위해 다음 명령어를 실행하세요:"
echo "gcloud init"
echo ""
log_info "설정할 정보:"
echo "- GCP 계정 로그인"
echo "- 프로젝트 선택"
echo "- 기본 리전 설정 (예: asia-northeast3)"
echo "- 기본 존 설정 (예: asia-northeast3-a)"

log_success "GCP CLI 설치 스크립트 완료"
