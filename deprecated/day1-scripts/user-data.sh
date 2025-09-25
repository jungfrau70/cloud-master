#!/bin/bash

# MCP Cloud EC2 인스턴스 초기 설정 스크립트
# 이 스크립트는 EC2 인스턴스 시작 시 자동으로 실행됩니다.

# 로그 파일 설정
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

echo "=== MCP Cloud 인스턴스 초기화 시작 ==="
date

# 1. 시스템 업데이트
echo "시스템 패키지 업데이트 중..."
yum update -y

# 2. 필수 패키지 설치
echo "필수 패키지 설치 중..."
yum install -y \
    git \
    wget \
    curl \
    unzip \
    htop \
    vim \
    net-tools \
    telnet

# 3. Docker 설치
echo "Docker 설치 중..."
yum install -y docker
systemctl start docker
systemctl enable docker
usermod -a -G docker ec2-user

# 4. Docker Compose 설치
echo "Docker Compose 설치 중..."
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose

# 5. AWS CLI v2 설치
echo "AWS CLI v2 설치 중..."
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
./aws/install
rm -rf aws awscliv2.zip

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
curl -fsSL https://rpm.nodesource.com/setup_lts.x | bash -
yum install -y nodejs

# 9. Python 3 및 pip 설치
echo "Python 3 및 pip 설치 중..."
yum install -y python3 python3-pip
pip3 install --upgrade pip

# 10. 작업 디렉토리 생성
echo "작업 디렉토리 생성 중..."
mkdir -p /opt/mcp-cloud
chown ec2-user:ec2-user /opt/mcp-cloud

# 11. 방화벽 설정 (필요한 경우)
echo "방화벽 설정 중..."
systemctl enable firewalld
systemctl start firewalld
firewall-cmd --permanent --add-port=22/tcp
firewall-cmd --permanent --add-port=80/tcp
firewall-cmd --permanent --add-port=443/tcp
firewall-cmd --permanent --add-port=3000/tcp
firewall-cmd --permanent --add-port=7000/tcp
firewall-cmd --reload

# 12. 시간대 설정
echo "시간대 설정 중..."
timedatectl set-timezone Asia/Seoul

# 13. 설치 완료 확인
echo "=== 설치된 소프트웨어 버전 확인 ==="
echo "Docker: $(docker --version)"
echo "Docker Compose: $(docker-compose --version)"
echo "AWS CLI: $(aws --version)"
echo "Terraform: $(terraform --version)"
echo "kubectl: $(kubectl version --client --short)"
echo "Node.js: $(node --version)"
echo "npm: $(npm --version)"
echo "Python: $(python3 --version)"
echo "pip: $(pip3 --version)"

# 14. MCP Cloud 프로젝트 클론 (예시)
echo "MCP Cloud 프로젝트 준비 중..."
cd /opt/mcp-cloud
# git clone https://github.com/your-org/mcp-cloud.git

echo "=== MCP Cloud 인스턴스 초기화 완료 ==="
date

# 15. 인스턴스 메타데이터에서 정보 가져오기
echo "=== 인스턴스 정보 ==="
echo "인스턴스 ID: $(curl -s http://169.254.169.254/latest/meta-data/instance-id)"
echo "인스턴스 타입: $(curl -s http://169.254.169.254/latest/meta-data/instance-type)"
echo "퍼블릭 IP: $(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)"
echo "프라이빗 IP: $(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)"
echo "가용 영역: $(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)"

echo "인스턴스가 성공적으로 초기화되었습니다!"
echo "SSH로 연결하여 작업을 시작할 수 있습니다."
