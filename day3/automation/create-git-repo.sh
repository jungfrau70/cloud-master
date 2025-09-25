#!/bin/bash

# Cloud Master Day3 Git Repository 생성 스크립트
# 작성일: 2024년 9월 23일
# 목적: WSL에서 실습 코드를 Git Repository로 생성하고 Cloud VM에서 사용할 수 있도록 설정

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

# 설정 변수
REPO_NAME="cloud-master-day3-practice"
GITHUB_USERNAME=""
WORKSPACE_DIR="/mnt/c/Users/$USER/Documents"

# 함수 정의
check_prerequisites() {
    log_header "사전 요구사항 확인"
    
    # Git 확인
    if ! command -v git &> /dev/null; then
        log_error "Git이 설치되지 않았습니다."
        exit 1
    fi
    
    # GitHub 사용자명 확인
    if [ -z "$GITHUB_USERNAME" ]; then
        log_warning "GitHub 사용자명이 설정되지 않았습니다."
        read -p "GitHub 사용자명을 입력하세요: " GITHUB_USERNAME
    fi
    
    log_success "사전 요구사항 확인 완료"
}

create_repository() {
    log_header "Git Repository 생성"
    
    # 작업 디렉토리로 이동
    cd "$WORKSPACE_DIR"
    
    # Repository 디렉토리 생성
    if [ -d "$REPO_NAME" ]; then
        log_warning "Repository 디렉토리가 이미 존재합니다."
        read -p "기존 디렉토리를 삭제하고 새로 생성하시겠습니까? (y/N): " confirm
        if [[ $confirm == [yY] ]]; then
            rm -rf "$REPO_NAME"
        else
            log_info "기존 디렉토리를 사용합니다."
            cd "$REPO_NAME"
            return
        fi
    fi
    
    # Repository 디렉토리 생성
    mkdir -p "$REPO_NAME"
    cd "$REPO_NAME"
    
    # Git 초기화
    git init
    git config user.name "Cloud Master Student"
    git config user.email "student@cloudmaster.com"
    
    log_success "Git Repository 초기화 완료"
}

copy_scripts() {
    log_header "실습 스크립트 복사"
    
    # 현재 스크립트 디렉토리 경로
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    
    # 실습 스크립트 복사
    log_info "실습 스크립트 복사 중..."
    cp "$SCRIPT_DIR"/*.sh ./
    
    # 실행 권한 부여
    chmod +x *.sh
    
    # README 파일 생성
    cat > README.md << 'EOF'
# Cloud Master Day3 Practice

이 Repository는 Cloud Master Day3 실습을 위한 자동화 스크립트들을 포함합니다.

## 📁 파일 구조

- `01-aws-loadbalancing.sh` - AWS 로드밸런싱 설정
- `02-gcp-loadbalancing.sh` - GCP 로드밸런싱 설정
- `03-monitoring-stack.sh` - 모니터링 스택 구축
- `04-autoscaling.sh` - 자동 스케일링 설정
- `05-cost-optimization.sh` - 비용 최적화 분석
- `06-integration-test.sh` - 통합 테스트 실행
- `vm-setup.sh` - VM 초기 설정 스크립트

## 🚀 사용법

### WSL에서 (개발 환경)
```bash
# Repository Clone
git clone https://github.com/[사용자명]/cloud-master-day3-practice.git
cd cloud-master-day3-practice

# 스크립트 수정 및 커밋
git add .
git commit -m "Update scripts"
git push origin main
```

### Cloud VM에서 (실습 환경)
```bash
# VM 설정
./vm-setup.sh

# 실습 실행
./01-aws-loadbalancing.sh setup
./02-gcp-loadbalancing.sh setup
./03-monitoring-stack.sh setup
./04-autoscaling.sh setup
./05-cost-optimization.sh analyze
./06-integration-test.sh setup
```

## ⚠️ 주의사항

- 실습 완료 후 반드시 리소스 정리를 수행하세요
- 비용 모니터링을 위해 정기적으로 리소스를 확인하세요
- AWS/GCP 계정 설정이 필요합니다
EOF
    
    log_success "실습 스크립트 복사 완료"
}

setup_gitignore() {
    log_header "Git 설정 파일 생성"
    
    # .gitignore 생성
    cat > .gitignore << 'EOF'
# 로그 파일
*.log
logs/

# 결과 파일
results/
output/

# 임시 파일
*.tmp
*.temp

# 백업 파일
*.backup
*.bak

# 환경 설정 파일
.env
.env.local
.env.production

# SSH 키
*.pem
*.key

# AWS 설정
.aws/

# GCP 설정
.gcloud/

# Docker 볼륨
docker-volumes/

# 모니터링 데이터
monitoring-stack/data/
prometheus-data/
grafana-data/
EOF
    
    log_success "Git 설정 파일 생성 완료"
}

create_github_repo() {
    log_header "GitHub Repository 생성"
    
    # GitHub CLI 확인
    if command -v gh &> /dev/null; then
        log_info "GitHub CLI를 사용하여 Repository 생성 중..."
        gh repo create "$REPO_NAME" --public --description "Cloud Master Day3 Practice Repository"
    else
        log_warning "GitHub CLI가 설치되지 않았습니다."
        log_info "수동으로 GitHub에서 Repository를 생성하세요:"
        log_info "https://github.com/new"
        log_info "Repository 이름: $REPO_NAME"
        log_info "설명: Cloud Master Day3 Practice Repository"
        log_info "공개/비공개: Public"
        
        read -p "GitHub Repository 생성이 완료되었습니까? (y/N): " confirm
        if [[ $confirm != [yY] ]]; then
            log_error "GitHub Repository 생성을 완료한 후 다시 실행하세요."
            exit 1
        fi
    fi
    
    # Remote 추가
    git remote add origin "https://github.com/$GITHUB_USERNAME/$REPO_NAME.git"
    
    log_success "GitHub Repository 설정 완료"
}

push_to_github() {
    log_header "GitHub에 Push"
    
    # 파일 추가
    git add .
    
    # 첫 번째 커밋
    git commit -m "Initial commit: Cloud Master Day3 practice automation scripts"
    
    # Main 브랜치로 설정
    git branch -M main
    
    # GitHub에 Push
    git push -u origin main
    
    log_success "GitHub Push 완료"
}

show_usage_instructions() {
    log_header "사용 방법 안내"
    
    echo -e "${GREEN}=== Repository 생성 완료 ===${NC}"
    echo ""
    echo -e "${BLUE}Repository 정보:${NC}"
    echo "  - 이름: $REPO_NAME"
    echo "  - URL: https://github.com/$GITHUB_USERNAME/$REPO_NAME"
    echo "  - 로컬 경로: $WORKSPACE_DIR/$REPO_NAME"
    echo ""
    echo -e "${BLUE}다음 단계:${NC}"
    echo ""
    echo "1. Cloud VM에서 Repository Clone:"
    echo "   git clone https://github.com/$GITHUB_USERNAME/$REPO_NAME.git"
    echo "   cd $REPO_NAME"
    echo ""
    echo "2. VM 초기 설정:"
    echo "   ./vm-setup.sh"
    echo ""
    echo "3. 실습 시작:"
    echo "   ./01-aws-loadbalancing.sh setup"
    echo ""
    echo -e "${YELLOW}주의사항:${NC}"
    echo "- VM에서 실습 전에 AWS/GCP 계정 설정이 필요합니다"
    echo "- 실습 완료 후 반드시 리소스 정리를 수행하세요"
    echo "- 코드 수정 시 Git을 통해 동기화하세요"
}

# 메인 실행
main() {
    log_header "Cloud Master Day3 Git Repository 생성 시작"
    
    # 사전 요구사항 확인
    check_prerequisites
    
    # Repository 생성
    create_repository
    
    # 스크립트 복사
    copy_scripts
    
    # Git 설정
    setup_gitignore
    
    # GitHub Repository 생성
    create_github_repo
    
    # GitHub에 Push
    push_to_github
    
    # 사용 방법 안내
    show_usage_instructions
    
    log_success "Git Repository 생성이 완료되었습니다!"
}

# 스크립트 실행
main "$@"
