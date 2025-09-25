#!/bin/bash

# 📅 날짜별 실습 범위 설정
# 각 날짜별로 실행할 실습 범위를 정의합니다

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

# 날짜별 실습 범위 정의
declare -A DAY_SCOPE

# Day 1: 기본 CI/CD 파이프라인 구축
DAY_SCOPE[day1]="
- GitHub 저장소 생성 및 기본 설정
- Docker 이미지 수동 빌드 및 테스트
- 기본 CI 워크플로우 설정
- Docker Hub 이미지 푸시
- 기본 테스트 실행
- AWS EC2 VM 배포
- GCP Compute Engine VM 배포
- 멀티 클라우드 자동화 배포
"

# Day 2: 고급 CI/CD 파이프라인 구축
DAY_SCOPE[day2]="
- 멀티스테이지 Dockerfile 구축
- 환경별 배포 파이프라인
- 자동화된 테스트 및 품질 검사
- Docker Compose 통합
- 모니터링 시스템 구축
"

# Day 3: 모니터링 및 최적화
DAY_SCOPE[day3]="
- Prometheus 및 Grafana 설정
- 로깅 시스템 구축
- 알림 시스템 설정
- 성능 최적화
- 비용 최적화
- 보안 스캔 및 취약점 분석
"

# 전체 실습 범위
DAY_SCOPE[all]="
- 모든 Day 1-3 실습 포함
- 완전한 CI/CD 파이프라인
- 프로덕션 환경 배포
- 모니터링 및 알림
- 성능 및 보안 최적화
"

# 날짜별 Docker 이미지 빌드 범위
declare -A DAY_DOCKER_BUILDS

DAY_DOCKER_BUILDS[day1]="
- Dockerfile (기본)
- Dockerfile.dev (개발용)
"

DAY_DOCKER_BUILDS[day2]="
- Dockerfile (기본)
- Dockerfile.dev (개발용)
- Dockerfile.test (테스트용)
- Dockerfile.multistage (멀티스테이지)
"

DAY_DOCKER_BUILDS[day3]="
- 모든 Dockerfile 빌드
- 모니터링 컨테이너 빌드
- 최적화된 프로덕션 이미지
"

# 날짜별 테스트 범위
declare -A DAY_TESTS

DAY_TESTS[day1]="
- 단위 테스트 (기본)
- 애플리케이션 헬스 체크
"

DAY_TESTS[day2]="
- 단위 테스트
- 통합 테스트
- Docker 컨테이너 테스트
- API 엔드포인트 테스트
"

DAY_TESTS[day3]="
- 모든 테스트
- 성능 테스트
- 보안 테스트
- 부하 테스트
"

# 날짜별 서비스 범위
declare -A DAY_SERVICES

DAY_SERVICES[day1]="
- 애플리케이션 서비스
- 기본 헬스 체크
"

DAY_SERVICES[day2]="
- 애플리케이션 서비스
- 데이터베이스 서비스
- Redis 서비스
- Docker Compose 스택
"

DAY_SERVICES[day3]="
- 모든 서비스
- Prometheus 모니터링
- Grafana 대시보드
- 알림 시스템
"

# 날짜별 환경 변수 설정
declare -A DAY_ENV_VARS

DAY_ENV_VARS[day1]="
PROJECT_NAME
DOCKER_USERNAME
DOCKER_IMAGE_NAME
DOCKER_TAG
GITHUB_USERNAME
GITHUB_REPO_NAME
APP_PORT
APP_HOST
NODE_ENV
AWS_VM_HOST
AWS_VM_USERNAME
AWS_VM_SSH_KEY
GCP_VM_HOST
GCP_VM_USERNAME
GCP_VM_SSH_KEY
"

DAY_ENV_VARS[day2]="
${DAY_ENV_VARS[day1]}
DB_HOST
DB_PORT
DB_USER
DB_PASSWORD
DB_NAME
REDIS_HOST
REDIS_PORT
"

DAY_ENV_VARS[day3]="
${DAY_ENV_VARS[day2]}
PROMETHEUS_PORT
GRAFANA_PORT
GRAFANA_USER
GRAFANA_PASSWORD
LOG_LEVEL
LOG_FILE
SLACK_WEBHOOK_URL
SMTP_HOST
SMTP_USER
SMTP_PASSWORD
"

# 날짜별 실습 범위 출력
show_day_scope() {
    local day=$1
    
    if [ -z "$day" ]; then
        log_error "날짜를 지정해주세요. (day1, day2, day3, all)"
        return 1
    fi
    
    if [ -z "${DAY_SCOPE[$day]}" ]; then
        log_error "알 수 없는 날짜: $day"
        return 1
    fi
    
    log_info "📅 $day 실습 범위:"
    echo "${DAY_SCOPE[$day]}"
    
    log_info "🐳 Docker 이미지 빌드 범위:"
    echo "${DAY_DOCKER_BUILDS[$day]}"
    
    log_info "🧪 테스트 범위:"
    echo "${DAY_TESTS[$day]}"
    
    log_info "🚀 서비스 범위:"
    echo "${DAY_SERVICES[$day]}"
    
    log_info "⚙️ 필요한 환경 변수:"
    echo "${DAY_ENV_VARS[$day]}"
}

# 날짜별 실습 실행
run_day_practice() {
    local day=$1
    local action=${2:-"all"}
    
    if [ -z "$day" ]; then
        log_error "날짜를 지정해주세요. (day1, day2, day3, all)"
        return 1
    fi
    
    log_info "🚀 $day 실습을 시작합니다..."
    
    case $action in
        "scope")
            show_day_scope "$day"
            ;;
        "build")
            run_day_build "$day"
            ;;
        "test")
            run_day_test "$day"
            ;;
        "deploy")
            run_day_deploy "$day"
            ;;
        "all")
            run_day_all "$day"
            ;;
        *)
            log_error "알 수 없는 액션: $action"
            log_info "사용 가능한 액션: scope, build, test, deploy, all"
            return 1
            ;;
    esac
}

# 날짜별 빌드 실행
run_day_build() {
    local day=$1
    
    log_info "🐳 $day Docker 이미지 빌드를 시작합니다..."
    
    case $day in
        "day1")
            docker build -f Dockerfile -t ${DOCKER_IMAGE_NAME}:${DOCKER_TAG} .
            docker build -f Dockerfile.dev -t ${DOCKER_IMAGE_NAME}:dev .
            ;;
        "day2")
            docker build -f Dockerfile -t ${DOCKER_IMAGE_NAME}:${DOCKER_TAG} .
            docker build -f Dockerfile.dev -t ${DOCKER_IMAGE_NAME}:dev .
            docker build -f Dockerfile.test -t ${DOCKER_IMAGE_NAME}:test .
            docker build -f Dockerfile.multistage -t ${DOCKER_IMAGE_NAME}:multistage .
            ;;
        "day3")
            docker build -f Dockerfile -t ${DOCKER_IMAGE_NAME}:${DOCKER_TAG} .
            docker build -f Dockerfile.dev -t ${DOCKER_IMAGE_NAME}:dev .
            docker build -f Dockerfile.test -t ${DOCKER_IMAGE_NAME}:test .
            docker build -f Dockerfile.multistage -t ${DOCKER_IMAGE_NAME}:multistage .
            ;;
        "all")
            docker build -f Dockerfile -t ${DOCKER_IMAGE_NAME}:${DOCKER_TAG} .
            docker build -f Dockerfile.dev -t ${DOCKER_IMAGE_NAME}:dev .
            docker build -f Dockerfile.test -t ${DOCKER_IMAGE_NAME}:test .
            docker build -f Dockerfile.multistage -t ${DOCKER_IMAGE_NAME}:multistage .
            ;;
    esac
    
    log_success "$day Docker 이미지 빌드 완료!"
}

# 날짜별 테스트 실행
run_day_test() {
    local day=$1
    
    log_info "🧪 $day 테스트를 시작합니다..."
    
    case $day in
        "day1")
            npm run test:unit
            ;;
        "day2")
            npm run test:unit
            npm run test:integration
            ;;
        "day3")
            npm run test:unit
            npm run test:integration
            npm run test:coverage
            ;;
        "all")
            npm run test:unit
            npm run test:integration
            npm run test:coverage
            ;;
    esac
    
    log_success "$day 테스트 완료!"
}

# 날짜별 배포 실행
run_day_deploy() {
    local day=$1
    
    log_info "🚀 $day 배포를 시작합니다..."
    
    case $day in
        "day1")
            docker-compose up -d app
            ;;
        "day2")
            docker-compose up -d app db redis
            ;;
        "day3")
            docker-compose up -d
            ;;
        "all")
            docker-compose up -d
            ;;
    esac
    
    log_success "$day 배포 완료!"
}

# 날짜별 전체 실행
run_day_all() {
    local day=$1
    
    log_info "🎯 $day 전체 실습을 시작합니다..."
    
    # 환경 변수 확인
    if ! ./scripts/check-auth.sh; then
        log_error "인증 확인 실패"
        return 1
    fi
    
    # 의존성 설치
    if [ -f package-lock.json ]; then
        npm ci
    else
        npm install
    fi
    
    # 빌드
    run_day_build "$day"
    
    # 테스트
    run_day_test "$day"
    
    # 배포
    run_day_deploy "$day"
    
    log_success "🎉 $day 전체 실습 완료!"
}

# 도움말 표시
show_help() {
    echo "사용법: $0 [날짜] [액션]"
    echo ""
    echo "날짜:"
    echo "  day1       1일차: 기본 CI/CD 파이프라인 구축"
    echo "  day2       2일차: 고급 CI/CD 파이프라인 구축"
    echo "  day3       3일차: 모니터링 및 최적화"
    echo "  all        전체 실습"
    echo ""
    echo "액션:"
    echo "  scope      실습 범위 확인 (기본값)"
    echo "  build      Docker 이미지 빌드"
    echo "  test       테스트 실행"
    echo "  deploy     서비스 배포"
    echo "  all        전체 실습 실행"
    echo ""
    echo "예시:"
    echo "  $0 day1 scope      # 1일차 실습 범위 확인"
    echo "  $0 day2 build      # 2일차 Docker 이미지 빌드"
    echo "  $0 day3 all        # 3일차 전체 실습 실행"
    echo "  $0 all deploy      # 전체 실습 배포"
}

# 메인 실행
main() {
    local day=$1
    local action=${2:-"scope"}
    
    if [ -z "$day" ] || [ "$day" = "help" ] || [ "$day" = "--help" ] || [ "$day" = "-h" ]; then
        show_help
        return
    fi
    
    run_day_practice "$day" "$action"
}

# 스크립트가 직접 실행된 경우에만 main 함수 실행
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi
