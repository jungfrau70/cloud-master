#!/bin/bash

# 개발 도구 설치 스크립트 (WSL 환경용)
# Node.js, Python, Terraform, Git 등 개발에 필요한 도구들을 설치합니다.

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 로그 함수
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

log_info "=== 개발 도구 설치 시작 ==="

# 1. 시스템 업데이트
log_info "시스템 패키지 업데이트 중..."
sudo apt update
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

# 2. Node.js 설치 (LTS 버전)
log_info "Node.js LTS 설치 중..."
if ! command -v node &> /dev/null; then
    curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
    sudo apt install -y nodejs
    log_success "Node.js 설치 완료"
else
    log_info "Node.js가 이미 설치되어 있습니다: $(node --version)"
fi

# 3. Python 3 및 pip 설치
log_info "Python 3 및 pip 설치 중..."
if ! command -v python3 &> /dev/null; then
    sudo apt install -y python3 python3-pip python3-venv python3-dev
    log_success "Python 3 설치 완료"
else
    log_info "Python 3이 이미 설치되어 있습니다: $(python3 --version)"
fi

# 4. Terraform 설치
log_info "Terraform 설치 중..."
if ! command -v terraform &> /dev/null; then
    # HashiCorp GPG 키 추가
    wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor | sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg
    echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
    
    # Terraform 설치
    sudo apt update
    sudo apt install -y terraform
    log_success "Terraform 설치 완료"
else
    log_info "Terraform이 이미 설치되어 있습니다: $(terraform --version | head -1)"
fi

# 5. Go 설치
log_info "Go 설치 중..."
if ! command -v go &> /dev/null; then
    # Go 최신 버전 다운로드
    GO_VERSION=$(curl -s https://golang.org/VERSION?m=text)
    wget https://golang.org/dl/$GO_VERSION.linux-amd64.tar.gz
    
    # Go 설치
    sudo tar -C /usr/local -xzf $GO_VERSION.linux-amd64.tar.gz
    rm $GO_VERSION.linux-amd64.tar.gz
    
    # PATH에 Go 추가
    echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.bashrc
    export PATH=$PATH:/usr/local/go/bin
    
    log_success "Go 설치 완료"
else
    log_info "Go가 이미 설치되어 있습니다: $(go version)"
fi

# 6. Rust 설치
log_info "Rust 설치 중..."
if ! command -v rustc &> /dev/null; then
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    source ~/.cargo/env
    log_success "Rust 설치 완료"
else
    log_info "Rust가 이미 설치되어 있습니다: $(rustc --version)"
fi

# 7. Git 설정 확인 및 안내
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

# 8. VS Code Server 설치 (선택사항)
log_info "VS Code Server 설치 중..."
if ! command -v code-server &> /dev/null; then
    read -p "VS Code Server를 설치하시겠습니까? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        # VS Code Server 최신 버전 다운로드
        VSCODE_VERSION=$(curl -s https://api.github.com/repos/coder/code-server/releases/latest | grep tag_name | cut -d '"' -f 4)
        wget https://github.com/coder/code-server/releases/download/$VSCODE_VERSION/code-server-${VSCODE_VERSION#v}-linux-amd64.tar.gz
        
        # VS Code Server 설치
        tar -xzf code-server-${VSCODE_VERSION#v}-linux-amd64.tar.gz
        sudo mv code-server-${VSCODE_VERSION#v}-linux-amd64 /opt/code-server
        sudo ln -s /opt/code-server/bin/code-server /usr/local/bin/code-server
        rm -rf code-server-${VSCODE_VERSION#v}-linux-amd64.tar.gz
        
        log_success "VS Code Server 설치 완료"
        log_info "VS Code Server 시작: code-server"
    fi
else
    log_info "VS Code Server가 이미 설치되어 있습니다: $(code-server --version)"
fi

# 9. Docker Compose 설치 (별도)
log_info "Docker Compose 설치 중..."
if ! command -v docker-compose &> /dev/null; then
    sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
    log_success "Docker Compose 설치 완료"
else
    log_info "Docker Compose가 이미 설치되어 있습니다: $(docker-compose --version)"
fi

# 10. 설치 확인
log_info "=== 설치된 개발 도구 버전 확인 ==="
echo "Node.js: $(node --version 2>/dev/null || echo '설치되지 않음')"
echo "npm: $(npm --version 2>/dev/null || echo '설치되지 않음')"
echo "Python: $(python3 --version 2>/dev/null || echo '설치되지 않음')"
echo "pip: $(pip3 --version 2>/dev/null || echo '설치되지 않음')"
echo "Terraform: $(terraform --version 2>/dev/null | head -1 || echo '설치되지 않음')"
echo "Go: $(go version 2>/dev/null || echo '설치되지 않음')"
echo "Rust: $(rustc --version 2>/dev/null || echo '설치되지 않음')"
echo "Git: $(git --version 2>/dev/null || echo '설치되지 않음')"
echo "Docker Compose: $(docker-compose --version 2>/dev/null || echo '설치되지 않음')"
echo "VS Code Server: $(code-server --version 2>/dev/null || echo '설치되지 않음')"

# 11. 작업 디렉토리 생성
log_info "작업 디렉토리 생성 중..."
mkdir -p ~/mcp-cloud-workspace/{projects,scripts,configs}
cd ~/mcp-cloud-workspace

# 12. 환경 설정 파일 생성
log_info "환경 설정 파일 생성 중..."
cat > ~/.mcp-dev-env << EOF
# MCP Cloud Master 개발 환경 설정
# 생성 시간: $(date)

export MCP_CLOUD_HOME="$HOME/mcp-cloud-workspace"
export PATH="\$MCP_CLOUD_HOME/bin:\$PATH"

# Go 설정
export PATH="\$PATH:/usr/local/go/bin"
export GOPATH="\$HOME/go"
export PATH="\$PATH:\$GOPATH/bin"

# Rust 설정
export PATH="\$PATH:\$HOME/.cargo/bin"

# Node.js 설정
export NODE_ENV="development"

# Python 설정
export PYTHONPATH="\$MCP_CLOUD_HOME/projects"

# 작업 디렉토리로 이동
cd "\$MCP_CLOUD_HOME"
EOF

# 13. .bashrc에 환경 설정 추가
if ! grep -q "MCP Cloud Master 개발 환경" ~/.bashrc; then
    echo "" >> ~/.bashrc
    echo "# MCP Cloud Master 개발 환경 설정" >> ~/.bashrc
    echo "source ~/.mcp-dev-env" >> ~/.bashrc
    log_success "개발 환경 설정이 .bashrc에 추가되었습니다."
fi

log_success "=== 개발 도구 설치 완료 ==="
log_info "설치 완료 시간: $(date)"
log_info "작업 디렉토리: ~/mcp-cloud-workspace"
log_warning "새로운 터미널을 열거나 'source ~/.bashrc'를 실행하여 환경 설정을 적용하세요."
log_info "다음 단계: 프로젝트 개발을 시작할 수 있습니다."
