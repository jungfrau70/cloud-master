#!/bin/bash

# 🔧 환경 변수 설정 스크립트
# 사용자로부터 환경 변수를 입력받아 .env 파일에 저장합니다

set -e # 오류 발생 시 스크립트 중단

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

# 날짜별 필수 환경 변수 정의
declare -A DAY_REQUIRED_VARS
DAY_REQUIRED_VARS[day1]="PROJECT_NAME DOCKER_USERNAME GITHUB_USERNAME AWS_VM_NAME AWS_VM_HOST AWS_VM_USERNAME AWS_VM_SSH_KEY"
DAY_REQUIRED_VARS[day2]="PROJECT_NAME DOCKER_USERNAME GITHUB_USERNAME GCP_GKE_CLUSTER_NAME GCP_ZONE GCP_PROJECT_ID"
DAY_REQUIRED_VARS[day3]="PROJECT_NAME DOCKER_USERNAME GITHUB_USERNAME AWS_EKS_CLUSTER_NAME AWS_REGION GCP_GKE_CLUSTER_NAME GCP_ZONE PROMETHEUS_PORT GRAFANA_PORT"

# 전체 필수 환경 변수 (모든 날짜에 공통)
REQUIRED_VARS=("PROJECT_NAME" "DOCKER_USERNAME" "GITHUB_USERNAME")

# 선택적 환경 변수 정의
OPTIONAL_VARS=("DOCKER_TAG" "GITHUB_REPO_NAME" "APP_PORT" "APP_HOST" "NODE_ENV" "LOG_LEVEL" "POSTGRES_DB" "POSTGRES_USER" "POSTGRES_PASSWORD" "POSTGRES_PORT" "REDIS_PORT" "PROMETHEUS_PORT" "GRAFANA_PORT" "GRAFANA_USER" "GRAFANA_PASSWORD")

# 환경 변수 기본값 정의
declare -A DEFAULT_VALUES
DEFAULT_VALUES[PROJECT_NAME]="github-actions-demo"
DEFAULT_VALUES[DOCKER_USERNAME]=""
DEFAULT_VALUES[DOCKER_IMAGE_NAME]=""
DEFAULT_VALUES[DOCKER_TAG]="latest"
DEFAULT_VALUES[GITHUB_USERNAME]=""
DEFAULT_VALUES[GITHUB_REPO_NAME]="github-actions-demo"
DEFAULT_VALUES[APP_PORT]="3000"
DEFAULT_VALUES[APP_HOST]="localhost"
DEFAULT_VALUES[NODE_ENV]="development"
DEFAULT_VALUES[LOG_LEVEL]="info"
DEFAULT_VALUES[POSTGRES_DB]="github_actions_demo"
DEFAULT_VALUES[POSTGRES_USER]="postgres"
DEFAULT_VALUES[POSTGRES_PASSWORD]="password"
DEFAULT_VALUES[POSTGRES_PORT]="5432"
DEFAULT_VALUES[REDIS_PORT]="6379"
DEFAULT_VALUES[PROMETHEUS_PORT]="9090"
DEFAULT_VALUES[GRAFANA_PORT]="3001"
DEFAULT_VALUES[GRAFANA_USER]="admin"
DEFAULT_VALUES[GRAFANA_PASSWORD]="admin"

# 환경 변수 설명 정의
declare -A DESCRIPTIONS
DESCRIPTIONS[PROJECT_NAME]="프로젝트 이름"
DESCRIPTIONS[DOCKER_USERNAME]="Docker Hub 사용자 이름"
DESCRIPTIONS[DOCKER_IMAGE_NAME]="Docker 이미지 이름 (자동 생성됨)"
DESCRIPTIONS[DOCKER_TAG]="Docker 이미지 태그"
DESCRIPTIONS[GITHUB_USERNAME]="GitHub 사용자 이름"
DESCRIPTIONS[GITHUB_REPO_NAME]="GitHub 저장소 이름"
DESCRIPTIONS[APP_PORT]="애플리케이션 포트"
DESCRIPTIONS[APP_HOST]="애플리케이션 호스트"
DESCRIPTIONS[NODE_ENV]="Node.js 환경"
DESCRIPTIONS[LOG_LEVEL]="로그 레벨"
DESCRIPTIONS[POSTGRES_DB]="PostgreSQL 데이터베이스 이름"
DESCRIPTIONS[POSTGRES_USER]="PostgreSQL 사용자 이름"
DESCRIPTIONS[POSTGRES_PASSWORD]="PostgreSQL 비밀번호"
DESCRIPTIONS[POSTGRES_PORT]="PostgreSQL 포트"
DESCRIPTIONS[REDIS_PORT]="Redis 포트"
DESCRIPTIONS[PROMETHEUS_PORT]="Prometheus 포트"
DESCRIPTIONS[GRAFANA_PORT]="Grafana 포트"
DESCRIPTIONS[GRAFANA_USER]="Grafana 사용자 이름"
DESCRIPTIONS[GRAFANA_PASSWORD]="Grafana 비밀번호"

# 필수/선택 여부 확인 함수
is_required() {
    local var_name=$1
    for required_var in "${REQUIRED_VARS[@]}"; do
        if [ "$required_var" = "$var_name" ]; then
            return 0
        fi
    done
    return 1
}

# 개별 환경 변수 확인 및 수정
check_and_update_var() {
    local var_name=$1
    local description=${DESCRIPTIONS[$var_name]}
    local current_value=${!var_name}
    local default_value=${DEFAULT_VALUES[$var_name]}
    local is_required_var=false
    
    # 필수 여부 확인
    if is_required "$var_name"; then
        is_required_var=true
    fi
    
    echo ""
    if [ "$is_required_var" = true ]; then
        log_info "📝 $description ${RED}(필수)${NC}"
    else
        log_info "📝 $description ${YELLOW}(선택)${NC}"
    fi
    
    # 현재 값 표시
    if [ -n "$current_value" ]; then
        echo -e "현재 값: ${GREEN}$current_value${NC}"
    else
        echo -e "현재 값: ${YELLOW}(설정되지 않음)${NC}"
    fi
    
    # 기본값 표시
    if [ -n "$default_value" ]; then
        echo -e "기본값: ${YELLOW}$default_value${NC}"
    fi
    
    # 사용자 선택
    if [ -n "$current_value" ]; then
        echo ""
        echo "1) 현재 값 사용: $current_value"
        echo "2) 새 값 입력"
        if [ -n "$default_value" ]; then
            echo "3) 기본값 사용: $default_value"
        fi
        echo ""
        echo "현재 확인 중인 변수: $var_name ($description)"
        read -p "선택하세요 (1-3): " choice
        
        case $choice in
            1)
                # 현재 값 사용
                echo "$current_value"
                ;;
            2)
                # 새 값 입력
                if [ "$is_required_var" = true ]; then
                    read -p "새 값을 입력하세요 (필수): " input_value
                else
                    read -p "새 값을 입력하세요: " input_value
                fi
                
                if [ -z "$input_value" ] && [ "$is_required_var" = true ]; then
                    log_error "❌ 필수 변수입니다. 값을 입력해주세요."
                    return 1
                fi
                
                echo "${input_value:-$current_value}"
                ;;
            3)
                # 기본값 사용
                if [ -n "$default_value" ]; then
                    echo "$default_value"
                else
                    echo "$current_value"
                fi
                ;;
            *)
                log_warning "잘못된 선택입니다. 현재 값을 사용합니다."
                echo "$current_value"
                ;;
        esac
    else
        # 현재 값이 없는 경우
        if [ "$is_required_var" = true ]; then
            read -p "값을 입력하세요 (필수): " input_value
            if [ -z "$input_value" ]; then
                log_error "❌ 필수 변수입니다. 값을 입력해주세요."
                return 1
            fi
            echo "$input_value"
        else
            if [ -n "$default_value" ]; then
                read -p "값을 입력하세요 (Enter: 기본값 사용): " input_value
                echo "${input_value:-$default_value}"
            else
                read -p "값을 입력하세요: " input_value
                echo "$input_value"
            fi
        fi
    fi
}

# 환경 변수 입력받기 (기존 함수 유지)
get_env_value() {
    local var_name=$1
    local description=${DESCRIPTIONS[$var_name]}
    local default_value=${DEFAULT_VALUES[$var_name]}
    local is_required_var=false
    
    # 필수 여부 확인
    if is_required "$var_name"; then
        is_required_var=true
    fi
    
    echo ""
    if [ "$is_required_var" = true ]; then
        log_info "📝 $description 설정 ${RED}(필수)${NC}"
    else
        log_info "📝 $description 설정 ${YELLOW}(선택)${NC}"
    fi
    
    if [ -n "$default_value" ]; then
        echo -e "기본값: ${YELLOW}$default_value${NC}"
        if [ "$is_required_var" = true ]; then
            read -p "값을 입력하세요 (필수): " input_value
        else
            read -p "값을 입력하세요 (Enter: 기본값 사용): " input_value
        fi
    else
        if [ "$is_required_var" = true ]; then
            read -p "값을 입력하세요 (필수): " input_value
        else
            read -p "값을 입력하세요 (선택): " input_value
        fi
    fi
    
    # 입력값이 없으면 기본값 사용
    if [ -z "$input_value" ]; then
        if [ "$is_required_var" = true ]; then
            log_error "❌ 필수 변수입니다. 값을 입력해주세요."
            return 1
        else
            input_value="$default_value"
        fi
    fi
    
    # 특별한 처리
    case $var_name in
        "DOCKER_IMAGE_NAME")
            if [ -n "$DOCKER_USERNAME" ] && [ -n "$PROJECT_NAME" ]; then
                input_value="${DOCKER_USERNAME}/${PROJECT_NAME}"
                log_info "자동 생성됨: $input_value"
            fi
            ;;
    esac
    
    echo "$input_value"
}

# 기존 .env 파일 읽기
load_existing_env() {
    if [ -f .env ]; then
        log_info "📁 기존 .env 파일을 발견했습니다."
        echo ""
        log_info "기존 설정값들:"
        
        # Windows 줄바꿈 문자 제거하고 환경 변수 표시
        while IFS='=' read -r key value; do
            # Windows 줄바꿈 문자 제거
            key=$(echo "$key" | tr -d '\r')
            value=$(echo "$value" | tr -d '\r')
            
            # 주석이나 빈 줄 건너뛰기
            if [[ $key =~ ^[[:space:]]*# ]] || [[ -z $key ]]; then
                continue
            fi
            
            # 따옴표 제거
            value=$(echo "$value" | sed 's/^"//;s/"$//')
            
            # 기존 값 표시
            if [ -n "$value" ]; then
                echo "  $key: $value"
            fi
        done < .env
        
        echo ""
        read -p "기존 설정을 사용하시겠습니까? (y/N): " use_existing
        
        if [[ $use_existing =~ ^[Yy]$ ]]; then
            log_info "기존 .env 파일을 로드합니다..."
            
            # Windows 줄바꿈 문자를 제거한 임시 파일 생성
            sed 's/\r$//' .env > .env.tmp
            source .env.tmp
            rm -f .env.tmp
            
            # 변수명 매핑 (기존 .env 형식을 스크립트 형식으로 변환)
            map_existing_vars
            
            return 0
        else
            log_info "새로운 설정을 입력받습니다..."
            return 1
        fi
    else
        log_info "기존 .env 파일이 없습니다. 새로운 설정을 입력받습니다..."
        return 1
    fi
}

# 기존 .env 파일의 변수명을 스크립트 형식으로 매핑
map_existing_vars() {
    # 기존 .env 파일의 변수명을 스크립트에서 사용하는 변수명으로 매핑
    if [ -n "$PORT" ]; then
        APP_PORT="$PORT"
    fi
    if [ -n "$HOST" ]; then
        APP_HOST="$HOST"
    fi
    if [ -n "$DB_NAME" ]; then
        POSTGRES_DB="$DB_NAME"
    fi
    if [ -n "$DB_USER" ]; then
        POSTGRES_USER="$DB_USER"
    fi
    if [ -n "$DB_PASSWORD" ]; then
        POSTGRES_PASSWORD="$DB_PASSWORD"
    fi
    if [ -n "$DB_PORT" ]; then
        POSTGRES_PORT="$DB_PORT"
    fi
    if [ -n "$REDIS_PORT" ]; then
        REDIS_PORT="$REDIS_PORT"
    fi
    if [ -n "$GITHUB_REPOSITORY" ]; then
        GITHUB_REPO_NAME=$(echo "$GITHUB_REPOSITORY" | cut -d'/' -f2)
        GITHUB_USERNAME=$(echo "$GITHUB_REPOSITORY" | cut -d'/' -f1)
    fi
    if [ -n "$PROMETHEUS_URL" ]; then
        PROMETHEUS_PORT=$(echo "$PROMETHEUS_URL" | cut -d':' -f3)
    fi
    if [ -n "$GRAFANA_URL" ]; then
        GRAFANA_PORT=$(echo "$GRAFANA_URL" | cut -d':' -f3)
    fi
    
    # 프로젝트 이름이 없으면 기본값 설정
    if [ -z "$PROJECT_NAME" ]; then
        PROJECT_NAME="github-actions-demo"
    fi
    
    # Docker 이미지 이름 자동 생성
    if [ -n "$DOCKER_USERNAME" ] && [ -n "$PROJECT_NAME" ]; then
        DOCKER_IMAGE_NAME="${DOCKER_USERNAME}/${PROJECT_NAME}"
    fi
    
    log_info "기존 변수들을 스크립트 형식으로 매핑했습니다."
}

# 기존 .env 파일 백업
backup_existing_env() {
    if [ -f .env ]; then
        local backup_file=".env.backup.$(date +%Y%m%d_%H%M%S)"
        cp .env "$backup_file"
        log_info "기존 .env 파일을 $backup_file로 백업했습니다."
    fi
}

# 환경 변수 파일 생성
create_env_file() {
    log_info "🔧 환경 변수 파일을 생성합니다..."
    
    # .env 파일 생성
    cat > .env << EOF
# 🚀 GitHub Actions Demo 프로젝트 환경 변수 설정
# 생성일: $(date)
# 생성자: $(whoami)

# --- 프로젝트 기본 설정 ---
PROJECT_NAME="$PROJECT_NAME"
APP_HOST="$APP_HOST"
APP_PORT="$APP_PORT"
NODE_ENV="$NODE_ENV"
LOG_LEVEL="$LOG_LEVEL"

# --- Docker 설정 ---
DOCKER_USERNAME="$DOCKER_USERNAME"
DOCKER_IMAGE_NAME="$DOCKER_IMAGE_NAME"
DOCKER_TAG="$DOCKER_TAG"

# --- GitHub 설정 ---
GITHUB_USERNAME="$GITHUB_USERNAME"
GITHUB_REPO_NAME="$GITHUB_REPO_NAME"

# --- 데이터베이스 설정 (PostgreSQL) ---
POSTGRES_DB="$POSTGRES_DB"
POSTGRES_USER="$POSTGRES_USER"
POSTGRES_PASSWORD="$POSTGRES_PASSWORD"
POSTGRES_PORT="$POSTGRES_PORT"

# --- Redis 설정 ---
REDIS_PORT="$REDIS_PORT"

# --- 모니터링 설정 (Prometheus & Grafana) ---
PROMETHEUS_PORT="$PROMETHEUS_PORT"
GRAFANA_PORT="$GRAFANA_PORT"
GRAFANA_USER="$GRAFANA_USER"
GRAFANA_PASSWORD="$GRAFANA_PASSWORD"

# --- 클라우드 서비스 인증 정보 (선택 사항) ---
# AWS
# AWS_ACCESS_KEY_ID="YOUR_AWS_ACCESS_KEY_ID"
# AWS_SECRET_ACCESS_KEY="YOUR_AWS_SECRET_ACCESS_KEY"
# AWS_REGION="ap-northeast-2"

# GCP
# GCP_PROJECT_ID="your-gcp-project-id"
# GCP_SERVICE_ACCOUNT_KEY_PATH="/path/to/your/gcp-key.json"

# --- GitHub Actions Secrets (CI/CD 파이프라인에서 사용) ---
# DOCKER_USERNAME (위에서 설정)
# DOCKER_PASSWORD (Docker Hub Personal Access Token)
# AWS_ACCESS_KEY_ID (위에서 설정)
# AWS_SECRET_ACCESS_KEY (위에서 설정)
# GCP_SERVICE_ACCOUNT_KEY (Base64 인코딩된 GCP 서비스 계정 키 JSON)
EOF

    log_success "✅ .env 파일이 생성되었습니다!"
}

# 환경 변수 검증
validate_env_vars() {
    log_info "🔍 환경 변수 검증 중..."
    
    local errors=0
    
    # 필수 변수 검증
    for var in "${REQUIRED_VARS[@]}"; do
        if [ -z "${!var}" ]; then
            log_error "❌ 필수 변수가 비어있습니다: $var"
            errors=$((errors + 1))
        fi
    done
    
    # 포트 번호 검증 (선택적)
    if [ -n "$APP_PORT" ] && (! [[ "$APP_PORT" =~ ^[0-9]+$ ]] || [ "$APP_PORT" -lt 1 ] || [ "$APP_PORT" -gt 65535 ]); then
        log_error "❌ 잘못된 포트 번호: $APP_PORT"
        errors=$((errors + 1))
    fi
    
    if [ -n "$POSTGRES_PORT" ] && (! [[ "$POSTGRES_PORT" =~ ^[0-9]+$ ]] || [ "$POSTGRES_PORT" -lt 1 ] || [ "$POSTGRES_PORT" -gt 65535 ]); then
        log_error "❌ 잘못된 PostgreSQL 포트 번호: $POSTGRES_PORT"
        errors=$((errors + 1))
    fi
    
    if [ -n "$REDIS_PORT" ] && (! [[ "$REDIS_PORT" =~ ^[0-9]+$ ]] || [ "$REDIS_PORT" -lt 1 ] || [ "$REDIS_PORT" -gt 65535 ]); then
        log_error "❌ 잘못된 Redis 포트 번호: $REDIS_PORT"
        errors=$((errors + 1))
    fi
    
    if [ $errors -eq 0 ]; then
        log_success "✅ 모든 환경 변수가 유효합니다!"
        return 0
    else
        log_error "❌ $errors 개의 오류가 발견되었습니다."
        return 1
    fi
}

# 환경 변수 미리보기
preview_env_vars() {
    log_info "📋 설정된 환경 변수 미리보기:"
    echo ""
    echo "프로젝트 설정:"
    echo "  PROJECT_NAME: $PROJECT_NAME"
    echo "  APP_HOST: $APP_HOST"
    echo "  APP_PORT: $APP_PORT"
    echo "  NODE_ENV: $NODE_ENV"
    echo ""
    echo "Docker 설정:"
    echo "  DOCKER_USERNAME: $DOCKER_USERNAME"
    echo "  DOCKER_IMAGE_NAME: $DOCKER_IMAGE_NAME"
    echo "  DOCKER_TAG: $DOCKER_TAG"
    echo ""
    echo "GitHub 설정:"
    echo "  GITHUB_USERNAME: $GITHUB_USERNAME"
    echo "  GITHUB_REPO_NAME: $GITHUB_REPO_NAME"
    echo ""
    echo "데이터베이스 설정:"
    echo "  POSTGRES_DB: $POSTGRES_DB"
    echo "  POSTGRES_USER: $POSTGRES_USER"
    echo "  POSTGRES_PORT: $POSTGRES_PORT"
    echo ""
    echo "모니터링 설정:"
    echo "  PROMETHEUS_PORT: $PROMETHEUS_PORT"
    echo "  GRAFANA_PORT: $GRAFANA_PORT"
    echo "  GRAFANA_USER: $GRAFANA_USER"
}

# 날짜별 필수 변수 확인
check_day_required_vars() {
    local day=$1
    
    log_info "📅 $day 실습에 필요한 필수 환경 변수를 확인합니다..."
    echo ""
    
    # 해당 날짜의 필수 변수들 확인
    local required_vars=(${DAY_REQUIRED_VARS[$day]})
    
    # 간단한 확인 옵션 제공
    echo "🔍 필수 변수들을 확인합니다:"
    for var in "${required_vars[@]}"; do
        local current_value=${!var}
        local description=${DESCRIPTIONS[$var]}
        if [ -n "$current_value" ]; then
            echo "  ✅ $var: $current_value ($description)"
        else
            echo "  ❌ $var: (설정되지 않음) ($description)"
        fi
    done
    
    echo ""
    read -p "모든 변수를 개별적으로 확인하시겠습니까? (y/N): " check_individual
    
    if [[ $check_individual =~ ^[Yy]$ ]]; then
        # 개별 확인
        for var in "${required_vars[@]}"; do
            local new_value=$(check_and_update_var "$var")
            if [ $? -eq 0 ]; then
                eval "$var='$new_value'"
            else
                log_error "환경 변수 설정에 실패했습니다: $var"
                return 1
            fi
        done
    else
        # 현재 값 그대로 사용
        log_info "현재 설정된 값들을 그대로 사용합니다."
    fi
    
    # Docker 이미지 이름 자동 생성
    if [ -n "$DOCKER_USERNAME" ] && [ -n "$PROJECT_NAME" ]; then
        DOCKER_IMAGE_NAME="${DOCKER_USERNAME}/${PROJECT_NAME}"
        log_info "Docker 이미지 이름이 자동 생성되었습니다: $DOCKER_IMAGE_NAME"
    fi
    
    log_success "✅ $day 필수 환경 변수 설정 완료!"
}

# 환경 변수 입력받기
input_env_vars() {
    log_info "📝 환경 변수를 입력해주세요. (Enter: 기본값 사용)"
    echo ""
    
    # 기본 변수들 입력받기
    PROJECT_NAME=$(get_env_value "PROJECT_NAME")
    DOCKER_USERNAME=$(get_env_value "DOCKER_USERNAME")
    GITHUB_USERNAME=$(get_env_value "GITHUB_USERNAME")
    GITHUB_REPO_NAME=$(get_env_value "GITHUB_REPO_NAME")
    
    # Docker 이미지 이름 자동 생성
    DOCKER_IMAGE_NAME="${DOCKER_USERNAME}/${PROJECT_NAME}"
    log_info "Docker 이미지 이름이 자동 생성되었습니다: $DOCKER_IMAGE_NAME"
    
    # 나머지 변수들 입력받기
    DOCKER_TAG=$(get_env_value "DOCKER_TAG")
    APP_PORT=$(get_env_value "APP_PORT")
    APP_HOST=$(get_env_value "APP_HOST")
    NODE_ENV=$(get_env_value "NODE_ENV")
    LOG_LEVEL=$(get_env_value "LOG_LEVEL")
    
    # 데이터베이스 설정
    POSTGRES_DB=$(get_env_value "POSTGRES_DB")
    POSTGRES_USER=$(get_env_value "POSTGRES_USER")
    POSTGRES_PASSWORD=$(get_env_value "POSTGRES_PASSWORD")
    POSTGRES_PORT=$(get_env_value "POSTGRES_PORT")
    REDIS_PORT=$(get_env_value "REDIS_PORT")
    
    # 모니터링 설정
    PROMETHEUS_PORT=$(get_env_value "PROMETHEUS_PORT")
    GRAFANA_PORT=$(get_env_value "GRAFANA_PORT")
    GRAFANA_USER=$(get_env_value "GRAFANA_USER")
    GRAFANA_PASSWORD=$(get_env_value "GRAFANA_PASSWORD")
}

# 메인 실행
main() {
    log_info "🚀 환경 변수 설정을 시작합니다..."
    echo ""
    
    # 실습 날짜 선택
    echo "📅 실습 날짜를 선택하세요:"
    echo "1) Day 1: 기본 CI/CD 파이프라인 구축"
    echo "2) Day 2: 고급 CI/CD 파이프라인 구축"
    echo "3) Day 3: 모니터링 및 최적화"
    echo "4) 전체 실습 (모든 환경 변수)"
    echo "5) 기존 .env 파일 사용"
    
    read -p "선택하세요 (1-5): " day_choice
    
    case $day_choice in
        1)
            SELECTED_DAY="day1"
            ;;
        2)
            SELECTED_DAY="day2"
            ;;
        3)
            SELECTED_DAY="day3"
            ;;
        4)
            SELECTED_DAY="all"
            ;;
        5)
            SELECTED_DAY="existing"
            ;;
        *)
            log_error "잘못된 선택입니다."
            exit 1
            ;;
    esac
    
    # 기존 .env 파일 확인 및 로드
    if load_existing_env; then
        log_success "✅ 기존 .env 파일을 로드했습니다!"
        
        # Docker 이미지 이름 자동 생성
        if [ -n "$DOCKER_USERNAME" ] && [ -n "$PROJECT_NAME" ]; then
            DOCKER_IMAGE_NAME="${DOCKER_USERNAME}/${PROJECT_NAME}"
            log_info "Docker 이미지 이름이 자동 생성되었습니다: $DOCKER_IMAGE_NAME"
        fi
        
        # 선택된 날짜에 따른 처리
        if [ "$SELECTED_DAY" = "existing" ]; then
            # 기존 설정 그대로 사용
            log_success "🎉 기존 환경 변수를 사용합니다!"
            echo ""
            log_info "다음 단계:"
            log_info "1. 'npm run setup'을 실행하여 프로젝트를 설정하세요"
            log_info "2. 'npm run check:auth'를 실행하여 인증 상태를 확인하세요"
            return 0
        elif [ "$SELECTED_DAY" = "all" ]; then
            # 모든 환경 변수 확인
            log_info "전체 실습을 위한 모든 환경 변수를 확인합니다..."
            echo ""
            
            # 필수 변수들 확인
            for var in "${REQUIRED_VARS[@]}"; do
                local new_value=$(check_and_update_var "$var")
                if [ $? -eq 0 ]; then
                    eval "$var='$new_value'"
                else
                    log_error "환경 변수 설정에 실패했습니다: $var"
                    exit 1
                fi
            done
            
            # 선택적 변수들 확인
            for var in "${OPTIONAL_VARS[@]}"; do
                local new_value=$(check_and_update_var "$var")
                if [ $? -eq 0 ]; then
                    eval "$var='$new_value'"
                fi
            done
        else
            # 특정 날짜의 필수 변수만 확인
            check_day_required_vars "$SELECTED_DAY"
        fi
    else
        # 새로운 환경 변수 입력받기
        if [ "$SELECTED_DAY" = "all" ]; then
            input_env_vars
        else
            check_day_required_vars "$SELECTED_DAY"
        fi
    fi
    
    echo ""
    log_info "🔍 환경 변수 검증 중..."
    
    # 환경 변수 검증
    if ! validate_env_vars; then
        log_error "환경 변수 검증에 실패했습니다. 다시 시도해주세요."
        exit 1
    fi
    
    # 미리보기 표시
    preview_env_vars
    
    echo ""
    read -p "이 설정으로 .env 파일을 생성하시겠습니까? (y/N): " confirm
    
    if [[ $confirm =~ ^[Yy]$ ]]; then
        # 기존 .env 파일 백업
        backup_existing_env
        
        create_env_file
        log_success "🎉 환경 변수 설정이 완료되었습니다!"
        echo ""
        log_info "다음 단계:"
        log_info "1. .env 파일의 설정값들을 확인하세요"
        log_info "2. 필요한 경우 .env 파일을 수정하세요"
        log_info "3. 'npm run setup'을 실행하여 프로젝트를 설정하세요"
        log_info "4. 'npm run check:auth'를 실행하여 인증 상태를 확인하세요"
    else
        log_warning "환경 변수 설정이 취소되었습니다."
        exit 0
    fi
}

# 스크립트가 직접 실행된 경우에만 main 함수 실행
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi
