#!/bin/bash

# Cloud Master Day3 VM 초기 설정 스크립트
# 작성일: 2024년 9월 23일
# 목적: Day3 실습을 위한 VM 환경 자동 설정

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
GIT_REPO_URL=""
VM_USER="ubuntu"

# 함수 정의
check_root() {
    if [[ $EUID -eq 0 ]]; then
        log_error "이 스크립트는 root 권한으로 실행하면 안됩니다."
        log_info "일반 사용자로 실행하세요: ./vm-setup.sh"
        exit 1
    fi
}

setup_system() {
    log_header "시스템 업데이트 및 기본 도구 설치"
    
    # 시스템 업데이트
    log_info "시스템 패키지 업데이트 중..."
    sudo apt update && sudo apt upgrade -y
    
    # 필수 도구 설치
    log_info "필수 도구 설치 중..."
    sudo apt install -y git curl wget jq unzip htop tree vim nano
    
    log_success "시스템 설정 완료"
}

install_docker() {
    log_header "Docker 설치"
    
    # Docker 설치
    log_info "Docker 설치 중..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    sudo usermod -aG docker $USER
    
    # Docker Compose 설치
    log_info "Docker Compose 설치 중..."
    sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
    
    # Docker 서비스 시작
    sudo systemctl start docker
    sudo systemctl enable docker
    
    log_success "Docker 설치 완료"
}

install_aws_cli() {
    log_header "AWS CLI 설치"
    
    # AWS CLI v2 설치
    log_info "AWS CLI v2 설치 중..."
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    unzip awscliv2.zip
    sudo ./aws/install
    
    # 설치 파일 정리
    rm -rf aws awscliv2.zip
    
    log_success "AWS CLI 설치 완료"
}

install_gcp_cli() {
    log_header "GCP CLI 설치"
    
    # GCP CLI 설치
    log_info "GCP CLI 설치 중..."
    curl https://sdk.cloud.google.com | bash
    echo 'source ~/google-cloud-sdk/path.bash.inc' >> ~/.bashrc
    echo 'source ~/google-cloud-sdk/completion.bash.inc' >> ~/.bashrc
    
    log_success "GCP CLI 설치 완료"
    log_warning "새 터미널을 열거나 'source ~/.bashrc'를 실행하세요"
}

setup_ssh() {
    log_header "SSH 설정"
    
    # SSH 디렉토리 생성
    mkdir -p ~/.ssh
    chmod 700 ~/.ssh
    
    # SSH 키 생성 (없는 경우)
    if [ ! -f ~/.ssh/id_rsa ]; then
        log_info "SSH 키 생성 중..."
        ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N ""
    fi
    
    log_success "SSH 설정 완료"
}

clone_repository() {
    log_header "실습 코드 Repository Clone"
    
    if [ -z "$GIT_REPO_URL" ]; then
        log_warning "Git Repository URL이 설정되지 않았습니다."
        log_info "다음 명령어로 수동으로 Clone하세요:"
        log_info "git clone https://github.com/[사용자명]/cloud-master-day3-practice.git"
        return
    fi
    
    # Repository Clone
    log_info "Repository Clone 중..."
    git clone "$GIT_REPO_URL" cloud-master-day3-practice
    cd cloud-master-day3-practice
    
    # 실행 권한 부여
    chmod +x *.sh
    
    log_success "Repository Clone 완료"
}

create_workspace() {
    log_header "작업 공간 설정"
    
    # 작업 디렉토리 생성
    mkdir -p ~/cloud-master-workspace/{logs,results,backups}
    
    # 환경 변수 설정
    cat >> ~/.bashrc << 'EOF'

# Cloud Master Day3 환경 변수
export CLOUD_MASTER_WORKSPACE=~/cloud-master-workspace
export CLOUD_MASTER_LOGS=~/cloud-master-workspace/logs
export CLOUD_MASTER_RESULTS=~/cloud-master-workspace/results

# 편의 함수
alias cmlogs='tail -f $CLOUD_MASTER_LOGS/*.log'
alias cmresults='ls -la $CLOUD_MASTER_RESULTS/'
alias cmstatus='docker ps && echo "---" && aws sts get-caller-identity 2>/dev/null && echo "---" && gcloud auth list 2>/dev/null'
EOF
    
    log_success "작업 공간 설정 완료"
}

show_next_steps() {
    log_header "다음 단계 안내"
    
    echo -e "${GREEN}=== VM 설정 완료 ===${NC}"
    echo ""
    echo -e "${BLUE}다음 명령어로 실습을 시작하세요:${NC}"
    echo ""
    echo "1. 새 터미널 열기 또는 환경 변수 로드:"
    echo "   source ~/.bashrc"
    echo ""
    echo "2. 실습 코드 디렉토리로 이동:"
    echo "   cd cloud-master-day3-practice"
    echo ""
    echo "3. AWS CLI 설정:"
    echo "   aws configure"
    echo ""
    echo "4. GCP CLI 설정:"
    echo "   gcloud auth login"
    echo "   gcloud config set project [PROJECT_ID]"
    echo ""
    echo "5. 실습 시작:"
    echo "   ./01-aws-loadbalancing.sh setup"
    echo ""
    echo -e "${YELLOW}주의사항:${NC}"
    echo "- AWS/GCP 계정 설정이 필요합니다"
    echo "- 실습 완료 후 리소스 정리를 잊지 마세요"
    echo "- 비용 모니터링을 위해 정기적으로 리소스를 확인하세요"
}

# 메인 실행
main() {
    log_header "Cloud Master Day3 VM 설정 시작"
    
    # 사전 체크
    check_root
    
    # 시스템 설정
    setup_system
    
    # Docker 설치
    install_docker
    
    # AWS CLI 설치
    install_aws_cli
    
    # GCP CLI 설치
    install_gcp_cli
    
    # SSH 설정
    setup_ssh
    
    # Repository Clone
    clone_repository
    
    # 작업 공간 설정
    create_workspace
    
    # 다음 단계 안내
    show_next_steps
    
    log_success "VM 설정이 완료되었습니다!"
}

# 스크립트 실행
main "$@"
