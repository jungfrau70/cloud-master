#!/bin/bash

# 🚀 GitHub Actions Demo 프로젝트 설정 스크립트
# 프로젝트 초기 설정을 자동화합니다

set -e  # 오류 발생 시 스크립트 중단

# 환경 변수 로드
source scripts/load-env.sh

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

# 환경 체크
check_environment() {
    log_info "환경을 확인하는 중..."
    
    # Node.js 체크
    if ! command -v node &> /dev/null; then
        log_error "Node.js가 설치되지 않았습니다. Node.js 18 이상을 설치해주세요."
        exit 1
    fi
    
    # npm 체크
    if ! command -v npm &> /dev/null; then
        log_error "npm이 설치되지 않았습니다."
        exit 1
    fi
    
    # Docker 체크
    if ! command -v docker &> /dev/null; then
        log_error "Docker가 설치되지 않았습니다."
        exit 1
    fi
    
    # Git 체크
    if ! command -v git &> /dev/null; then
        log_error "Git이 설치되지 않았습니다."
        exit 1
    fi
    
    # AWS CLI 체크 (선택사항)
    if ! command -v aws &> /dev/null; then
        log_warning "AWS CLI가 설치되지 않았습니다. AWS 배포를 위해서는 AWS CLI가 필요합니다."
    fi
    
    # GCP CLI 체크 (선택사항)
    if ! command -v gcloud &> /dev/null; then
        log_warning "GCP CLI가 설치되지 않았습니다. GCP 배포를 위해서는 GCP CLI가 필요합니다."
    fi
    
    log_success "환경 체크 완료!"
}

# 의존성 설치
install_dependencies() {
    log_info "의존성을 설치하는 중..."
    
    if [ -f package-lock.json ]; then
        npm ci
    else
        npm install
    fi
    
    log_success "의존성 설치 완료!"
}

# 환경 변수 설정
setup_environment() {
    log_info "환경 변수를 설정하는 중..."
    
    if [ ! -f .env ]; then
        if [ -f config.env.example ]; then
            cp config.env.example .env
            log_warning ".env 파일이 생성되었습니다. 필요한 값들을 설정해주세요."
        else
            log_error "config.env.example 파일이 없습니다."
            exit 1
        fi
    else
        log_info ".env 파일이 이미 존재합니다."
    fi
    
    # 환경 변수 다시 로드
    source scripts/load-env.sh
}

# Docker 이미지 빌드
build_docker_images() {
    log_info "Docker 이미지를 빌드하는 중..."
    
    # 기본 이미지 빌드
    docker build -f Dockerfile -t ${DOCKER_IMAGE_NAME}:${DOCKER_TAG} .
    log_success "기본 이미지 빌드 완료! (${DOCKER_IMAGE_NAME}:${DOCKER_TAG})"
    
    # 개발용 이미지 빌드
    docker build -f Dockerfile.dev -t ${DOCKER_IMAGE_NAME}:dev .
    log_success "개발용 이미지 빌드 완료! (${DOCKER_IMAGE_NAME}:dev)"
    
    # 테스트용 이미지 빌드
    docker build -f Dockerfile.test -t ${DOCKER_IMAGE_NAME}:test .
    log_success "테스트용 이미지 빌드 완료! (${DOCKER_IMAGE_NAME}:test)"
    
    # 멀티스테이지 이미지 빌드
    docker build -f Dockerfile.multistage -t ${DOCKER_IMAGE_NAME}:multistage .
    log_success "멀티스테이지 이미지 빌드 완료! (${DOCKER_IMAGE_NAME}:multistage)"
}

# 테스트 실행
run_tests() {
    log_info "테스트를 실행하는 중..."
    
    # 단위 테스트
    npm run test:unit || log_warning "단위 테스트에서 일부 실패가 있었습니다."
    
    # 통합 테스트
    npm run test:integration || log_warning "통합 테스트에서 일부 실패가 있었습니다."
    
    log_success "테스트 실행 완료!"
}

# Docker Compose 실행
start_services() {
    log_info "Docker Compose로 서비스를 시작하는 중..."
    
    # 환경 변수를 Docker Compose에 전달
    export PROJECT_NAME
    export DOCKER_IMAGE_NAME
    export APP_PORT
    export PROMETHEUS_PORT
    export GRAFANA_PORT
    export GRAFANA_USER
    export GRAFANA_PASSWORD
    
    docker-compose up -d
    
    log_success "서비스가 시작되었습니다!"
    log_info "애플리케이션: http://${APP_HOST}:${APP_PORT}"
    log_info "Grafana: http://${APP_HOST}:${GRAFANA_PORT} (${GRAFANA_USER}/${GRAFANA_PASSWORD})"
    log_info "Prometheus: http://${APP_HOST}:${PROMETHEUS_PORT}"
}

# 인증 확인
check_authentication() {
    log_info "인증 상태를 확인하는 중..."
    
    if ! ./scripts/check-auth.sh; then
        log_error "인증 확인 실패. 필요한 인증을 완료한 후 다시 시도하세요."
        log_info "인증 가이드:"
        log_info "1. Docker Hub: docker login"
        log_info "2. GitHub: gh auth login"
        log_info "3. AWS: aws configure (선택사항)"
        log_info "4. GCP: gcloud auth login (선택사항)"
        exit 1
    fi
    
    log_success "인증 확인 완료!"
}

# 메인 실행
main() {
    log_info "🚀 GitHub Actions Demo 프로젝트 설정을 시작합니다..."
    
    check_environment
    check_authentication
    install_dependencies
    setup_environment
    build_docker_images
    run_tests
    start_services
    
    log_success "🎉 프로젝트 설정이 완료되었습니다!"
    log_info "다음 단계:"
    log_info "1. .env 파일의 설정값들을 확인하고 수정하세요"
    log_info "2. GitHub 저장소를 생성하고 연결하세요"
    log_info "3. GitHub Secrets를 설정하세요"
    log_info "4. 코드를 푸시하여 CI/CD 파이프라인을 테스트하세요"
}

# 스크립트 실행
main "$@"
