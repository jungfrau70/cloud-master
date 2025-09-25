#!/bin/bash

# Cloud Master Day 1 - Docker Practice Automation Script
# 작성자: Cloud Master Team
# 목적: Docker 기초 실습 자동화

set -e  # 오류 발생 시 스크립트 중단

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

# 실습 환경 확인
check_prerequisites() {
    log_info "실습 환경 확인 중..."
    
    # 통합 환경 체크 스크립트 실행
    if [ -f "../../cloud-scripts/environment-check.sh" ]; then
        log_info "통합 환경 체크 실행 중..."
        if bash ../../cloud-scripts/environment-check.sh; then
            log_success "환경 체크 완료"
        else
            log_warning "환경 체크에서 일부 문제가 발견되었습니다."
            log_warning "계속 진행하시겠습니까? (y/N)"
            read -r response
            if [[ ! "$response" =~ ^[Yy]$ ]]; then
                log_info "실습을 중단합니다."
                exit 0
            fi
        fi
    else
        # 기본 환경 체크 (fallback)
        log_info "기본 환경 체크 실행 중..."
        
        # Docker 설치 확인
        if ! command -v docker &> /dev/null; then
            log_error "Docker가 설치되지 않았습니다. 먼저 Docker를 설치해주세요."
            exit 1
        fi
        
        # Docker 서비스 실행 확인
        if ! docker info &> /dev/null; then
            log_error "Docker 서비스가 실행되지 않았습니다. Docker를 시작해주세요."
            exit 1
        fi
        
        log_success "Docker 환경 확인 완료"
    fi
}

# 1단계: Docker 설치 및 확인
step1_docker_installation() {
    log_info "=== 1단계: Docker 설치 및 확인 ==="
    
    # Docker 버전 확인
    log_info "Docker 버전 확인:"
    docker --version
    
    # Docker 정보 확인
    log_info "Docker 정보 확인:"
    docker info | head -20
    
    # Hello World 이미지 확인 및 실행
    log_info "Hello World 이미지 확인:"
    if docker images | grep -q "hello-world"; then
        log_info "Hello World 이미지가 이미 존재합니다."
    else
        log_info "Hello World 이미지 다운로드 중..."
        docker pull hello-world
    fi
    
    # Hello World 컨테이너 실행
    log_info "Hello World 컨테이너 실행:"
    docker run --rm hello-world
    
    log_success "1단계 완료: Docker 설치 및 확인"
}

# 2단계: 기본 명령어 실습
step2_basic_commands() {
    log_info "=== 2단계: 기본 명령어 실습 ==="
    
    # 이미지 목록 확인
    log_info "이미지 목록 확인:"
    docker images
    
    # 컨테이너 목록 확인
    log_info "실행 중인 컨테이너 확인:"
    docker ps
    
    # 모든 컨테이너 확인
    log_info "모든 컨테이너 확인:"
    docker ps -a
    
    # Nginx 이미지 확인 및 다운로드
    log_info "Nginx 이미지 확인:"
    if docker images | grep -q "nginx.*latest"; then
        log_info "Nginx 이미지가 이미 존재합니다."
    else
        log_info "Nginx 이미지 다운로드 중..."
        docker pull nginx:latest
    fi
    
    # 다운로드된 이미지 확인
    log_info "다운로드된 이미지 확인:"
    docker images | grep nginx
    
    log_success "2단계 완료: 기본 명령어 실습"
}

# 3단계: 웹 서버 컨테이너 실습
step3_web_server_practice() {
    log_info "=== 3단계: 웹 서버 컨테이너 실습 ==="
    
    # 기존 컨테이너 정리
    log_info "기존 컨테이너 정리:"
    if docker ps -a | grep -q "my-nginx"; then
        log_info "기존 my-nginx 컨테이너를 중지하고 삭제합니다."
        docker stop my-nginx 2>/dev/null || true
        docker rm my-nginx 2>/dev/null || true
    fi
    
    # Nginx 컨테이너 실행 (포트 매핑)
    log_info "Nginx 컨테이너 실행 (포트 8080):"
    docker run -d --name my-nginx -p 8080:80 nginx
    
    # 컨테이너 시작 대기
    log_info "컨테이너 시작 대기 (5초)..."
    sleep 5
    
    # 컨테이너 상태 확인
    log_info "컨테이너 상태 확인:"
    docker ps | grep my-nginx
    
    # 컨테이너 로그 확인
    log_info "컨테이너 로그 확인:"
    docker logs my-nginx | head -10
    
    # 컨테이너 내부 접속 (명령어 실행)
    log_info "컨테이너 내부 명령어 실행:"
    docker exec my-nginx ls -la /usr/share/nginx/html
    
    # 웹 서버 접속 테스트
    log_info "웹 서버 접속 테스트:"
    if command -v curl &> /dev/null; then
        curl -s http://localhost:8080 | head -5
    else
        log_warning "curl이 설치되지 않았습니다. 브라우저에서 http://localhost:8080 접속해보세요."
    fi
    
    log_success "3단계 완료: 웹 서버 컨테이너 실습"
}

# 4단계: 볼륨 마운트 실습
step4_volume_mount_practice() {
    log_info "=== 4단계: 볼륨 마운트 실습 ==="
    
    # 기존 컨테이너 정리
    log_info "기존 컨테이너 정리:"
    if docker ps -a | grep -q "nginx-volume"; then
        log_info "기존 nginx-volume 컨테이너를 중지하고 삭제합니다."
        docker stop nginx-volume 2>/dev/null || true
        docker rm nginx-volume 2>/dev/null || true
    fi
    
    # 호스트 디렉토리 생성
    log_info "호스트 디렉토리 생성:"
    mkdir -p ~/nginx-html
    echo "<h1>Hello from Docker Volume!</h1>" > ~/nginx-html/index.html
    echo "<p>This page is served from a Docker volume mount.</p>" >> ~/nginx-html/index.html
    
    # 볼륨 마운트로 Nginx 실행
    log_info "볼륨 마운트로 Nginx 실행 (포트 8081):"
    docker run -d --name nginx-volume \
        -p 8081:80 \
        -v ~/nginx-html:/usr/share/nginx/html \
        nginx
    
    # 컨테이너 시작 대기
    log_info "컨테이너 시작 대기 (5초)..."
    sleep 5
    
    # 컨테이너 상태 확인
    log_info "볼륨 마운트 컨테이너 상태 확인:"
    docker ps | grep nginx-volume
    
    # 볼륨 마운트 테스트
    log_info "볼륨 마운트 테스트:"
    if command -v curl &> /dev/null; then
        curl -s http://localhost:8081
    else
        log_warning "curl이 설치되지 않았습니다. 브라우저에서 http://localhost:8081 접속해보세요."
    fi
    
    log_success "4단계 완료: 볼륨 마운트 실습"
}

# 5단계: Dockerfile 실습
step5_dockerfile_practice() {
    log_info "=== 5단계: Dockerfile 실습 ==="
    
    # 기존 컨테이너 정리
    log_info "기존 컨테이너 정리:"
    if docker ps -a | grep -q "my-web-app"; then
        log_info "기존 my-web-app 컨테이너를 중지하고 삭제합니다."
        docker stop my-web-app 2>/dev/null || true
        docker rm my-web-app 2>/dev/null || true
    fi
    
    # 기존 이미지 정리
    if docker images | grep -q "my-web-app"; then
        log_info "기존 my-web-app 이미지를 삭제합니다."
        docker rmi my-web-app 2>/dev/null || true
    fi
    
    # 실습용 디렉토리 생성
    log_info "실습용 디렉토리 생성:"
    mkdir -p ~/docker-practice
    cd ~/docker-practice
    
    # 간단한 웹 애플리케이션 생성
    log_info "간단한 웹 애플리케이션 생성:"
    cat > index.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Docker Practice App</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; }
        .container { max-width: 600px; margin: 0 auto; }
        h1 { color: #333; }
        p { color: #666; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🐳 Docker Practice Application</h1>
        <p>This is a simple web application running in a Docker container!</p>
        <p>Built with Dockerfile automation.</p>
    </div>
</body>
</html>
EOF
    
    # Dockerfile 생성
    log_info "Dockerfile 생성:"
    cat > Dockerfile << 'EOF'
# 베이스 이미지
FROM nginx:alpine

# 작업 디렉토리 설정
WORKDIR /usr/share/nginx/html

# HTML 파일 복사
COPY index.html .

# 포트 노출
EXPOSE 80

# Nginx 실행 (기본 명령어)
CMD ["nginx", "-g", "daemon off;"]
EOF
    
    # Docker 이미지 빌드
    log_info "Docker 이미지 빌드:"
    docker build -t my-web-app .
    
    # 빌드된 이미지 확인
    log_info "빌드된 이미지 확인:"
    docker images | grep my-web-app
    
    # 컨테이너 실행
    log_info "컨테이너 실행 (포트 8082):"
    docker run -d --name my-web-app -p 8082:80 my-web-app
    
    # 컨테이너 상태 확인
    log_info "컨테이너 상태 확인:"
    docker ps | grep my-web-app
    
    # 웹 애플리케이션 테스트
    log_info "웹 애플리케이션 테스트:"
    if command -v curl &> /dev/null; then
        curl -s http://localhost:8082
    else
        log_warning "curl이 설치되지 않았습니다. 브라우저에서 http://localhost:8082 접속해보세요."
    fi
    
    log_success "5단계 완료: Dockerfile 실습"
}

# 6단계: GitHub Actions CI/CD 연계
step6_github_actions_integration() {
    log_info "=== 6단계: GitHub Actions CI/CD 연계 ==="
    
    # GitHub Actions 워크플로우 확인
    log_info "GitHub Actions 워크플로우 확인:"
    if [ -f "../../../cloud-scripts/.github/workflows/cloud-master-ci-cd.yml" ]; then
        log_success "GitHub Actions CI/CD 파이프라인을 찾았습니다."
        
        # 워크플로우 내용 확인
        log_info "CI/CD 파이프라인 기능:"
        echo "  - Docker 이미지 자동 빌드"
        echo "  - Docker Hub 자동 푸시"
        echo "  - AWS/GCP VM 자동 배포"
        echo "  - 헬스체크 및 알림"
        
        # GitHub Actions 실행 방법 안내
        log_info "GitHub Actions 실행 방법:"
        echo "  1. 코드를 GitHub에 푸시"
        echo "  2. GitHub Actions 탭에서 워크플로우 확인"
        echo "  3. 자동으로 Docker 이미지 빌드 및 배포"
        
    else
        log_warning "GitHub Actions 워크플로우를 찾을 수 없습니다."
        log_info "cloud-scripts 디렉토리에 .github/workflows/cloud-master-ci-cd.yml 파일이 있는지 확인하세요."
    fi
    
    # Docker 이미지를 GitHub Actions에서 사용할 수 있도록 준비
    log_info "GitHub Actions용 Docker 이미지 준비:"
    
    # MCP Cloud Master Day1 이미지로 태그 변경
    if docker images | grep -q "my-web-app"; then
        log_info "Docker 이미지를 GitHub Actions용으로 태그 변경:"
        docker tag my-web-app mcp-cloud-master-day1:latest
        log_success "이미지 태그 변경 완료: mcp-cloud-master-day1:latest"
    fi
    
    # Docker Hub 푸시 준비 안내
    log_info "Docker Hub 푸시 준비:"
    echo "  docker tag mcp-cloud-master-day1:latest YOUR_DOCKERHUB_USERNAME/mcp-cloud-master-day1:latest"
    echo "  docker push YOUR_DOCKERHUB_USERNAME/mcp-cloud-master-day1:latest"
    
    log_success "6단계 완료: GitHub Actions CI/CD 연계"
}

# 7단계: 정리 및 요약
step7_cleanup_and_summary() {
    log_info "=== 7단계: 정리 및 요약 ==="
    
    # 실행 중인 컨테이너 확인
    log_info "실행 중인 컨테이너 목록:"
    docker ps
    
    # 생성된 이미지 확인
    log_info "생성된 이미지 목록:"
    docker images
    
    # 정리 옵션 제공
    log_warning "실습 완료! 다음 명령어로 정리할 수 있습니다:"
    echo "  docker stop my-nginx nginx-volume my-web-app"
    echo "  docker rm my-nginx nginx-volume my-web-app"
    echo "  docker rmi my-web-app"
    
    # 실습 결과 요약
    log_success "=== Docker 실습 완료 ==="
    echo "✅ Docker 설치 및 확인"
    echo "✅ 기본 명령어 실습"
    echo "✅ 웹 서버 컨테이너 실행"
    echo "✅ 볼륨 마운트 실습"
    echo "✅ Dockerfile 빌드 실습"
    echo "✅ GitHub Actions CI/CD 연계"
    echo ""
    echo "🌐 접속 가능한 웹 서비스:"
    echo "  - Nginx 기본: http://localhost:8080"
    echo "  - 볼륨 마운트: http://localhost:8081"
    echo "  - 커스텀 앱: http://localhost:8082"
    echo ""
    echo "🚀 GitHub Actions CI/CD:"
    echo "  - Docker 이미지 자동 빌드"
    echo "  - Docker Hub 자동 푸시"
    echo "  - VM 자동 배포"
    echo "  - 헬스체크 및 알림"
}

# 메인 실행 함수
main() {
    log_info "Cloud Master Day 1 - Docker Practice Automation 시작"
    echo "=================================================="
    
    check_prerequisites
    step1_docker_installation
    step2_basic_commands
    step3_web_server_practice
    step4_volume_mount_practice
    step5_dockerfile_practice
    step6_github_actions_integration
    step7_cleanup_and_summary
    
    log_success "모든 Docker 실습이 완료되었습니다!"
}

# 스크립트 실행
main "$@"
