#!/bin/bash

# 🔐 인증 상태 확인 스크립트
# Docker Hub, GitHub, AWS, GCP 등의 인증 상태를 확인합니다

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

# 인증 상태 저장
AUTH_STATUS=0

# Docker Hub 인증 확인
check_docker_auth() {
    log_info "Docker Hub 인증 상태를 확인하는 중..."
    
    if docker info > /dev/null 2>&1; then
        # Docker가 실행 중인지 확인
        if docker system info > /dev/null 2>&1; then
            # Docker Hub 로그인 상태 확인
            if docker system info | grep -q "Username:"; then
                local username=$(docker system info | grep "Username:" | awk '{print $2}')
                log_success "Docker Hub 로그인됨: $username"
                return 0
            else
                log_warning "Docker Hub에 로그인되지 않음"
                log_info "다음 명령어로 로그인하세요: docker login"
                return 1
            fi
        else
            log_error "Docker가 실행되지 않음"
            return 1
        fi
    else
        log_error "Docker가 설치되지 않음"
        return 1
    fi
}

# GitHub 인증 확인
check_github_auth() {
    log_info "GitHub 인증 상태를 확인하는 중..."
    
    # GitHub CLI 확인
    if command -v gh &> /dev/null; then
        if gh auth status > /dev/null 2>&1; then
            local username=$(gh api user --jq '.login' 2>/dev/null || echo "unknown")
            log_success "GitHub CLI 로그인됨: $username"
            return 0
        else
            log_warning "GitHub CLI에 로그인되지 않음"
            log_info "다음 명령어로 로그인하세요: gh auth login"
            return 1
        fi
    else
        log_warning "GitHub CLI가 설치되지 않음"
        log_info "GitHub CLI 설치: https://cli.github.com/"
        return 1
    fi
}

# AWS 인증 확인
check_aws_auth() {
    log_info "AWS 인증 상태를 확인하는 중..."
    
    if command -v aws &> /dev/null; then
        if aws sts get-caller-identity > /dev/null 2>&1; then
            local account=$(aws sts get-caller-identity --query Account --output text 2>/dev/null || echo "unknown")
            local user=$(aws sts get-caller-identity --query Arn --output text 2>/dev/null | cut -d'/' -f2 || echo "unknown")
            log_success "AWS 인증됨: $user (Account: $account)"
            return 0
        else
            log_warning "AWS에 인증되지 않음"
            log_info "다음 명령어로 인증하세요: aws configure"
            return 1
        fi
    else
        log_warning "AWS CLI가 설치되지 않음"
        log_info "AWS CLI 설치: https://aws.amazon.com/cli/"
        return 1
    fi
}

# GCP 인증 확인
check_gcp_auth() {
    log_info "GCP 인증 상태를 확인하는 중..."
    
    if command -v gcloud &> /dev/null; then
        if gcloud auth list --filter=status:ACTIVE --format="value(account)" > /dev/null 2>&1; then
            local account=$(gcloud auth list --filter=status:ACTIVE --format="value(account)" | head -1)
            log_success "GCP 인증됨: $account"
            return 0
        else
            log_warning "GCP에 인증되지 않음"
            log_info "다음 명령어로 인증하세요: gcloud auth login"
            return 1
        fi
    else
        log_warning "GCP CLI가 설치되지 않음"
        log_info "GCP CLI 설치: https://cloud.google.com/sdk/docs/install"
        return 1
    fi
}

# 환경 변수 확인
check_env_vars() {
    log_info "필수 환경 변수를 확인하는 중..."
    
    local missing_vars=()
    local required_vars=(
        "DOCKER_USERNAME"
        "DOCKER_IMAGE_NAME"
        "GITHUB_USERNAME"
        "GITHUB_REPO_NAME"
    )
    
    # VM 배포 관련 환경 변수 확인
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
        return 1
    else
        log_success "필수 환경 변수 설정 완료"
        return 0
    fi
}

# 인증 가이드 표시
show_auth_guide() {
    log_info "인증 설정 가이드:"
    echo ""
    echo "1. Docker Hub 로그인:"
    echo "   docker login"
    echo ""
    echo "2. GitHub CLI 로그인:"
    echo "   gh auth login"
    echo ""
    echo "3. AWS CLI 설정:"
    echo "   aws configure"
    echo ""
    echo "4. GCP CLI 로그인:"
    echo "   gcloud auth login"
    echo ""
    echo "5. 환경 변수 설정:"
    echo "   .env 파일을 편집하여 필요한 값들을 설정하세요"
}

# 메인 실행
main() {
    log_info "🔐 인증 상태 확인을 시작합니다..."
    echo ""
    
    local total_checks=0
    local passed_checks=0
    
    # 환경 변수 확인
    total_checks=$((total_checks + 1))
    if check_env_vars; then
        passed_checks=$((passed_checks + 1))
    fi
    
    # Docker Hub 인증 확인
    total_checks=$((total_checks + 1))
    if check_docker_auth; then
        passed_checks=$((passed_checks + 1))
    fi
    
    # GitHub 인증 확인
    total_checks=$((total_checks + 1))
    if check_github_auth; then
        passed_checks=$((passed_checks + 1))
    fi
    
    # AWS 인증 확인 (선택사항)
    if [ "${CHECK_AWS:-true}" = "true" ]; then
        total_checks=$((total_checks + 1))
        if check_aws_auth; then
            passed_checks=$((passed_checks + 1))
        fi
    fi
    
    # GCP 인증 확인 (선택사항)
    if [ "${CHECK_GCP:-true}" = "true" ]; then
        total_checks=$((total_checks + 1))
        if check_gcp_auth; then
            passed_checks=$((passed_checks + 1))
        fi
    fi
    
    echo ""
    log_info "=== 인증 상태 요약 ==="
    log_info "통과: $passed_checks/$total_checks"
    
    if [ $passed_checks -eq $total_checks ]; then
        log_success "🎉 모든 인증이 완료되었습니다!"
        AUTH_STATUS=0
    elif [ $passed_checks -ge 2 ]; then
        log_warning "⚠️ 일부 인증이 누락되었지만 계속 진행할 수 있습니다."
        AUTH_STATUS=1
    else
        log_error "❌ 필수 인증이 누락되었습니다."
        show_auth_guide
        AUTH_STATUS=2
    fi
    
    return $AUTH_STATUS
}

# 스크립트가 직접 실행된 경우에만 main 함수 실행
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi
