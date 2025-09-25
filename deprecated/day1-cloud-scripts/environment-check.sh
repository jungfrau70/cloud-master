#!/bin/bash

# 통합 환경 체크 스크립트
# Cloud Master 과정용 환경 검증 도구

set -e  # 오류 발생 시 스크립트 종료

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# 로그 함수
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_header() {
    echo -e "${PURPLE}[HEADER]${NC} $1"
}

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

# AWS CLI 체크
check_aws_cli() {
    log_header "=== AWS CLI 환경 체크 ==="
    
    check_command "AWS CLI" "aws --version" "aws-cli"
    
    if command -v aws &> /dev/null; then
        log_info "AWS 자격증명 확인 중..."
        if aws sts get-caller-identity &> /dev/null; then
            log_success "✅ AWS 자격증명: 설정됨"
            CHECKS_PASSED=$((CHECKS_PASSED + 1))
        else
            log_error "❌ AWS 자격증명: 설정되지 않음"
            log_warning "다음 명령어로 설정하세요: aws configure"
            CHECKS_FAILED=$((CHECKS_FAILED + 1))
        fi
        TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    fi
}

# GCP CLI 체크
check_gcp_cli() {
    log_header "=== GCP CLI 환경 체크 ==="
    
    check_command "gcloud CLI" "gcloud --version" "Google Cloud SDK"
    
    if command -v gcloud &> /dev/null; then
        log_info "GCP 인증 확인 중..."
        if gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q .; then
            log_success "✅ GCP 인증: 설정됨"
            CHECKS_PASSED=$((CHECKS_PASSED + 1))
        else
            log_error "❌ GCP 인증: 설정되지 않음"
            log_warning "다음 명령어로 설정하세요: gcloud auth login"
            CHECKS_FAILED=$((CHECKS_FAILED + 1))
        fi
        TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    fi
}

# Docker 체크
check_docker() {
    log_header "=== Docker 환경 체크 ==="
    
    check_command "Docker" "docker --version" "Docker version"
    check_command "Docker Compose" "docker-compose --version" "docker-compose version"
    
    if command -v docker &> /dev/null; then
        log_info "Docker 서비스 상태 확인 중..."
        if docker info &> /dev/null; then
            log_success "✅ Docker 서비스: 실행 중"
            CHECKS_PASSED=$((CHECKS_PASSED + 1))
        else
            log_error "❌ Docker 서비스: 실행되지 않음"
            log_warning "Docker Desktop을 시작하거나 Docker 서비스를 시작하세요"
            CHECKS_FAILED=$((CHECKS_FAILED + 1))
        fi
        TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    fi
}

# Git 체크
check_git() {
    log_header "=== Git 환경 체크 ==="
    
    check_command "Git" "git --version" "git version"
    
    if command -v git &> /dev/null; then
        log_info "Git 설정 확인 중..."
        if git config --global user.name &> /dev/null && git config --global user.email &> /dev/null; then
            log_success "✅ Git 설정: 완료됨"
            log_info "  사용자명: $(git config --global user.name)"
            log_info "  이메일: $(git config --global user.email)"
            CHECKS_PASSED=$((CHECKS_PASSED + 1))
        else
            log_warning "⚠️ Git 설정: 사용자 정보가 설정되지 않음"
            log_warning "다음 명령어로 설정하세요:"
            log_warning "  git config --global user.name 'Your Name'"
            log_warning "  git config --global user.email 'your.email@example.com'"
            CHECKS_FAILED=$((CHECKS_FAILED + 1))
        fi
        TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    fi
}

# Kubernetes 체크 (Day2, Day3용)
check_kubernetes() {
    log_header "=== Kubernetes 환경 체크 ==="
    
    check_command "kubectl" "kubectl version --client" "Client Version"
    
    if command -v kubectl &> /dev/null; then
        log_info "Kubernetes 클러스터 연결 확인 중..."
        if kubectl cluster-info &> /dev/null; then
            log_success "✅ Kubernetes 클러스터: 연결됨"
            CHECKS_PASSED=$((CHECKS_PASSED + 1))
        else
            log_warning "⚠️ Kubernetes 클러스터: 연결되지 않음"
            log_warning "minikube start 또는 kind create cluster를 실행하세요"
            CHECKS_FAILED=$((CHECKS_FAILED + 1))
        fi
        TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    fi
}

# 시스템 리소스 체크
check_system_resources() {
    log_header "=== 시스템 리소스 체크 ==="
    
    # 메모리 체크
    if command -v free &> /dev/null; then
        local available_memory=$(free -m | awk 'NR==2{printf "%.0f", $7}')
        if [ "$available_memory" -gt 2048 ]; then
            log_success "✅ 사용 가능한 메모리: ${available_memory}MB"
            CHECKS_PASSED=$((CHECKS_PASSED + 1))
        else
            log_warning "⚠️ 사용 가능한 메모리: ${available_memory}MB (권장: 2GB 이상)"
            CHECKS_FAILED=$((CHECKS_FAILED + 1))
        fi
        TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    fi
    
    # 디스크 공간 체크
    local available_space=$(df -BG . | awk 'NR==2{print $4}' | sed 's/G//')
    if [ "$available_space" -gt 10 ]; then
        log_success "✅ 사용 가능한 디스크 공간: ${available_space}GB"
        CHECKS_PASSED=$((CHECKS_PASSED + 1))
    else
        log_warning "⚠️ 사용 가능한 디스크 공간: ${available_space}GB (권장: 10GB 이상)"
        CHECKS_FAILED=$((CHECKS_FAILED + 1))
    fi
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
}

# 결과 요약
print_summary() {
    log_header "=== 환경 체크 결과 요약 ==="
    
    echo ""
    echo "📊 체크 결과:"
    echo "  ✅ 통과: $CHECKS_PASSED"
    echo "  ❌ 실패: $CHECKS_FAILED"
    echo "  📋 전체: $TOTAL_CHECKS"
    echo ""
    
    local success_rate=$((CHECKS_PASSED * 100 / TOTAL_CHECKS))
    
    if [ "$success_rate" -ge 90 ]; then
        log_success "🎉 환경 체크 통과! (${success_rate}%)"
        echo ""
        log_info "실습을 시작할 준비가 완료되었습니다!"
    elif [ "$success_rate" -ge 70 ]; then
        log_warning "⚠️ 환경 체크 부분 통과 (${success_rate}%)"
        echo ""
        log_warning "일부 실습에 제한이 있을 수 있습니다."
        log_warning "실패한 항목을 수정한 후 다시 실행하세요."
    else
        log_error "❌ 환경 체크 실패 (${success_rate}%)"
        echo ""
        log_error "실습을 시작하기 전에 실패한 항목을 수정해야 합니다."
        log_error "설치 가이드를 참고하여 환경을 설정하세요."
    fi
    
    echo ""
    log_info "📚 설치 가이드:"
    log_info "  - AWS CLI: /mcp_knowledge_base/cloud_master/textbook/Day1/guides/install_aws_cli.md"
    log_info "  - GCP CLI: /mcp_knowledge_base/cloud_master/textbook/Day1/guides/install_glcoud_cli.md"
    log_info "  - Docker: /mcp_knowledge_base/cloud_master/textbook/Day1/guides/install_docker.md"
    log_info "  - Git: /mcp_knowledge_base/cloud_master/textbook/Day1/guides/install_git.md"
}

# 메인 실행
main() {
    log_header "🚀 Cloud Master 환경 체크 시작"
    echo ""
    
    # 기본 도구 체크
    check_docker
    check_git
    check_aws_cli
    check_gcp_cli
    
    # Day별 추가 체크
    if [ "$1" = "day2" ] || [ "$1" = "day3" ]; then
        check_kubernetes
    fi
    
    # 시스템 리소스 체크
    check_system_resources
    
    # 결과 요약
    print_summary
}

# 스크립트 실행
main "$@"
