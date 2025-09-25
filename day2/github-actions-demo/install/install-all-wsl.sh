#!/bin/bash

# MCP Cloud Master - WSL 환경 전체 설치 스크립트
# 이 스크립트는 WSL 환경에서 모든 필요한 도구를 설치합니다.

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

# 스크립트 디렉토리 확인
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
log_info "설치 스크립트 디렉토리: $SCRIPT_DIR"

# WSL 환경 확인
if [[ ! -f /proc/version ]] || ! grep -q Microsoft /proc/version; then
    log_warning "WSL 환경이 아닙니다. 이 스크립트는 WSL 환경에서 최적화되어 있습니다."
    read -p "계속 진행하시겠습니까? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

log_info "=== MCP Cloud Master 환경 설치 시작 ==="
log_info "설치 시간: $(date)"

# 1. 시스템 업데이트
log_info "시스템 패키지 업데이트 중..."
sudo apt update && sudo apt upgrade -y
log_success "시스템 업데이트 완료"

# 2. 필수 패키지 설치
log_info "필수 패키지 설치 중..."
sudo apt install -y \
    curl \
    wget \
    git \
    unzip \
    jq \
    htop \
    vim \
    nano \
    tree \
    build-essential \
    software-properties-common \
    apt-transport-https \
    ca-certificates \
    gnupg \
    lsb-release

log_success "필수 패키지 설치 완료"

# 3. AWS CLI v2 설치
log_info "AWS CLI v2 설치 중..."
if ! command -v aws &> /dev/null; then
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    unzip awscliv2.zip
    sudo ./aws/install
    rm -rf aws awscliv2.zip
    log_success "AWS CLI v2 설치 완료"
else
    log_info "AWS CLI가 이미 설치되어 있습니다: $(aws --version)"
fi

# 4. GCP CLI 설치
log_info "GCP CLI 설치 중..."
if ! command -v gcloud &> /dev/null; then
    echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | sudo tee -a /etc/apt/sources.list.d/google-cloud-sdk.list
    curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
    sudo apt update
    sudo apt install -y google-cloud-cli
    log_success "GCP CLI 설치 완료"
else
    log_info "GCP CLI가 이미 설치되어 있습니다: $(gcloud --version | head -1)"
fi

# 4-1. GKE 인증 플러그인 설치 시도
log_info "GKE 인증 플러그인 설치 시도 중..."
if gcloud components install gke-gcloud-auth-plugin --quiet 2>/dev/null; then
    log_success "GKE 인증 플러그인 설치 완료"
else
    log_warning "GKE 인증 플러그인 설치 실패 (권한 문제일 수 있음)"
    log_info "WSL 관리자 권한으로 설치가 필요할 수 있습니다."
fi

# 5. Docker 설치 (최신 버전을 사용자 bin에 직접 설치)
log_info "Docker 최신 버전 설치 중..."
if ! command -v docker &> /dev/null; then
    # Docker Desktop WSL2 통합 확인
    if [ -f "/mnt/c/Program Files/Docker/Docker/Docker Desktop.exe" ]; then
        log_info "Docker Desktop이 Windows에 설치되어 있습니다."
        log_warning "Docker Desktop의 WSL2 통합을 활성화해주세요:"
        echo "  1. Docker Desktop 실행"
        echo "  2. Settings → Resources → WSL Integration"
        echo "  3. 'Enable integration with my default WSL distro' 체크"
        echo "  4. 현재 WSL 배포판 활성화"
        echo "  5. Docker Desktop 재시작"
        echo ""
        log_info "WSL2 통합이 활성화되면 'docker --version'으로 확인하세요."
    else
        # WSL에서 Docker Engine 완전 설치
        log_info "Docker Engine을 WSL에 완전 설치 중..."
        
        # 1. Docker GPG 키 추가
        log_info "Docker GPG 키 추가 중..."
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
        
        # 2. Docker 저장소 추가
        log_info "Docker 저장소 추가 중..."
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
        
        # 3. 패키지 목록 업데이트
        log_info "패키지 목록 업데이트 중..."
        sudo apt update
        
        # 4. Docker 및 Docker Compose 설치 (Ubuntu 패키지)
        log_info "Docker 및 Docker Compose 설치 중..."
        sudo apt install -y docker.io docker-compose
        
        # 5. Docker Compose를 사용자 bin에 복사
        log_info "Docker Compose를 사용자 경로에 복사 중..."
        mkdir -p ~/.local/bin
        sudo cp /usr/bin/docker-compose ~/.local/bin/docker-compose
        sudo chown $USER:$USER ~/.local/bin/docker-compose
        chmod +x ~/.local/bin/docker-compose
        
        # 6. PATH에 ~/.local/bin 추가
        if ! echo "$PATH" | grep -q "$HOME/.local/bin"; then
            echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
            export PATH="$HOME/.local/bin:$PATH"
        fi
        
        # 7. Docker 서비스 시작 (WSL 환경)
        log_info "Docker 서비스 시작 중 (WSL 환경)..."
        # WSL에서는 systemctl 대신 직접 dockerd 실행
        sudo dockerd --host=unix:///var/run/docker.sock --host=tcp://0.0.0.0:2375 &
        sleep 5
        
        # 8. 사용자를 docker 그룹에 추가
        log_info "사용자를 docker 그룹에 추가 중..."
        sudo usermod -aG docker $USER
        
        # 9. Docker 데몬 상태 확인 (WSL 환경)
        log_info "Docker 데몬 상태 확인 중..."
        if pgrep dockerd > /dev/null; then
            log_success "Docker 데몬이 실행 중입니다."
        else
            log_warning "Docker 데몬 시작에 실패했습니다. 수동으로 시작해주세요: dockerd &"
        fi
        
        # 10. Docker 테스트
        log_info "Docker 설치 테스트 중..."
        if sudo docker --version > /dev/null 2>&1; then
            log_success "Docker Engine 설치 완료: $(sudo docker --version)"
        else
            log_error "Docker 설치에 실패했습니다."
        fi
        
        log_success "Docker Engine 설치 완료"
        log_warning "Docker 그룹 권한을 적용하려면 로그아웃 후 다시 로그인하거나 'newgrp docker'를 실행하세요."
        log_info "Docker 사용법: sudo docker run hello-world"
        log_info "WSL에서 Docker 시작: sudo dockerd &"
        log_info "Docker 중지: sudo pkill dockerd"
    fi
else
    log_info "Docker가 이미 설치되어 있습니다: $(sudo docker --version)"
fi

# 6. Docker Compose는 Docker 설치 시 함께 설치됨

# 7. kubectl 설치 (최신 버전을 사용자 bin에 직접 설치)
log_info "kubectl 최신 버전 설치 중..."
if ! command -v kubectl &> /dev/null; then
    # 사용자 bin 디렉토리 생성
    mkdir -p ~/.local/bin
    
    # 최신 kubectl 버전 다운로드
    KUBECTL_VERSION=$(curl -L -s https://dl.k8s.io/release/stable.txt)
    log_info "kubectl 버전: $KUBECTL_VERSION"
    
    # kubectl 다운로드
    curl -LO "https://dl.k8s.io/release/$KUBECTL_VERSION/bin/linux/amd64/kubectl"
    
    # kubectl을 사용자 bin에 설치
    chmod +x kubectl
    mv kubectl ~/.local/bin/
    
    # PATH에 ~/.local/bin 추가 (이미 추가되어 있을 수 있음)
    if ! echo "$PATH" | grep -q "$HOME/.local/bin"; then
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
        export PATH="$HOME/.local/bin:$PATH"
    fi
    
    # 설치 확인
    if command -v kubectl &> /dev/null; then
        log_success "kubectl 설치 완료: $(kubectl version --client)"
    else
        log_error "kubectl 설치에 실패했습니다."
    fi
else
    log_info "kubectl이 이미 설치되어 있습니다: $(kubectl version --client)"
fi

# 8. Terraform 설치
log_info "Terraform 설치 중..."
if ! command -v terraform &> /dev/null; then
    wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor | sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg
    echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
    sudo apt update
    sudo apt install -y terraform
    log_success "Terraform 설치 완료"
else
    log_info "Terraform이 이미 설치되어 있습니다: $(terraform --version | head -1)"
fi

# 9. Node.js 설치 (LTS 버전)
log_info "Node.js LTS 설치 중..."
if ! command -v node &> /dev/null; then
    curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
    sudo apt install -y nodejs
    log_success "Node.js 설치 완료"
else
    log_info "Node.js가 이미 설치되어 있습니다: $(node --version)"
fi

# 10. Python 3 및 pip 설치
log_info "Python 3 및 pip 설치 중..."
if ! command -v python3 &> /dev/null; then
    sudo apt install -y python3 python3-pip python3-venv
    log_success "Python 3 설치 완료"
else
    log_info "Python 3이 이미 설치되어 있습니다: $(python3 --version)"
fi

# 11. Helm 설치
log_info "Helm 설치 중..."
if ! command -v helm &> /dev/null; then
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
    log_success "Helm 설치 완료"
else
    log_info "Helm이 이미 설치되어 있습니다: $(helm version --short)"
fi

# 12. Git 설정 확인
log_info "Git 설정 확인 중..."
if [ -z "$(git config --global user.name)" ]; then
    log_warning "Git 사용자 이름이 설정되지 않았습니다."
    read -p "Git 사용자 이름을 입력하세요: " git_username
    git config --global user.name "$git_username"
fi

if [ -z "$(git config --global user.email)" ]; then
    log_warning "Git 이메일이 설정되지 않았습니다."
    read -p "Git 이메일을 입력하세요: " git_email
    git config --global user.email "$git_email"
fi

# 13. 작업 디렉토리 생성
log_info "작업 디렉토리 생성 중..."
mkdir -p ~/mcp-cloud-workspace
cd ~/mcp-cloud-workspace

# 14. 설치 완료 확인
log_info "=== 설치된 소프트웨어 버전 확인 ==="
echo "AWS CLI: $(aws --version 2>/dev/null || echo '설치되지 않음')"
echo "GCP CLI: $(gcloud --version 2>/dev/null | head -1 || echo '설치되지 않음')"

# GKE 인증 플러그인 확인
if command -v gke-gcloud-auth-plugin &> /dev/null; then
    echo "GKE Auth Plugin: $(gke-gcloud-auth-plugin --version 2>/dev/null || echo '설치됨 (버전 확인 불가)')"
else
    echo "GKE Auth Plugin: 설치되지 않음"
    log_warning "⚠️ GKE 인증 플러그인이 설치되지 않았습니다."
fi

# Docker 확인 (Docker Engine 설치 확인)
if command -v docker &> /dev/null; then
    echo "Docker: $(docker --version)"
    # Docker 데몬 상태 확인 (WSL 환경)
    if pgrep dockerd > /dev/null; then
        echo "Docker 데몬: 실행 중"
    else
        echo "Docker 데몬: 중지됨"
        log_warning "Docker 데몬이 실행되지 않았습니다. 'sudo dockerd &'를 실행하세요."
    fi
else
    echo "Docker: 설치되지 않음"
    log_warning "Docker가 설치되지 않았습니다. Docker Desktop WSL2 통합을 확인하거나 직접 설치하세요."
fi

# Docker Compose 확인 (사용자 bin에 설치된 버전)
if command -v docker-compose &> /dev/null; then
    echo "Docker Compose: $(docker-compose --version)"
else
    echo "Docker Compose: 설치되지 않음"
    log_warning "Docker Compose가 설치되지 않았습니다. Docker 설치 시 함께 설치됩니다."
fi

# kubectl 확인 (사용자 bin에 설치된 버전)
if command -v kubectl &> /dev/null; then
    echo "kubectl: $(kubectl version --client)"
else
    echo "kubectl: 설치되지 않음"
    log_warning "kubectl이 설치되지 않았습니다. 수동으로 설치하세요."
fi

echo "Terraform: $(terraform --version 2>/dev/null | head -1 || echo '설치되지 않음')"
echo "Node.js: $(node --version 2>/dev/null || echo '설치되지 않음')"
echo "Python: $(python3 --version 2>/dev/null || echo '설치되지 않음')"
echo "Helm: $(helm version --short 2>/dev/null || echo '설치되지 않음')"

# 15. 환경 설정 파일 생성
log_info "환경 설정 파일 생성 중..."
cat > ~/.mcp-cloud-env << EOF
# MCP Cloud Master 환경 설정
# 생성 시간: $(date)

export MCP_CLOUD_HOME="$HOME/mcp-cloud-workspace"
export PATH="\$MCP_CLOUD_HOME/bin:\$PATH"

# AWS 설정
export AWS_DEFAULT_REGION="ap-northeast-2"

# GCP 설정
export GOOGLE_CLOUD_PROJECT=""

# Docker 설정
export DOCKER_BUILDKIT=1
export COMPOSE_DOCKER_CLI_BUILD=1

# Kubernetes 설정
export KUBECONFIG="\$HOME/.kube/config"

# Terraform 설정
export TF_VAR_region="ap-northeast-2"

# 작업 디렉토리로 이동
cd "\$MCP_CLOUD_HOME"
EOF

# 16. WSL용 Docker 시작 스크립트 생성
log_info "WSL용 Docker 시작 스크립트 생성 중..."
cat > ~/.local/bin/start-docker << 'EOF'
#!/bin/bash
# WSL에서 Docker 시작 스크립트

echo "🐳 WSL에서 Docker 시작 중..."

# Docker 데몬이 이미 실행 중인지 확인
if pgrep dockerd > /dev/null; then
    echo "✅ Docker 데몬이 이미 실행 중입니다."
    docker --version
    exit 0
fi

# Docker 데몬 시작
echo "🚀 Docker 데몬 시작 중..."
sudo dockerd --host=unix:///var/run/docker.sock --host=tcp://0.0.0.0:2375 &

# Docker 데몬이 시작될 때까지 대기
echo "⏳ Docker 데몬 시작 대기 중..."
for i in {1..30}; do
    if pgrep dockerd > /dev/null; then
        echo "✅ Docker 데몬이 시작되었습니다."
        sudo docker --version
        echo "🎉 Docker 사용 준비 완료!"
        echo "💡 사용법: sudo docker run hello-world"
        exit 0
    fi
    sleep 1
done

echo "❌ Docker 데몬 시작에 실패했습니다."
echo "🔧 수동으로 시작: sudo dockerd &"
exit 1
EOF

chmod +x ~/.local/bin/start-docker
log_success "Docker 시작 스크립트 생성 완료: ~/.local/bin/start-docker"

# 17. Windows 디렉토리 심볼릭 링크 생성
log_info "Windows 디렉토리 심볼릭 링크 생성 중..."
create_mcp_link() {
    local windows_path="C:\\Users\\JIH\\githubs\\mcp_cloud\\mcp_knowledge_base"
    local wsl_path=$(wslpath "$windows_path")
    local link_name="mcp_knowledge_base"
    
    # Windows 경로가 존재하는지 확인
    if [ -d "$wsl_path" ]; then
        # 기존 링크가 있으면 제거
        if [ -L ~/$link_name ]; then
            rm ~/$link_name
            log_info "기존 심볼릭 링크를 제거했습니다."
        fi
        
        # 새 심볼릭 링크 생성
        ln -s "$wsl_path" ~/$link_name
        log_success "심볼릭 링크가 생성되었습니다: ~/$link_name -> $wsl_path"
        
        # 링크 테스트
        if [ -d ~/$link_name ]; then
            log_success "✅ 심볼릭 링크가 정상적으로 작동합니다."
        else
            log_error "❌ 심볼릭 링크 생성에 실패했습니다."
        fi
    else
        log_warning "❌ Windows 경로를 찾을 수 없습니다: $windows_path"
        log_info "경로를 확인하고 수동으로 심볼릭 링크를 생성하세요."
    fi
}

# 심볼릭 링크 생성 실행
create_mcp_link

# 18. .bashrc에 환경 설정 추가
if ! grep -q "MCP Cloud Master" ~/.bashrc; then
    echo "" >> ~/.bashrc
    echo "# MCP Cloud Master 환경 설정" >> ~/.bashrc
    echo "source ~/.mcp-cloud-env" >> ~/.bashrc
    log_success "환경 설정이 .bashrc에 추가되었습니다."
fi

# 19. MCP Knowledge Base 환경 변수 추가
if ! grep -q "MCP_KNOWLEDGE_BASE" ~/.bashrc; then
    echo 'export MCP_KNOWLEDGE_BASE="$HOME/mcp_knowledge_base"' >> ~/.bashrc
    echo 'export PATH="$MCP_KNOWLEDGE_BASE/cloud_master/repos/cloud-scripts:$PATH"' >> ~/.bashrc
    log_success "MCP Knowledge Base 환경 변수가 추가되었습니다."
fi

log_success "=== MCP Cloud Master 환경 설치 완료 ==="
log_info "설치 완료 시간: $(date)"
log_info "작업 디렉토리: ~/mcp-cloud-workspace"
log_info "MCP Knowledge Base: ~/mcp_knowledge_base (심볼릭 링크)"

# 설치 문제 해결 가이드
log_info "=== 설치 문제 해결 가이드 ==="
echo ""

# GKE 인증 플러그인 문제 해결 가이드
if ! command -v gke-gcloud-auth-plugin &> /dev/null; then
    echo "🔧 GKE 인증 플러그인 문제 해결:"
    echo "  ⚠️ GKE 인증 플러그인이 설치되지 않았습니다."
    echo "  📋 해결 방법:"
    echo "    1. WSL을 관리자 권한으로 실행:"
    echo "       - Windows 시작 메뉴에서 'Ubuntu' 또는 'WSL' 검색"
    echo "       - '관리자 권한으로 실행' 선택"
    echo "    2. Google Cloud SDK 업데이트:"
    echo "       sudo gcloud components update"
    echo "    3. GKE 인증 플러그인 설치:"
    echo "       sudo gcloud components install gke-gcloud-auth-plugin"
    echo "    4. PC 재시작 (권장):"
    echo "       - WSL 종료: wsl --shutdown"
    echo "       - PC 재시작"
    echo "    5. 설치 확인:"
    echo "       gke-gcloud-auth-plugin --version"
    echo "       kubectl get nodes"
    echo ""
    echo "  🔗 자동 수정 스크립트 사용:"
    echo "     cd ~/mcp_knowledge_base/cloud_master/repos/cloud-scripts"
    echo "     ./fix-gke-auth.sh"
    echo "     ./fix-cluster-issues.sh"
    echo ""
fi

echo "🔧 Docker 문제 해결:"
echo "  - Docker Desktop이 설치되어 있다면:"
echo "    1. Docker Desktop 실행"
echo "    2. Settings → Resources → WSL Integration"
echo "    3. 'Enable integration with my default WSL distro' 체크"
echo "    4. 현재 WSL 배포판 활성화"
echo "    5. Docker Desktop 재시작"
echo "  - WSL에 설치된 Docker Engine 사용:"
    echo "    start-docker  # 자동 시작 스크립트 사용 (sudo 필요)"
echo "    # 또는 수동으로:"
echo "    sudo dockerd &"
echo "    sudo usermod -aG docker \$USER"
echo "    newgrp docker"
echo "    sudo docker --version"
echo "    sudo docker run hello-world"
echo "    # Docker 중지: sudo pkill dockerd"
echo ""
echo "🔧 Docker Compose 문제 해결:"
echo "  - 사용자 bin에 설치된 Docker Compose 사용:"
echo "    ~/.local/bin/docker-compose --version"
echo "    export PATH=\"\$HOME/.local/bin:\$PATH\""
echo ""
echo "🔧 kubectl 문제 해결:"
echo "  - 사용자 bin에 설치된 kubectl 사용:"
echo "    ~/.local/bin/kubectl version --client"
echo "    export PATH=\"\$HOME/.local/bin:\$PATH\""
echo "  - 수동 재설치:"
echo "    curl -LO \"https://dl.k8s.io/release/\$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl\""
echo "    chmod +x kubectl"
echo "    mv kubectl ~/.local/bin/"
echo ""
echo "🔧 권한 문제 해결:"
echo "  - Docker 그룹 권한:"
echo "    usermod -aG docker \$USER"
echo "    newgrp docker"
echo "  - WSL 재시작:"
echo "    wsl --shutdown"
echo "    wsl"
echo ""
echo "🔗 심볼릭 링크 문제 해결:"
echo "  - Windows 경로 확인:"
echo "    ls -la /mnt/c/Users/JIH/githubs/mcp_cloud/"
echo "  - 심볼릭 링크 재생성:"
echo "    rm ~/mcp_knowledge_base"
echo "    ln -s /mnt/c/Users/JIH/githubs/mcp_cloud/mcp_knowledge_base ~/mcp_knowledge_base"
echo "  - 환경 변수 확인:"
echo "    echo \$MCP_KNOWLEDGE_BASE"
echo "    echo \$PATH"
echo ""

log_warning "새로운 터미널을 열거나 'source ~/.bashrc'를 실행하여 환경 설정을 적용하세요."

# GKE 인증 플러그인 설치 상태에 따른 다음 단계 안내
if ! command -v gke-gcloud-auth-plugin &> /dev/null; then
    log_warning "⚠️ 중요: GKE 인증 플러그인이 설치되지 않았습니다."
    log_info "다음 단계:"
    log_info "1. WSL을 관리자 권한으로 실행"
    log_info "2. sudo gcloud components install gke-gcloud-auth-plugin 실행"
    log_info "3. PC 재시작 후 클러스터 연결 테스트"
    log_info "4. AWS 및 GCP 인증 설정 진행"
else
    log_info "다음 단계: AWS 및 GCP 인증 설정을 진행하세요."
fi
