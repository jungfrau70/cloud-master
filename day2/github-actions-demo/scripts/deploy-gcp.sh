#!/bin/bash

# 🚀 GCP Compute Engine 배포 스크립트
# GitHub Actions Demo 애플리케이션을 GCP VM에 배포합니다

set -e  # 오류 발생 시 스크립트 종료

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# 로그 함수
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# 환경 변수 로드
if [ -f .env ]; then
    log_info "환경 변수 로드 중..."
    export $(cat .env | grep -v '^#' | xargs)
else
    log_warning ".env 파일을 찾을 수 없습니다. 환경 변수를 수동으로 설정하세요."
fi

# 필수 환경 변수 확인
check_required_vars() {
    local required_vars=("GCP_VM_HOST" "GCP_VM_USERNAME" "GCP_VM_SSH_KEY" "DOCKER_USERNAME" "DOCKER_PASSWORD")
    
    for var in "${required_vars[@]}"; do
        if [ -z "${!var}" ]; then
            log_error "필수 환경 변수가 설정되지 않았습니다: $var"
            exit 1
        fi
    done
    
    log_success "모든 필수 환경 변수가 설정되었습니다."
}

# SSH 키 파일 생성
setup_ssh_key() {
    log_info "SSH 키 설정 중..."
    
    # SSH 키 파일 생성
    echo "$GCP_VM_SSH_KEY" > /tmp/gcp-deployment-key.pem
    chmod 600 /tmp/gcp-deployment-key.pem
    
    log_success "SSH 키 파일이 생성되었습니다."
}

# Docker Hub 로그인
docker_login() {
    log_info "Docker Hub 로그인 중..."
    
    echo "$DOCKER_PASSWORD" | docker login -u "$DOCKER_USERNAME" --password-stdin
    
    if [ $? -eq 0 ]; then
        log_success "Docker Hub 로그인 성공"
    else
        log_error "Docker Hub 로그인 실패"
        exit 1
    fi
}

# GCP VM에 배포
deploy_to_gcp() {
    log_info "GCP VM에 배포 중..."
    
    # SSH를 통한 배포 스크립트 실행
    ssh -i /tmp/gcp-deployment-key.pem \
        -o StrictHostKeyChecking=no \
        -o UserKnownHostsFile=/dev/null \
        "$GCP_VM_USERNAME@$GCP_VM_HOST" << 'EOF'
        
        # 기존 컨테이너 중지 및 제거
        echo "기존 컨테이너 중지 및 제거 중..."
        docker stop github-actions-demo || true
        docker rm github-actions-demo || true
        
        # Docker Hub에서 최신 이미지 풀
        echo "최신 이미지 풀 중..."
        docker pull $DOCKER_USERNAME/github-actions-demo:latest
        
        # 새 컨테이너 실행
        echo "새 컨테이너 실행 중..."
        docker run -d \
            --name github-actions-demo \
            --restart unless-stopped \
            -p 3000:3000 \
            -e NODE_ENV=production \
            $DOCKER_USERNAME/github-actions-demo:latest
        
        # 헬스 체크
        echo "헬스 체크 중..."
        sleep 10
        curl -f http://localhost:3000/health || exit 1
        
        echo "✅ GCP VM 배포가 성공적으로 완료되었습니다!"
EOF
    
    if [ $? -eq 0 ]; then
        log_success "GCP VM 배포 성공"
    else
        log_error "GCP VM 배포 실패"
        exit 1
    fi
}

# 배포 상태 확인
verify_deployment() {
    log_info "배포 상태 확인 중..."
    
    # 애플리케이션 접근 테스트
    local app_url="http://$GCP_VM_HOST:3000"
    local health_url="$app_url/health"
    local metrics_url="$app_url/metrics"
    
    log_info "애플리케이션 URL: $app_url"
    log_info "헬스 체크 URL: $health_url"
    log_info "메트릭 URL: $metrics_url"
    
    # 헬스 체크
    if curl -f "$health_url" > /dev/null 2>&1; then
        log_success "헬스 체크 통과"
    else
        log_warning "헬스 체크 실패 - 애플리케이션이 아직 시작 중일 수 있습니다."
    fi
}

# 정리 작업
cleanup() {
    log_info "정리 작업 중..."
    rm -f /tmp/gcp-deployment-key.pem
    log_success "정리 완료"
}

# 메인 함수
main() {
    log_info "🚀 GCP Compute Engine 배포 시작"
    
    check_required_vars
    setup_ssh_key
    docker_login
    deploy_to_gcp
    verify_deployment
    cleanup
    
    log_success "🎉 GCP 배포가 완료되었습니다!"
    log_info "🌐 애플리케이션 URL: http://$GCP_VM_HOST:3000"
}

# 스크립트 실행
main "$@"
