#!/bin/bash

# Cloud Master Day3 환경 체크 스크립트
# 작성일: 2024년 9월 23일
# 목적: 실습 환경의 사전 요구사항을 자동으로 확인

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
log_header() { echo -e "${PURPLE}=== $1 ===${NC}"; }

# 체크 결과 저장
CHECKS_PASSED=0
CHECKS_FAILED=0
TOTAL_CHECKS=0

# 체크 함수
check_command() {
    local command_name="$1"
    local command="$2"
    local expected_output="$3"
    
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    
    log_info "체크 중: $command_name"
    
    if command -v "$command" &> /dev/null; then
        if [ -n "$expected_output" ]; then
            if eval "$command" | grep -q "$expected_output"; then
                log_success "✅ $command_name: 정상"
                CHECKS_PASSED=$((CHECKS_PASSED + 1))
            else
                log_error "❌ $command_name: 예상 출력과 다름"
                CHECKS_FAILED=$((CHECKS_FAILED + 1))
            fi
        else
            log_success "✅ $command_name: 설치됨"
            CHECKS_PASSED=$((CHECKS_PASSED + 1))
        fi
    else
        log_error "❌ $command_name: 설치되지 않음"
        CHECKS_FAILED=$((CHECKS_FAILED + 1))
    fi
}

# 시스템 정보 확인
check_system_info() {
    log_header "시스템 정보"
    
    echo "OS: $(uname -s)"
    echo "Kernel: $(uname -r)"
    echo "Architecture: $(uname -m)"
    echo "Hostname: $(hostname)"
    echo "User: $(whoami)"
    echo "Home: $HOME"
    echo "Working Directory: $(pwd)"
    echo ""
}

# 필수 도구 확인
check_prerequisites() {
    log_header "필수 도구 확인"
    
    # 기본 도구
    check_command "Git" "git --version"
    check_command "Curl" "curl --version"
    check_command "Wget" "wget --version"
    check_command "jq" "jq --version"
    check_command "Unzip" "unzip -v"
    
    # Docker 관련
    check_command "Docker" "docker --version"
    check_command "Docker Compose" "docker-compose --version"
    
    # 클라우드 CLI
    check_command "AWS CLI" "aws --version"
    check_command "GCP CLI" "gcloud --version"
    
    echo ""
}

# Docker 상태 확인
check_docker_status() {
    log_header "Docker 상태 확인"
    
    # Docker 서비스 상태
    if systemctl is-active --quiet docker; then
        log_success "✅ Docker 서비스: 실행 중"
        CHECKS_PASSED=$((CHECKS_PASSED + 1))
    else
        log_error "❌ Docker 서비스: 중지됨"
        CHECKS_FAILED=$((CHECKS_FAILED + 1))
    fi
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    
    # Docker 권한 확인
    if docker ps &> /dev/null; then
        log_success "✅ Docker 권한: 정상"
        CHECKS_PASSED=$((CHECKS_PASSED + 1))
    else
        log_warning "⚠️ Docker 권한: 사용자를 docker 그룹에 추가하세요"
        log_info "sudo usermod -aG docker $USER"
        CHECKS_FAILED=$((CHECKS_FAILED + 1))
    fi
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    
    # Docker 컨테이너 확인
    local container_count=$(docker ps -q | wc -l)
    log_info "실행 중인 컨테이너: $container_count개"
    
    echo ""
}

# 클라우드 계정 확인
check_cloud_accounts() {
    log_header "클라우드 계정 확인"
    
    # AWS 계정 확인
    if aws sts get-caller-identity &> /dev/null; then
        local aws_user=$(aws sts get-caller-identity --query 'Arn' --output text 2>/dev/null)
        log_success "✅ AWS 계정: $aws_user"
        CHECKS_PASSED=$((CHECKS_PASSED + 1))
    else
        log_error "❌ AWS 계정: 설정되지 않음"
        log_info "aws configure 실행하세요"
        CHECKS_FAILED=$((CHECKS_FAILED + 1))
    fi
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    
    # GCP 계정 확인
    if gcloud auth list --filter=status:ACTIVE --format="value(account)" &> /dev/null; then
        local gcp_user=$(gcloud auth list --filter=status:ACTIVE --format="value(account)" 2>/dev/null | head -1)
        log_success "✅ GCP 계정: $gcp_user"
        CHECKS_PASSED=$((CHECKS_PASSED + 1))
    else
        log_error "❌ GCP 계정: 설정되지 않음"
        log_info "gcloud auth login 실행하세요"
        CHECKS_FAILED=$((CHECKS_FAILED + 1))
    fi
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    
    echo ""
}

# 포트 사용 확인
check_ports() {
    log_header "포트 사용 확인"
    
    local ports=("9090" "9091" "3000" "3001" "3002" "16686" "16687" "9200" "9201" "5601" "5602")
    
    for port in "${ports[@]}"; do
        if netstat -tulpn 2>/dev/null | grep -q ":$port "; then
            local process=$(netstat -tulpn 2>/dev/null | grep ":$port " | awk '{print $7}' | cut -d'/' -f2)
            log_warning "⚠️ 포트 $port: 사용 중 ($process)"
        else
            log_success "✅ 포트 $port: 사용 가능"
        fi
    done
    
    echo ""
}

# 디스크 공간 확인
check_disk_space() {
    log_header "디스크 공간 확인"
    
    local available_space=$(df -h / | awk 'NR==2 {print $4}')
    local used_percent=$(df -h / | awk 'NR==2 {print $5}' | sed 's/%//')
    
    log_info "사용 가능한 공간: $available_space"
    log_info "사용률: ${used_percent}%"
    
    if [ "$used_percent" -lt 80 ]; then
        log_success "✅ 디스크 공간: 충분함"
        CHECKS_PASSED=$((CHECKS_PASSED + 1))
    else
        log_warning "⚠️ 디스크 공간: 부족할 수 있음"
        CHECKS_FAILED=$((CHECKS_FAILED + 1))
    fi
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    
    echo ""
}

# 메모리 확인
check_memory() {
    log_header "메모리 확인"
    
    local total_mem=$(free -h | awk 'NR==2{print $2}')
    local available_mem=$(free -h | awk 'NR==2{print $7}')
    local used_percent=$(free | awk 'NR==2{printf "%.0f", $3*100/$2}')
    
    log_info "총 메모리: $total_mem"
    log_info "사용 가능: $available_mem"
    log_info "사용률: ${used_percent}%"
    
    if [ "$used_percent" -lt 80 ]; then
        log_success "✅ 메모리: 충분함"
        CHECKS_PASSED=$((CHECKS_PASSED + 1))
    else
        log_warning "⚠️ 메모리: 부족할 수 있음"
        CHECKS_FAILED=$((CHECKS_FAILED + 1))
    fi
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    
    echo ""
}

# 실습 스크립트 확인
check_scripts() {
    log_header "실습 스크립트 확인"
    
    local scripts=("01-aws-loadbalancing.sh" "02-gcp-loadbalancing.sh" "03-monitoring-stack.sh" "04-autoscaling.sh" "05-cost-optimization.sh" "06-integration-test.sh")
    
    for script in "${scripts[@]}"; do
        if [ -f "$script" ] && [ -x "$script" ]; then
            log_success "✅ $script: 존재하고 실행 가능"
            CHECKS_PASSED=$((CHECKS_PASSED + 1))
        else
            log_error "❌ $script: 없거나 실행 불가능"
            CHECKS_FAILED=$((CHECKS_FAILED + 1))
        fi
        TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    done
    
    echo ""
}

# 결과 요약
print_summary() {
    log_header "환경 체크 결과 요약"
    
    local success_rate=$((CHECKS_PASSED * 100 / TOTAL_CHECKS))
    
    echo "총 체크 항목: $TOTAL_CHECKS"
    echo "통과: $CHECKS_PASSED"
    echo "실패: $CHECKS_FAILED"
    echo "성공률: ${success_rate}%"
    echo ""
    
    if [ "$success_rate" -ge 90 ]; then
        log_success "🎉 환경 체크 통과! 실습을 시작할 수 있습니다."
    elif [ "$success_rate" -ge 70 ]; then
        log_warning "⚠️ 환경 체크 부분 통과. 일부 문제를 해결한 후 실습을 시작하세요."
    else
        log_error "❌ 환경 체크 실패. 문제를 해결한 후 다시 실행하세요."
    fi
    
    echo ""
    log_info "다음 명령어로 실습을 시작하세요:"
    echo "  ./01-aws-loadbalancing.sh setup"
}

# 메인 실행
main() {
    log_header "Cloud Master Day3 환경 체크 시작"
    echo ""
    
    check_system_info
    check_prerequisites
    check_docker_status
    check_cloud_accounts
    check_ports
    check_disk_space
    check_memory
    check_scripts
    print_summary
}

# 스크립트 실행
main "$@"
