#!/bin/bash

# 🧪 Day1 기본 테스트 스크립트
# GitHub Actions CI/CD Practice - Day1 Basic Testing

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

# 설정
APP_URL="http://localhost:3000"

echo -e "${PURPLE}🧪 Day1 기본 테스트 시작${NC}"
echo "================================================"

# 테스트 결과 저장
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# 테스트 함수
run_test() {
    local test_name="$1"
    local test_command="$2"
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    log_info "테스트 실행: $test_name"
    
    if eval "$test_command" > /dev/null 2>&1; then
        log_success "✅ $test_name - 통과"
        PASSED_TESTS=$((PASSED_TESTS + 1))
        return 0
    else
        log_error "❌ $test_name - 실패"
        FAILED_TESTS=$((FAILED_TESTS + 1))
        return 1
    fi
}

# 1. 기본 환경 확인
echo -e "${BLUE}🔧 기본 환경 확인${NC}"
echo "----------------------------------------"

run_test "Node.js 설치 확인" "node --version"
run_test "NPM 설치 확인" "npm --version"
run_test "Docker 설치 확인" "docker --version"
run_test "Git 설치 확인" "git --version"

# 2. 프로젝트 구조 확인
echo -e "${BLUE}📁 프로젝트 구조 확인${NC}"
echo "----------------------------------------"

run_test "package.json 존재 확인" "test -f package.json"
run_test "src 디렉토리 존재 확인" "test -d src"
run_test "Dockerfile 존재 확인" "test -f Dockerfile"
run_test "GitHub Actions 워크플로우 확인" "test -d .github/workflows"

# 3. 의존성 설치 확인
echo -e "${BLUE}📦 의존성 설치 확인${NC}"
echo "----------------------------------------"

run_test "node_modules 디렉토리 확인" "test -d node_modules"
run_test "Express.js 설치 확인" "npm list express"
run_test "Jest 설치 확인" "npm list jest"

# 4. 웹 애플리케이션 테스트
echo -e "${BLUE}📱 웹 애플리케이션 테스트${NC}"
echo "----------------------------------------"

# 애플리케이션 시작
log_info "애플리케이션 시작 중..."
if [ -f "src/app.day1.js" ]; then
    node src/app.day1.js &
    APP_PID=$!
    sleep 3
    
    run_test "애플리케이션 실행 확인" "curl -s $APP_URL/health"
    run_test "홈페이지 응답 확인" "curl -s $APP_URL/"
    run_test "API 상태 확인" "curl -s $APP_URL/api/status"
    
    # 애플리케이션 종료
    kill $APP_PID 2>/dev/null
else
    log_warning "app.day1.js 파일이 없습니다. 기본 app.js를 사용합니다."
    if [ -f "src/app.js" ]; then
        node src/app.js &
        APP_PID=$!
        sleep 3
        
        run_test "애플리케이션 실행 확인" "curl -s $APP_URL/health"
        run_test "홈페이지 응답 확인" "curl -s $APP_URL/"
        
        # 애플리케이션 종료
        kill $APP_PID 2>/dev/null
    else
        log_error "애플리케이션 파일을 찾을 수 없습니다."
        FAILED_TESTS=$((FAILED_TESTS + 3))
        TOTAL_TESTS=$((TOTAL_TESTS + 3))
    fi
fi

# 5. Docker 테스트
echo -e "${BLUE}🐳 Docker 테스트${NC}"
echo "----------------------------------------"

run_test "Docker 이미지 빌드 테스트" "docker build -t github-actions-demo:test ."
run_test "Docker 이미지 실행 테스트" "docker run -d -p 3001:3000 --name test-container github-actions-demo:test"

# Docker 컨테이너 테스트
if docker ps | grep -q test-container; then
    sleep 3
    run_test "Docker 컨테이너 응답 확인" "curl -s http://localhost:3001/health"
    
    # 테스트 컨테이너 정리
    docker stop test-container
    docker rm test-container
fi

# 6. 테스트 실행
echo -e "${BLUE}🧪 테스트 실행${NC}"
echo "----------------------------------------"

run_test "NPM 테스트 실행" "npm test"

# 7. Git 상태 확인
echo -e "${BLUE}📝 Git 상태 확인${NC}"
echo "----------------------------------------"

run_test "Git 저장소 확인" "git status"
run_test "브랜치 확인" "git branch"

# 8. 테스트 결과 요약
echo ""
echo "================================================"
echo -e "${PURPLE}📊 Day1 기본 테스트 결과 요약${NC}"
echo "================================================"
echo "총 테스트 수: $TOTAL_TESTS"
echo "통과한 테스트: $PASSED_TESTS"
echo "실패한 테스트: $FAILED_TESTS"

# 성공률 계산
if [ $TOTAL_TESTS -gt 0 ]; then
    success_rate=$((PASSED_TESTS * 100 / TOTAL_TESTS))
    echo "성공률: ${success_rate}%"
    
    if [ $success_rate -ge 90 ]; then
        log_success "🎉 우수한 테스트 결과입니다!"
    elif [ $success_rate -ge 70 ]; then
        log_warning "⚠️ 양호한 테스트 결과입니다. 일부 개선이 필요합니다."
    else
        log_error "❌ 테스트 결과가 좋지 않습니다. 문제를 해결해야 합니다."
    fi
fi

echo ""
echo "테스트 완료 시간: $(date)"

# 9. Day1 완료 체크리스트
echo ""
echo -e "${YELLOW}📋 Day1 완료 체크리스트${NC}"
echo "----------------------------------------"

if [ $PASSED_TESTS -eq $TOTAL_TESTS ]; then
    echo "✅ 모든 기본 테스트 통과"
    echo "✅ 개발 환경 설정 완료"
    echo "✅ Docker 기본 사용법 습득"
    echo "✅ GitHub Actions 워크플로우 이해"
    echo "✅ 기본 CI/CD 파이프라인 구축"
    
    log_success "🎉 Day1 기본 과정을 성공적으로 완료했습니다!"
    echo ""
    echo "다음 단계: Day2 Advanced 과정으로 진행하세요."
    echo "  git checkout day2-advanced"
else
    echo "❌ 일부 테스트가 실패했습니다."
    echo "위의 오류 메시지를 확인하고 문제를 해결한 후 다시 테스트하세요."
fi

# 종료 코드 설정
if [ $FAILED_TESTS -eq 0 ]; then
    exit 0
else
    exit 1
fi
