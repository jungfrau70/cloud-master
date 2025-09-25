#!/bin/bash

# 디버그 메뉴 스크립트
# 입력 처리 테스트

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

# 간단한 메뉴 테스트
test_menu() {
    while true; do
        echo ""
        echo "=== 테스트 메뉴 ==="
        echo "1. 옵션 1"
        echo "2. 옵션 2"
        echo "3. 종료"
        echo ""
        echo -n "선택 (1-3): "
        
        if ! read -r choice; then
            log_error "입력 읽기 실패"
            continue
        fi
        
        echo "입력된 값: '$choice'"
        echo "길이: ${#choice}"
        
        case $choice in
            1)
                log_success "옵션 1 선택됨"
                ;;
            2)
                log_success "옵션 2 선택됨"
                ;;
            3)
                log_info "종료합니다."
                break
                ;;
            "")
                log_error "빈 입력"
                ;;
            *)
                log_error "잘못된 선택: '$choice'"
                ;;
        esac
    done
}

echo "=== 디버그 메뉴 테스트 ==="
test_menu
