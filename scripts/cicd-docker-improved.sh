#!/bin/bash

# CI/CD Docker Compose 개선 스크립트
# WSL 히스토리 분석을 바탕으로 GitHub Actions 관련 Docker 오류 수정

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# 환경 변수 설정
setup_environment() {
    log_info "CI/CD 환경 변수 설정 중..."
    
    # 기본 환경 변수 설정
    export DOCKER_USERNAME="${DOCKER_USERNAME:-jungfrau70}"
    export IMAGE_NAME="${IMAGE_NAME:-github-actions-demo-day2}"
    export IMAGE_TAG="${IMAGE_TAG:-latest}"
    export CONTAINER_PREFIX="${CONTAINER_PREFIX:-cicd-test}"
    export NODE_ENV="${NODE_ENV:-staging}"
    export DB_PASSWORD="${DB_PASSWORD:-password123}"
    export REDIS_PASSWORD="${REDIS_PASSWORD:-}"
    export APP_PORT="${APP_PORT:-3000}"
    
    log_success "환경 변수 설정 완료"
    log_info "DOCKER_USERNAME: $DOCKER_USERNAME"
    log_info "IMAGE_NAME: $IMAGE_NAME"
    log_info "CONTAINER_PREFIX: $CONTAINER_PREFIX"
}

# Docker Compose 설정 검증
validate_docker_compose() {
    local compose_file=$1
    
    log_info "Docker Compose 설정 검증 중: $compose_file"
    
    if [ ! -f "$compose_file" ]; then
        log_error "Docker Compose 파일이 존재하지 않습니다: $compose_file"
        return 1
    fi
    
    # Docker Compose 문법 검증
    docker-compose -f "$compose_file" config >/dev/null 2>&1
    
    if [ $? -eq 0 ]; then
        log_success "Docker Compose 설정이 유효합니다"
    else
        log_error "Docker Compose 설정에 오류가 있습니다"
        docker-compose -f "$compose_file" config
        return 1
    fi
}

# 기존 컨테이너 정리
cleanup_containers() {
    log_info "기존 컨테이너 정리 중..."
    
    # 실행 중인 컨테이너 중지
    docker-compose -f docker-compose.prod.yml down --volumes --remove-orphans 2>/dev/null
    
    # 관련 볼륨 정리
    docker volume prune -f 2>/dev/null
    
    # 시스템 정리
    docker system prune -f 2>/dev/null
    
    log_success "컨테이너 정리 완료"
}

# PostgreSQL 초기화 개선
setup_postgresql() {
    log_info "PostgreSQL 초기화 중..."
    
    # PostgreSQL 컨테이너 시작
    docker-compose -f docker-compose.prod.yml up -d postgres
    
    # PostgreSQL 준비 대기
    log_info "PostgreSQL 준비 대기 중..."
    for i in {1..30}; do
        if docker-compose -f docker-compose.prod.yml exec -T postgres pg_isready -U postgres >/dev/null 2>&1; then
            log_success "PostgreSQL 준비 완료"
            return 0
        fi
        echo -n "."
        sleep 2
    done
    
    log_error "PostgreSQL 초기화 시간 초과"
    return 1
}

# Redis 초기화 개선
setup_redis() {
    log_info "Redis 초기화 중..."
    
    # Redis 컨테이너 시작
    docker-compose -f docker-compose.prod.yml up -d redis
    
    # Redis 준비 대기
    log_info "Redis 준비 대기 중..."
    for i in {1..15}; do
        if docker-compose -f docker-compose.prod.yml exec -T redis redis-cli ping >/dev/null 2>&1; then
            log_success "Redis 준비 완료"
            return 0
        fi
        echo -n "."
        sleep 2
    done
    
    log_error "Redis 초기화 시간 초과"
    return 1
}

# 애플리케이션 시작
start_application() {
    log_info "애플리케이션 시작 중..."
    
    # 애플리케이션 컨테이너 시작
    docker-compose -f docker-compose.prod.yml up -d app
    
    # 애플리케이션 준비 대기
    log_info "애플리케이션 준비 대기 중..."
    for i in {1..30}; do
        if curl -f http://localhost:3000/health >/dev/null 2>&1; then
            log_success "애플리케이션 준비 완료"
            return 0
        fi
        echo -n "."
        sleep 2
    done
    
    log_error "애플리케이션 시작 시간 초과"
    return 1
}

# Nginx 시작
start_nginx() {
    log_info "Nginx 시작 중..."
    
    # Nginx 컨테이너 시작
    docker-compose -f docker-compose.prod.yml up -d nginx
    
    # Nginx 준비 대기
    log_info "Nginx 준비 대기 중..."
    for i in {1..15}; do
        if curl -f http://localhost:80 >/dev/null 2>&1; then
            log_success "Nginx 준비 완료"
            return 0
        fi
        echo -n "."
        sleep 2
    done
    
    log_error "Nginx 시작 시간 초과"
    return 1
}

# 헬스 체크
health_check() {
    log_info "헬스 체크 실행 중..."
    
    # 애플리케이션 헬스 체크
    log_info "애플리케이션 헬스 체크..."
    if curl -f http://localhost:3000/health >/dev/null 2>&1; then
        log_success "✅ 애플리케이션 헬스 체크 통과"
    else
        log_error "❌ 애플리케이션 헬스 체크 실패"
        return 1
    fi
    
    # 메트릭스 체크
    log_info "메트릭스 체크..."
    if curl -f http://localhost:3000/metrics >/dev/null 2>&1; then
        log_success "✅ 메트릭스 체크 통과"
    else
        log_error "❌ 메트릭스 체크 실패"
        return 1
    fi
    
    # API 엔드포인트 체크
    log_info "API 엔드포인트 체크..."
    if curl -f http://localhost:3000/api/status >/dev/null 2>&1; then
        log_success "✅ API 엔드포인트 체크 통과"
    else
        log_warning "⚠️ API 엔드포인트 체크 실패 (일부 기능 제한)"
    fi
    
    return 0
}

# 컨테이너 로그 확인
check_logs() {
    log_info "컨테이너 로그 확인 중..."
    
    # PostgreSQL 로그
    log_info "PostgreSQL 로그:"
    docker-compose -f docker-compose.prod.yml logs --tail=10 postgres
    
    # Redis 로그
    log_info "Redis 로그:"
    docker-compose -f docker-compose.prod.yml logs --tail=10 redis
    
    # 애플리케이션 로그
    log_info "애플리케이션 로그:"
    docker-compose -f docker-compose.prod.yml logs --tail=20 app
}

# CI/CD 테스트 실행
run_cicd_test() {
    log_info "CI/CD 테스트 실행 중..."
    
    # 1. 환경 변수 설정
    setup_environment
    
    # 2. Docker Compose 설정 검증
    validate_docker_compose "docker-compose.prod.yml"
    if [ $? -ne 0 ]; then
        log_error "Docker Compose 설정 검증 실패"
        return 1
    fi
    
    # 3. 기존 컨테이너 정리
    cleanup_containers
    
    # 4. PostgreSQL 초기화
    setup_postgresql
    if [ $? -ne 0 ]; then
        log_error "PostgreSQL 초기화 실패"
        check_logs
        return 1
    fi
    
    # 5. Redis 초기화
    setup_redis
    if [ $? -ne 0 ]; then
        log_error "Redis 초기화 실패"
        check_logs
        return 1
    fi
    
    # 6. 애플리케이션 시작
    start_application
    if [ $? -ne 0 ]; then
        log_error "애플리케이션 시작 실패"
        check_logs
        return 1
    fi
    
    # 7. Nginx 시작
    start_nginx
    if [ $? -ne 0 ]; then
        log_error "Nginx 시작 실패"
        check_logs
        return 1
    fi
    
    # 8. 헬스 체크
    health_check
    if [ $? -ne 0 ]; then
        log_error "헬스 체크 실패"
        check_logs
        return 1
    fi
    
    log_success "CI/CD 테스트 완료"
    log_info "애플리케이션 URL: http://localhost:3000"
    log_info "Nginx URL: http://localhost:80"
    
    return 0
}

# 메뉴 표시
show_menu() {
    echo ""
    log_info "CI/CD Docker 관리 도구"
    echo "1. 환경 변수 설정"
    echo "2. Docker Compose 설정 검증"
    echo "3. 기존 컨테이너 정리"
    echo "4. PostgreSQL 초기화"
    echo "5. Redis 초기화"
    echo "6. 애플리케이션 시작"
    echo "7. Nginx 시작"
    echo "8. 헬스 체크"
    echo "9. 컨테이너 로그 확인"
    echo "10. 전체 CI/CD 테스트 실행"
    echo "11. 종료"
    echo ""
}

# 메인 실행 함수
main() {
    while true; do
        show_menu
        read -p "선택하세요 (1-11): " choice
        
        case $choice in
            1)
                setup_environment
                read -p "계속하려면 Enter를 누르세요..."
                ;;
            2)
                validate_docker_compose "docker-compose.prod.yml"
                read -p "계속하려면 Enter를 누르세요..."
                ;;
            3)
                cleanup_containers
                read -p "계속하려면 Enter를 누르세요..."
                ;;
            4)
                setup_postgresql
                read -p "계속하려면 Enter를 누르세요..."
                ;;
            5)
                setup_redis
                read -p "계속하려면 Enter를 누르세요..."
                ;;
            6)
                start_application
                read -p "계속하려면 Enter를 누르세요..."
                ;;
            7)
                start_nginx
                read -p "계속하려면 Enter를 누르세요..."
                ;;
            8)
                health_check
                read -p "계속하려면 Enter를 누르세요..."
                ;;
            9)
                check_logs
                read -p "계속하려면 Enter를 누르세요..."
                ;;
            10)
                run_cicd_test
                read -p "계속하려면 Enter를 누르세요..."
                ;;
            11)
                log_info "CI/CD Docker 관리 도구를 종료합니다."
                exit 0
                ;;
            *)
                log_error "잘못된 선택입니다. 1-11 중에서 선택하세요."
                sleep 2
                ;;
        esac
    done
}

# 스크립트 실행
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
