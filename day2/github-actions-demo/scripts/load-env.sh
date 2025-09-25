#!/bin/bash

# 환경 변수 로드 스크립트
# .env 파일에서 환경 변수를 로드하고 기본값을 설정합니다

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

# 환경 변수 파일 경로
ENV_FILE=".env"
CONFIG_FILE="config.env.example"

# .env 파일이 없으면 config.env.example에서 복사
if [ ! -f "$ENV_FILE" ]; then
    if [ -f "$CONFIG_FILE" ]; then
        log_info ".env 파일이 없습니다. config.env.example에서 복사합니다..."
        cp "$CONFIG_FILE" "$ENV_FILE"
        log_warning ".env 파일이 생성되었습니다. 필요한 값들을 설정해주세요."
    else
        log_error "config.env.example 파일이 없습니다."
        exit 1
    fi
fi

# .env 파일 로드
if [ -f "$ENV_FILE" ]; then
    log_info "환경 변수를 로드하는 중..."
    
    # Windows 줄바꿈 문자(\r) 제거하고 임시 파일 생성
    sed 's/\r$//' "$ENV_FILE" > "${ENV_FILE}.tmp"
    
    # .env 파일에서 환경 변수 로드 (주석과 빈 줄 제외)
    set -a
    source "${ENV_FILE}.tmp"
    set +a
    
    # 임시 파일 삭제
    rm -f "${ENV_FILE}.tmp"
    
    log_success "환경 변수 로드 완료!"
else
    log_error ".env 파일을 찾을 수 없습니다."
    exit 1
fi

# 필수 환경 변수 검증
validate_required_env() {
    local missing_vars=()
    
    # 필수 변수 목록
    local required_vars=(
        "PROJECT_NAME"
        "DOCKER_USERNAME"
        "DOCKER_IMAGE_NAME"
        "APP_PORT"
    )
    
    # VM 배포 관련 변수 (선택사항)
    local vm_vars=(
        "AWS_VM_HOST"
        "AWS_VM_USERNAME"
        "GCP_VM_HOST"
        "GCP_VM_USERNAME"
    )
    
    for var in "${required_vars[@]}"; do
        if [ -z "${!var}" ] || [ "${!var}" = "your_${var,,}" ] || [ "${!var}" = "your_${var,,}_here" ]; then
            missing_vars+=("$var")
        fi
    done
    
    if [ ${#missing_vars[@]} -gt 0 ]; then
        log_warning "다음 환경 변수들이 설정되지 않았습니다:"
        for var in "${missing_vars[@]}"; do
            log_warning "  - $var"
        done
        log_warning ".env 파일을 확인하고 필요한 값들을 설정해주세요."
    fi
}

# 기본값 설정
set_default_values() {
    # 프로젝트 기본값
    PROJECT_NAME=${PROJECT_NAME:-"github-actions-demo"}
    PROJECT_VERSION=${PROJECT_VERSION:-"1.0.0"}
    
    # Docker 기본값
    DOCKER_IMAGE_NAME=${DOCKER_IMAGE_NAME:-"github-actions-demo"}
    DOCKER_TAG=${DOCKER_TAG:-"latest"}
    
    # 애플리케이션 기본값
    APP_PORT=${APP_PORT:-3000}
    APP_HOST=${APP_HOST:-"localhost"}
    NODE_ENV=${NODE_ENV:-"development"}
    
    # 모니터링 기본값
    PROMETHEUS_PORT=${PROMETHEUS_PORT:-9090}
    GRAFANA_PORT=${GRAFANA_PORT:-3001}
    GRAFANA_USER=${GRAFANA_USER:-"admin"}
    GRAFANA_PASSWORD=${GRAFANA_PASSWORD:-"admin"}
    
    # 성능 기본값
    NODE_OPTIONS=${NODE_OPTIONS:-"--max-old-space-size=4096"}
    DOCKER_MEMORY_LIMIT=${DOCKER_MEMORY_LIMIT:-"1g"}
    
    # 로그 기본값
    LOG_LEVEL=${LOG_LEVEL:-"info"}
    LOG_FILE=${LOG_FILE:-"logs/app.log"}
    
    log_info "기본값 설정 완료"
}

# 환경 변수 출력 (디버깅용)
show_env_vars() {
    if [ "${DEBUG:-false}" = "true" ]; then
        log_info "현재 환경 변수:"
        echo "PROJECT_NAME: $PROJECT_NAME"
        echo "DOCKER_USERNAME: $DOCKER_USERNAME"
        echo "DOCKER_IMAGE_NAME: $DOCKER_IMAGE_NAME"
        echo "DOCKER_TAG: $DOCKER_TAG"
        echo "APP_PORT: $APP_PORT"
        echo "APP_HOST: $APP_HOST"
        echo "NODE_ENV: $NODE_ENV"
        echo "PROMETHEUS_PORT: $PROMETHEUS_PORT"
        echo "GRAFANA_PORT: $GRAFANA_PORT"
    fi
}

# 메인 실행
main() {
    log_info "환경 변수 설정을 시작합니다..."
    
    set_default_values
    validate_required_env
    show_env_vars
    
    log_success "환경 변수 설정 완료!"
}

# 스크립트가 직접 실행된 경우에만 main 함수 실행
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi
