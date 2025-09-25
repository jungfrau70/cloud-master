# 통합 자동화 시스템 설치 가이드

## 🛠️ 필수 도구 설치

### 1. AWS CLI 설치

#### Windows
```bash
# AWS CLI v2 설치
winget install Amazon.AWSCLI

# 또는 직접 다운로드
# https:///aws.amazon.com/cli/
```

#### macOS
```bash
# Homebrew 사용
brew install awscli

# 또는 pip 사용
pip install awscli
```

#### Linux
```bash
# Ubuntu/Debian
sudo apt update
sudo apt install awscli

# CentOS/RHEL
sudo yum install awscli

# 또는 pip 사용
pip install awscli
```

### 2. Google Cloud CLI 설치

#### Windows
```bash
# Google Cloud SDK 설치
winget install Google.CloudSDK

# 또는 직접 다운로드
# https:///cloud.google.com/sdk/docs/install
```

#### macOS
```bash
# Homebrew 사용
brew install --cask google-cloud-sdk

# 또는 직접 설치
curl https:///sdk.cloud.google.com | bash
```

#### Linux
```bash
# Ubuntu/Debian
curl https:///sdk.cloud.google.com | bash
exec -l $SHELL

# 또는 패키지 매니저 사용
sudo apt-get install google-cloud-cli
```

### 3. Docker 설치

#### Windows
- Docker Desktop for Windows 다운로드 및 설치
- https:///www.docker.com/products/docker-desktop/

#### macOS
- Docker Desktop for Mac 다운로드 및 설치
- 또는 Homebrew 사용:
```bash
brew install --cask docker
```

#### Linux
```bash
# Ubuntu/Debian
sudo apt update
sudo apt install docker.io
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -aG docker $USER

# CentOS/RHEL
sudo yum install docker
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -aG docker $USER
```

### 4. kubectl 설치

#### Windows
```bash
# Chocolatey 사용
choco install kubernetes-cli

# 또는 직접 다운로드
# https:///kubernetes.io/docs/tasks/tools/install-kubectl-windows/
```

#### macOS
```bash
# Homebrew 사용
brew install kubectl

# 또는 직접 설치
curl -LO "https:///dl.k8s.io/release/$[curl -L -s https:///dl.k8s.io/release/stable.txt]/bin/darwin/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/
```

#### Linux
```bash
# Ubuntu/Debian
curl -LO "https:///dl.k8s.io/release/$[curl -L -s https:///dl.k8s.io/release/stable.txt]/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/

# 또는 패키지 매니저 사용
sudo apt-get update
sudo apt-get install -y kubectl
```

### 5. Helm 설치

#### Windows
```bash
# Chocolatey 사용
choco install kubernetes-helm

# 또는 직접 다운로드
# https:///helm.sh/docs/intro/install/
```

#### macOS
```bash
# Homebrew 사용
brew install helm

# 또는 직접 설치
curl https:///raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
```

#### Linux
```bash
# 직접 설치
curl https:///raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# 또는 패키지 매니저 사용
sudo apt-get install helm
```

### 6. Terraform 설치

#### Windows
```bash
# Chocolatey 사용
choco install terraform

# 또는 직접 다운로드
# https:///www.terraform.io/downloads
```

#### macOS
```bash
# Homebrew 사용
brew install terraform

# 또는 직접 설치
# https:///www.terraform.io/downloads
```

#### Linux
```bash
# 직접 설치
wget https:///releases.hashicorp.com/terraform/1.6.0/terraform_1.6.0_linux_amd64.zip
unzip terraform_1.6.0_linux_amd64.zip
sudo mv terraform /usr/local/bin/

# 또는 패키지 매니저 사용
sudo apt-get install terraform
```

## 🔧 설정 및 인증

### 1. AWS 설정
```bash
# AWS CLI 설정
aws configure

# 입력할 정보:
# AWS Access Key ID: [YOUR_ACCESS_KEY]
# AWS Secret Access Key: [YOUR_SECRET_KEY]
# Default region name: us-west-2
# Default output format: json

# 설정 확인
aws sts get-caller-identity
```

### 2. Google Cloud 설정
```bash
# GCP 인증
gcloud auth login

# 프로젝트 설정
gcloud config set project YOUR_PROJECT_ID

# 설정 확인
gcloud config list
```

### 3. Docker 설정
```bash
# Docker 서비스 시작
sudo systemctl start docker  # Linux

# Docker 실행 확인
docker --version
docker run hello-world
```

### 4. Kubernetes 설정
```bash
# kubeconfig 파일 확인
ls ~/.kube/config

# 클러스터 연결 확인
kubectl cluster-info
```

### 5. GitHub 설정
```bash
# GitHub CLI 인증
gh auth login

# 인증 확인
gh auth status
```

## 📦 Python 의존성 설치

### 1. Python 패키지 설치
```bash
# 통합 자동화 디렉토리로 이동
cd mcp_knowledge_base/integrated_automation

# 의존성 설치
pip install -r requirements.txt
```

### 2. 개별 패키지 설치
```bash
# 기본 패키지
pip install pyyaml requests psutil

# AWS SDK
pip install boto3 botocore

# Google Cloud SDK
pip install google-cloud-storage google-cloud-compute

# Docker SDK
pip install docker

# Kubernetes SDK
pip install kubernetes

# GitHub API
pip install PyGithub

# 기타 도구
pip install python-terraform colorlog rich
```

## 🧪 설치 검증

### 1. 통합 검증 실행
```bash
cd mcp_knowledge_base/integrated_automation
python validate_integration.py
```

### 2. 개별 도구 검증
```bash
# AWS CLI
aws --version
aws sts get-caller-identity

# Google Cloud CLI
gcloud --version
gcloud config list

# Docker
docker --version
docker info

# kubectl
kubectl version --client

# Helm
helm version

# Terraform
terraform version

# GitHub CLI
gh --version
gh auth status
```

## 🚨 문제 해결

### 1. 권한 문제
```bash
# Docker 권한 문제 [Linux]
sudo usermod -aG docker $USER
newgrp docker

# kubectl 권한 문제
chmod 600 ~/.kube/config
```

### 2. 네트워크 문제
```bash
# 프록시 설정 ["필요한 경우"]
export http_proxy=http://proxy.company.com:8080
export https_proxy=http://proxy.company.com:8080

# 방화벽 확인
# Windows: Windows Defender 방화벽
# Linux: ufw 또는 iptables
# macOS: 시스템 환경설정 > 보안 및 개인정보보호
```

### 3. 버전 호환성 문제
```bash
# Python 버전 확인
python --version  # 3.8 이상 필요

# pip 업그레이드
pip install --upgrade pip

# 패키지 재설치
pip uninstall package_name
pip install package_name
```

## 📚 추가 리소스

### 공식 문서
- ["AWS CLI 문서"][https:///docs.aws.amazon.com/cli/]
- ["Google Cloud CLI 문서"][https:///cloud.google.com/sdk/docs]
- ["Docker 문서"][https:///docs.docker.com/]
- ["Kubernetes 문서"][https:///kubernetes.io/docs/]
- ["Helm 문서"][https:///helm.sh/docs/]
- ["Terraform 문서"][https:///www.terraform.io/docs/]

### 학습 자료
- ["AWS 학습 경로"][https:///aws.amazon.com/training/]
- ["Google Cloud 학습 경로"][https:///cloud.google.com/training]
- ["Kubernetes 학습 경로"][https:///kubernetes.io/docs/tutorials/]
- ["Docker 학습 경로"][https:///docs.docker.com/get-started/]

---

**🎉 모든 도구가 설치되면 통합 자동화 시스템을 사용할 수 있습니다!**


---



---



---



---

<div align="center">

 현재 위치
**통합 자동화**

## 🔗 관련 과정
["Cloud Basic 1일차"][README.md] | ["Cloud Master 1일차"][README.md] | ["Cloud Container 1일차"][README.md]

</div>

---

<div align="center">

["🏠 홈"][index.md] | ["📚 전체 커리큘럼"][curriculum.md] | ["🔗 학습 경로"][learning-path.md]

</div>
