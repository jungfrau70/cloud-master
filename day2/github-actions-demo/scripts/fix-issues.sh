#!/bin/bash

# 🔧 문제 해결 스크립트
# 로그에서 발견된 문제들을 자동으로 해결합니다

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

# 1. .env 파일의 Windows 줄바꿈 문자 제거
fix_env_file() {
    log_info "1. .env 파일의 Windows 줄바꿈 문자 제거 중..."
    
    if [ -f ".env" ]; then
        # Windows 줄바꿈 문자(\r) 제거
        sed -i 's/\r$//' .env
        log_success ".env 파일의 줄바꿈 문자 수정 완료"
    else
        log_warning ".env 파일이 없습니다. setup-env.sh를 실행하세요."
    fi
}

# 2. Docker 이미지 재빌드
rebuild_docker_images() {
    log_info "2. Docker 이미지 재빌드 중..."
    
    # 기존 컨테이너 중지 및 제거
    docker-compose down --remove-orphans 2>/dev/null || true
    
    # Docker 시스템 정리
    docker system prune -f --volumes 2>/dev/null || true
    
    # Docker 이미지 재빌드
    docker-compose build --no-cache
    
    log_success "Docker 이미지 재빌드 완료"
}

# 3. 테스트 실행
run_tests() {
    log_info "3. 테스트 실행 중..."
    
    # 단위 테스트
    npm run test:unit
    
    # 통합 테스트
    npm run test:integration
    
    log_success "테스트 실행 완료"
}

# 4. Docker Compose 서비스 시작
start_services() {
    log_info "4. Docker Compose 서비스 시작 중..."
    
    # 서비스 시작 (강제 재생성)
    docker-compose up -d --force-recreate
    
    # 서비스 상태 확인
    sleep 15
    docker-compose ps
    
    log_success "Docker Compose 서비스 시작 완료"
}

# 5. 헬스 체크
health_check() {
    log_info "5. 헬스 체크 실행 중..."
    
    # 애플리케이션 헬스 체크
    if curl -f http://localhost:${APP_PORT:-3000}/health > /dev/null 2>&1; then
        log_success "✅ 애플리케이션이 정상적으로 실행 중입니다"
    else
        log_error "❌ 애플리케이션 헬스 체크 실패"
        return 1
    fi
    
    # Prometheus 헬스 체크
    if curl -f http://localhost:${PROMETHEUS_PORT:-9090}/-/healthy > /dev/null 2>&1; then
        log_success "✅ Prometheus가 정상적으로 실행 중입니다"
    else
        log_warning "⚠️ Prometheus 헬스 체크 실패"
    fi
    
    # Grafana 헬스 체크
    if curl -f http://localhost:${GRAFANA_PORT:-3001}/api/health > /dev/null 2>&1; then
        log_success "✅ Grafana가 정상적으로 실행 중입니다"
    else
        log_warning "⚠️ Grafana 헬스 체크 실패"
    fi
}

# 6. 로그 확인
check_logs() {
    log_info "6. 서비스 로그 확인 중..."
    
    echo "=== 애플리케이션 로그 ==="
    docker-compose logs --tail=20 app
    
    echo ""
    echo "=== 데이터베이스 로그 ==="
    docker-compose logs --tail=10 db
    
    echo ""
    echo "=== Redis 로그 ==="
    docker-compose logs --tail=10 redis
}

# 메인 실행
main() {
    log_info "🔧 문제 해결을 시작합니다..."
    
    # 환경 변수 로드
    source scripts/load-env.sh
    
    # 문제 해결 단계별 실행
    fix_env_file
    rebuild_docker_images
    run_tests
    start_services
    health_check
    check_logs
    
    log_success "🎉 모든 문제가 해결되었습니다!"
    
    echo ""
    log_info "📊 서비스 접속 정보:"
    echo "  - 애플리케이션: http://localhost:${APP_PORT:-3000}"
    echo "  - Prometheus: http://localhost:${PROMETHEUS_PORT:-9090}"
    echo "  - Grafana: http://localhost:${GRAFANA_PORT:-3001}"
    echo "  - 데이터베이스: localhost:${POSTGRES_PORT:-5432}"
    echo "  - Redis: localhost:${REDIS_PORT:-6379}"
}

# 스크립트 실행
main "$@"
