#!/bin/bash

# Docker Compose 실습 자동화 스크립트 (현행화)
# Cloud Master Day2 - Docker Compose 및 고급 기능 실습
# 최신 문제 해결 방법 및 개선사항 반영

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

# 문제 해결 함수
fix_container_conflicts() {
    log_info "컨테이너 이름 충돌 문제 해결 중..."
    
    # 기존 컨테이너 완전 정리
    docker-compose down 2>/dev/null || true
    docker rm -f $(docker ps -a --filter "name=github-actions-demo" --format "{{.Names}}") 2>/dev/null || true
    docker network prune -f
    
    log_success "컨테이너 충돌 문제 해결 완료"
}

fix_redis_connection() {
    log_info "Redis 연결 문제 해결 중..."
    
    # Redis 클라이언트 설정 수정
    if [ -f "src/app.js" ]; then
        # IPv6 vs IPv4 문제 해결
        sed -i 's/host: '\''redis'\''/socket: { host: '\''redis'\'' }/g' src/app.js
        
        # 메서드명 수정 (setex -> setEx)
        sed -i 's/redisClient\.setex/redisClient.setEx/g' src/app.js
        
        log_success "Redis 연결 설정 수정 완료"
    fi
}

fix_postgresql_syntax() {
    log_info "PostgreSQL SQL 문법 오류 해결 중..."
    
    # timestamp 예약어 문제 해결
    if [ -f "database/init.sql" ]; then
        sed -i 's/timestamp TIMESTAMP/"timestamp" TIMESTAMP/g' database/init.sql
        sed -i 's/l\.timestamp/l\."timestamp"/g' database/init.sql
        
        log_success "PostgreSQL SQL 문법 수정 완료"
    fi
}

# 환경 체크 함수
check_environment() {
    log_info "실습 환경 체크 중..."
    
    # Docker 설치 확인
    if ! command -v docker &> /dev/null; then
        log_error "Docker가 설치되지 않았습니다."
        exit 1
    fi
    
    # Docker Compose 설치 확인
    if ! command -v docker-compose &> /dev/null; then
        log_error "Docker Compose가 설치되지 않았습니다."
        exit 1
    fi
    
    # 프로젝트 디렉토리 확인
    if [ ! -f "docker-compose.yml" ]; then
        log_error "docker-compose.yml 파일을 찾을 수 없습니다."
        exit 1
    fi
    
    log_success "환경 체크 완료"
}

# 개발 환경 실행 함수
run_development() {
    log_info "개발 환경 실행 중..."
    
    # 문제 해결 적용
    fix_container_conflicts
    fix_redis_connection
    fix_postgresql_syntax
    
    # 개발 환경 실행
    docker-compose up --build -d
    
    # 헬스체크 대기
    log_info "서비스 헬스체크 대기 중..."
    sleep 30
    
    # 서비스 상태 확인
    if curl -f http://localhost:3000/health > /dev/null 2>&1; then
        log_success "개발 환경 실행 완료"
        log_info "애플리케이션: http://localhost:3000"
        log_info "Nginx 프록시: http://localhost"
    else
        log_error "개발 환경 실행 실패"
        docker-compose logs
        exit 1
    fi
}

# 프로덕션 환경 실행 함수
run_production() {
    log_info "프로덕션 환경 실행 중..."
    
    # 환경 변수 파일 생성
    if [ ! -f ".env.prod" ]; then
        echo "DB_PASSWORD=secure_prod_password_123" > .env.prod
        echo "REDIS_PASSWORD=secure_redis_password_456" >> .env.prod
        log_info "프로덕션 환경 변수 파일 생성"
    fi
    
    # 문제 해결 적용
    fix_container_conflicts
    fix_redis_connection
    fix_postgresql_syntax
    
    # 프로덕션 환경 실행
    docker-compose -f docker-compose.prod.yml up --build -d
    
    # 헬스체크 대기
    log_info "서비스 헬스체크 대기 중..."
    sleep 30
    
    # 서비스 상태 확인
    if curl -f http://localhost:3000/health > /dev/null 2>&1; then
        log_success "프로덕션 환경 실행 완료"
        log_info "애플리케이션: http://localhost:3000"
        log_info "Nginx 프록시: http://localhost"
        log_info "메트릭: http://localhost/metrics"
    else
        log_error "프로덕션 환경 실행 실패"
        docker-compose -f docker-compose.prod.yml logs
        exit 1
    fi
}

# 테스트 함수
run_tests() {
    log_info "서비스 테스트 실행 중..."
    
    # 헬스체크 테스트
    if curl -f http://localhost:3000/health > /dev/null 2>&1; then
        log_success "헬스체크 테스트 통과"
    else
        log_error "헬스체크 테스트 실패"
        return 1
    fi
    
    # API 테스트
    if curl -f http://localhost/api/users > /dev/null 2>&1; then
        log_success "API 테스트 통과"
    else
        log_error "API 테스트 실패"
        return 1
    fi
    
    # Nginx 프록시 테스트
    if curl -f http://localhost/health > /dev/null 2>&1; then
        log_success "Nginx 프록시 테스트 통과"
    else
        log_error "Nginx 프록시 테스트 실패"
        return 1
    fi
    
    log_success "모든 테스트 통과"
}

# 정리 함수
cleanup() {
    log_info "환경 정리 중..."
    
    # 개발 환경 정리
    docker-compose down 2>/dev/null || true
    
    # 프로덕션 환경 정리
    docker-compose -f docker-compose.prod.yml down 2>/dev/null || true
    
    # 사용하지 않는 리소스 정리
    docker system prune -f
    
    log_success "환경 정리 완료"
}

# 로그 확인 함수
show_logs() {
    log_info "서비스 로그 확인 중..."
    
    echo -e "${PURPLE}=== 애플리케이션 로그 ===${NC}"
    docker-compose logs app
    
    echo -e "${PURPLE}=== 데이터베이스 로그 ===${NC}"
    docker-compose logs postgres
    
    echo -e "${PURPLE}=== Redis 로그 ===${NC}"
    docker-compose logs redis
    
    echo -e "${PURPLE}=== Nginx 로그 ===${NC}"
    docker-compose logs nginx
}

# 메인 함수
main() {
    case "${1:-dev}" in
        "dev")
            check_environment
            run_development
            run_tests
            ;;
        "prod")
            check_environment
            run_production
            run_tests
            ;;
        "test")
            run_tests
            ;;
        "logs")
            show_logs
            ;;
        "cleanup")
            cleanup
            ;;
        "help")
            echo "사용법: $0 [dev|prod|test|logs|cleanup|help]"
            echo "  dev     - 개발 환경 실행 (기본값)"
            echo "  prod    - 프로덕션 환경 실행"
            echo "  test    - 서비스 테스트 실행"
            echo "  logs    - 서비스 로그 확인"
            echo "  cleanup - 환경 정리"
            echo "  help    - 도움말 표시"
            ;;
        *)
            log_error "알 수 없는 옵션: $1"
            echo "사용법: $0 [dev|prod|test|logs|cleanup|help]"
            exit 1
            ;;
    esac
}

# 스크립트 실행
main "$@"
