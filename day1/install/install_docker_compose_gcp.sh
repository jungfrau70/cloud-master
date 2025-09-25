#!/bin/bash
set -e

echo "📦 Google Cloud Platform에서 Docker 및 Docker Compose 설치"

# OS 정보 확인
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$NAME
    VER=$VERSION_ID
    echo "OS: $OS $VER"
else
    echo "OS 정보를 확인할 수 없습니다."
    exit 1
fi

# Ubuntu/Debian 계열 확인
if [[ "$OS" == *"Ubuntu"* ]] || [[ "$OS" == *"Debian"* ]]; then
    echo "Ubuntu/Debian 계열에서 Docker 설치..."
    
    # 기존 Docker 패키지 제거
    sudo apt-get remove -y docker docker-engine docker.io containerd runc || true
    
    # 패키지 인덱스 업데이트
    sudo apt-get update -y
    
    # 필요한 패키지 설치
    sudo apt-get install -y \
        ca-certificates \
        curl \
        gnupg \
        lsb-release
    
    # Docker의 공식 GPG 키 추가
    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    
    # Docker 리포지터리 설정
    echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
        $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # 패키지 인덱스 업데이트
    sudo apt-get update -y
    
    # Docker Engine 설치
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    
    # Docker 서비스 시작 및 부팅 시 자동 시작
    sudo systemctl start docker
    sudo systemctl enable docker
    
    # 현재 사용자 docker 그룹에 추가
    sudo usermod -aG docker "$USER"
    
    # Docker 버전 확인
    docker --version
    
    # docker-compose 플러그인 확인
    echo "docker-compose 플러그인 버전:"
    docker compose version
    
    echo "✅ 설치 완료! 재로그인 후 sudo 없이 docker 사용 가능."
    echo "💡 docker-compose 명령어는 'docker compose'로 사용하세요."

elif [[ "$OS" == *"CentOS"* ]] || [[ "$OS" == *"Red Hat"* ]] || [[ "$OS" == *"Rocky"* ]]; then
    echo "RHEL/CentOS/Rocky Linux 계열에서 Docker 설치..."
    
    # 기존 Docker 패키지 제거
    sudo yum remove -y docker docker-client docker-client-latest docker-common docker-latest docker-latest-logrotate docker-logrotate docker-engine || true
    
    # 필요한 패키지 설치
    sudo yum install -y yum-utils
    
    # Docker 리포지터리 추가
    sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
    
    # Docker Engine 설치
    sudo yum install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    
    # Docker 서비스 시작 및 부팅 시 자동 시작
    sudo systemctl start docker
    sudo systemctl enable docker
    
    # 현재 사용자 docker 그룹에 추가
    sudo usermod -aG docker "$USER"
    
    # Docker 버전 확인
    docker --version
    
    # docker-compose 플러그인 확인
    echo "docker-compose 플러그인 버전:"
    docker compose version
    
    echo "✅ 설치 완료! 재로그인 후 sudo 없이 docker 사용 가능."
    echo "💡 docker-compose 명령어는 'docker compose'로 사용하세요."

# Container-Optimized OS (COS) 확인
elif [[ "$OS" == *"Container-Optimized"* ]] || [[ "$OS" == *"COS"* ]]; then
    echo "Container-Optimized OS에서 Docker 확인..."
    
    # COS에는 Docker가 이미 설치되어 있음
    docker --version
    
    # docker-compose 설치 (별도 바이너리)
    echo "📥 docker-compose 최신 바이너리 설치"
    
    COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep tag_name | cut -d '"' -f 4)
    
    sudo curl -L "https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" \
        -o /usr/local/bin/docker-compose
    
    sudo chmod +x /usr/local/bin/docker-compose
    
    echo "docker-compose 버전:"
    docker-compose --version
    
    echo "✅ COS에서 Docker 및 docker-compose 설치 완료!"

else
    echo "지원되지 않는 OS입니다: $OS"
    echo "Ubuntu, Debian, CentOS, RHEL, Rocky Linux, Container-Optimized OS만 지원됩니다."
    exit 1
fi
