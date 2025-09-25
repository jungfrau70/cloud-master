#!/bin/bash

# MCP Cloud GCP Compute Engine 인스턴스 초기 설정 스크립트
# 이 스크립트는 GCE 인스턴스 시작 시 자동으로 실행됩니다.

# 로그 파일 설정
exec > >(tee /var/log/startup-script.log|logger -t startup-script -s 2>/dev/console) 2>&1

echo "=== MCP Cloud GCP 인스턴스 초기화 시작 ==="
date

# 1. 시스템 업데이트
echo "시스템 패키지 업데이트 중..."
apt-get update -y
apt-get upgrade -y

# 2. 필수 패키지 설치
echo "필수 패키지 설치 중..."
apt-get install -y \
    git \
    wget \
    curl \
    unzip \
    htop \
    vim \
    net-tools \
    telnet \
    ca-certificates \
    gnupg \
    lsb-release

# 3. Docker 설치
echo "Docker 설치 중..."
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
systemctl start docker
systemctl enable docker
usermod -a -G docker $USER

# 4. Docker Compose 설치
echo "Docker Compose 설치 중..."
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose

# 5. Google Cloud CLI 설치 (이미 설치되어 있을 수 있음)
echo "Google Cloud CLI 확인 중..."
if ! command -v gcloud &> /dev/null; then
    echo "Google Cloud CLI 설치 중..."
    curl https://sdk.cloud.google.com | bash
    source /root/.bashrc
fi

# 6. Terraform 설치
echo "Terraform 설치 중..."
wget https://releases.hashicorp.com/terraform/1.6.0/terraform_1.6.0_linux_amd64.zip
unzip terraform_1.6.0_linux_amd64.zip
mv terraform /usr/local/bin/
chmod +x /usr/local/bin/terraform
rm terraform_1.6.0_linux_amd64.zip

# 7. kubectl 설치
echo "kubectl 설치 중..."
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
mv kubectl /usr/local/bin/

# 8. Node.js 설치 (LTS 버전)
echo "Node.js 설치 중..."
curl -fsSL https://deb.nodesource.com/setup_lts.x | bash -
apt-get install -y nodejs

# 9. Python 3 및 pip 설치
echo "Python 3 및 pip 설치 중..."
apt-get install -y python3 python3-pip
pip3 install --upgrade pip

# 10. 작업 디렉토리 생성
echo "작업 디렉토리 생성 중..."
mkdir -p /opt/mcp-cloud
chown $USER:$USER /opt/mcp-cloud

# 11. 방화벽 설정 (ufw 사용)
echo "방화벽 설정 중..."
ufw --force enable
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw allow 3000/tcp
ufw allow 7000/tcp

# 12. 시간대 설정
echo "시간대 설정 중..."
timedatectl set-timezone Asia/Seoul

# 13. 설치 완료 확인
echo "=== 설치된 소프트웨어 버전 확인 ==="
echo "Docker: $(docker --version)"
echo "Docker Compose: $(docker-compose --version)"
echo "Google Cloud CLI: $(gcloud --version)"
echo "Terraform: $(terraform --version)"
echo "kubectl: $(kubectl version --client --short)"
echo "Node.js: $(node --version)"
echo "npm: $(npm --version)"
echo "Python: $(python3 --version)"
echo "pip: $(pip3 --version)"

# 14. MCP Cloud 프로젝트 준비
echo "MCP Cloud 프로젝트 준비 중..."
cd /opt/mcp-cloud
# git clone https://github.com/your-org/mcp-cloud.git

# 15. 인스턴스 메타데이터에서 정보 가져오기
echo "=== 인스턴스 정보 ==="
echo "인스턴스 이름: $(curl -s -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/name)"
echo "인스턴스 ID: $(curl -s -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/id)"
echo "머신 타입: $(curl -s -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/machine-type)"
echo "외부 IP: $(curl -s -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/access-configs/0/external-ip)"
echo "내부 IP: $(curl -s -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/ip)"
echo "존: $(curl -s -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/zone)"

echo "=== MCP Cloud GCP 인스턴스 초기화 완료 ==="
date

echo "인스턴스가 성공적으로 초기화되었습니다!"
echo "SSH로 연결하여 작업을 시작할 수 있습니다."
