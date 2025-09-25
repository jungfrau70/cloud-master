#!/bin/bash

# 입력 테스트 스크립트
# WSL 환경에서 read 명령어 테스트

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 로그 함수
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# 안전한 입력 읽기 함수
safe_read() {
    local prompt="$1"
    local timeout="${2:-30}"
    local response=""
    
    echo -n "$prompt"
    
    # 타임아웃과 함께 입력 읽기
    if read -t "$timeout" -r response 2>/dev/null; then
        echo "$response"
        return 0
    else
        echo ""
        log_error "입력 시간 초과 또는 읽기 실패"
        return 1
    fi
}

echo "=== 입력 테스트 스크립트 ==="
echo ""

# 테스트 1: 기본 read
log_info "테스트 1: 기본 read 명령어"
echo -n "이름을 입력하세요: "
if read -r name; then
    log_success "입력 성공: $name"
else
    log_error "입력 실패"
fi

echo ""

# 테스트 2: safe_read 함수
log_info "테스트 2: safe_read 함수"
if name=$(safe_read "이름을 입력하세요 (30초 타임아웃): "); then
    log_success "입력 성공: $name"
else
    log_error "입력 실패"
fi

echo ""

# 테스트 3: 메뉴 선택
log_info "테스트 3: 메뉴 선택"
echo "1. 옵션 1"
echo "2. 옵션 2"
echo "3. 옵션 3"
if choice=$(safe_read "선택 (1-3): "); then
    log_success "선택된 옵션: $choice"
else
    log_error "선택 실패"
fi

echo ""
log_success "테스트 완료!"
