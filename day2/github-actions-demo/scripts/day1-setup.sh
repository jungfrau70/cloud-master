#!/bin/bash
# Day1 - Basic CI/CD Setup Script
# Cloud Master Day1 강의안 기반

set -e

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 로그 함수
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

log_info "🚀 Cloud Master Day1 - Basic CI/CD Setup 시작"

# 1. 환경 변수 설정
log_info "📋 환경 변수 설정 중..."
if [ ! -f .env ]; then
    cp .env.example .env
    log_success ".env 파일 생성 완료"
else
    log_info ".env 파일이 이미 존재합니다"
fi

# 2. 의존성 설치
log_info "📦 의존성 설치 중..."
npm install

# 3. Docker 이미지 빌드
log_info "🐳 Docker 이미지 빌드 중..."
docker build -f Dockerfile.day1 -t github-actions-demo:day1 .

# 4. 테스트 실행
log_info "🧪 테스트 실행 중..."
npm test

# 5. 린트 검사
log_info "🔍 린트 검사 중..."
npm run lint

# 6. Docker 컨테이너 실행 테스트
log_info "🚀 Docker 컨테이너 실행 테스트 중..."
docker run -d --name github-actions-demo-day1 -p 3000:3000 github-actions-demo:day1

# 7. 헬스 체크
log_info "🔍 헬스 체크 중..."
sleep 5
if curl -f http://localhost:3000/health > /dev/null 2>&1; then
    log_success "✅ 애플리케이션이 정상적으로 실행되고 있습니다"
else
    log_error "❌ 애플리케이션 실행에 실패했습니다"
    exit 1
fi

# 8. 컨테이너 정리
log_info "🧹 컨테이너 정리 중..."
docker stop github-actions-demo-day1
docker rm github-actions-demo-day1

log_success "🎉 Day1 기본 CI/CD 설정 완료!"
log_info "📋 다음 단계:"
log_info "1. GitHub 저장소에 코드 푸시"
log_info "2. GitHub Actions 워크플로우 실행 확인"
log_info "3. Docker Hub에 이미지 푸시"
log_info "4. AWS/GCP VM에 배포"