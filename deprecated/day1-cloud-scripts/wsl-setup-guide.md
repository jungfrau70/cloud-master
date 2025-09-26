# WSL 고급 설정 및 개발 환경 구성 가이드

이 가이드는 Cloud Master 과정을 위한 WSL[Windows Subsystem for Linux] 환경의 고급 설정과 개발 환경 구성을 다룹니다. 기본 WSL 설치가 완료된 후 추가 설정이 필요한 경우를 위한 가이드입니다.

## 📋 목차

1. ["사전 요구사항"]["#1-사전-요구사항"]
2. ["WSL 고급 설정"]["#2-wsl-고급-설정"]
3. ["개발 환경 구성"]["#3-개발-환경-구성"]
   - ["자동화된 설치 스크립트"]["#31-자동화된-설치-스크립트-권장"]
   - ["설치되는 도구들"]["#32-설치되는-도구들"]
   - ["Git 설정"]["#33-git-설정"]
   - ["설치 후 설정"]["#34-설치-후-설정"]
   - ["작업 디렉토리"]["#35-작업-디렉토리"]
   - ["사용법 예시"]["#36-사용법-예시"]
4. ["성능 최적화"]["#4-성능-최적화"]
5. ["GUI 애플리케이션 실행"]["#5-gui-애플리케이션-실행"]
6. ["보안 모범 사례"]["#6-보안-모범-사례"]
7. ["문제 해결"]["#7-문제-해결"]

---

## 1. 사전 요구사항

### 1.1 기본 WSL 설치 확인
이 가이드를 진행하기 전에 다음이 완료되어 있어야 합니다:
- WSL 2 설치 및 설정 완료
- 기본 Linux 배포판 설치 완료
- 기본 사용자 계정 설정 완료

> **📖 참고**: 기본 WSL 설치가 필요하다면 (wsl-install.md)(wsl-install.md)를 먼저 참조하세요.

### 1.2 시스템 요구사항
- **RAM**: 최소 8GB ["16GB 권장"]
- **저장공간**: 최소 20GB 여유 공간
- **CPU**: 64비트 프로세서
- **가상화**: BIOS/UEFI에서 가상화 활성화 필요

---

## 2. WSL 고급 설정

### 2.1 추가 WSL 인스턴스 생성

#### 새로운 배포판 설치
```powershell
# 사용 가능한 배포판 목록 확인
wsl --list --online

# 새로운 배포판 설치
wsl --install -d Ubuntu-20.04
wsl --install -d Debian
wsl --install -d kali-linux
```

#### WSL 인스턴스 관리
```powershell
# 설치된 배포판 목록 확인
wsl --list --all

# 특정 배포판 시작
wsl -d Ubuntu-20.04

# 특정 배포판 중지
wsl --terminate Ubuntu-20.04

# 배포판 제거
wsl --unregister Ubuntu-20.04
```

### 2.2 WSL 설정 파일 구성

#### .wslconfig 파일 생성
`%USERPROFILE%\.wslconfig` 파일을 생성하여 WSL 설정을 최적화합니다:

```ini
[wsl2]
# 메모리 제한 ["기본값: 시스템 RAM의 50%"]
memory=8GB

# CPU 코어 수 제한 ["기본값: 시스템 CPU의 50%"]
processors=4

# 스왑 파일 크기 ["기본값: 메모리의 25%"]
swap=2GB

# 스왑 파일 위치
swapFile=C:\\temp\\wsl-swap.vhdx

# 가상 디스크 위치
vmIdleTimeout=60000

# 네트워킹 모드 [mirrored, nat, none]
networkingMode=mirrored

# DNS 서버 설정
dnsTunneling=true
firewall=true
autoProxy=true
```

### 2.3 WSL 배포판별 설정

#### Ubuntu 설정 최적화
```bash
# Ubuntu에서 실행
sudo apt update && sudo apt upgrade -y

# 필수 패키지 설치
sudo apt install -y \
    curl \
    wget \
    git \
    vim \
    nano \
    htop \
    tree \
    unzip \
    build-essential \
    software-properties-common \
    apt-transport-https \
    ca-certificates \
    gnupg \
    lsb-release

# 한국어 로케일 설정
sudo locale-gen ko_KR.UTF-8
sudo update-locale LANG=ko_KR.UTF-8
```

#### Debian 설정 최적화
```bash
# Debian에서 실행
sudo apt update && sudo apt upgrade -y

# 필수 패키지 설치
sudo apt install -y \
    curl \
    wget \
    git \
    vim \
    nano \
    htop \
    tree \
    unzip \
    build-essential \
    software-properties-common \
    apt-transport-https \
    ca-certificates \
    gnupg \
    lsb-release
```

---

## 3. 개발 환경 구성

### 3.1 자동화된 설치 스크립트 ["권장"]

Cloud Master 과정에 필요한 모든 도구를 한 번에 설치할 수 있는 자동화 스크립트를 제공합니다.

#### 전체 설치 스크립트 실행
```bash
# 스크립트가 위치한 디렉토리로 이동
cd mcp_knowledge_base/cloud_master/repos/install/

# 스크립트 실행 권한 부여
chmod +x install-all-wsl.sh

# 모든 도구를 한 번에 설치
./install-all-wsl.sh
```

#### 환경 검증 스크립트
```bash
# 설치된 환경 검증
chmod +x check-environment.sh
./check-environment.sh
```

#### 개별 도구 설치 ["선택사항"]
```bash
# AWS CLI 설치
chmod +x install-aws-cli-wsl.sh
./install-aws-cli-wsl.sh

# GCP CLI 설치
chmod +x install-gcp-cli-wsl.sh
./install-gcp-cli-wsl.sh

# Docker 설치
chmod +x install-docker-wsl.sh
./install-docker-wsl.sh

# Kubernetes 도구 설치
chmod +x install-k8s-tools-wsl.sh
./install-k8s-tools-wsl.sh

# 개발 도구 설치
chmod +x install-dev-tools-wsl.sh
./install-dev-tools-wsl.sh
```

### 3.2 설치되는 도구들

#### 클라우드 도구
- **AWS CLI v2**: AWS 서비스 관리
- **GCP CLI**: Google Cloud Platform 서비스 관리
- **Terraform**: Infrastructure as Code
- **AWS Vault**: AWS 자격 증명 관리

#### 컨테이너 도구
- **Docker**: 컨테이너 플랫폼
- **Docker Compose**: 다중 컨테이너 애플리케이션 관리
- **Podman**: Docker 대안 컨테이너 도구

#### Kubernetes 도구
- **kubectl**: Kubernetes 클러스터 관리
- **Helm**: Kubernetes 패키지 관리자
- **k9s**: Kubernetes 클러스터 대화형 관리
- **kustomize**: Kubernetes 설정 관리
- **stern**: Kubernetes 로그 도구
- **kubectx/kubens**: 컨텍스트 및 네임스페이스 전환
- **kubectl-neat**: Kubernetes YAML 정리 도구

#### 개발 도구
- **Node.js LTS**: JavaScript 런타임
- **Python 3**: Python 프로그래밍 언어
- **Go**: Go 프로그래밍 언어
- **Rust**: Rust 프로그래밍 언어
- **Git**: 버전 관리 시스템
- **VS Code Server**: 웹 기반 코드 에디터 ["선택사항"]
- **GitHub CLI**: GitHub 명령줄 도구

#### 시스템 도구
- **curl, wget**: 파일 다운로드
- **jq**: JSON 처리
- **htop**: 시스템 모니터링
- **vim, nano**: 텍스트 에디터
- **tree**: 디렉토리 구조 표시
- **bat**: cat 명령어 개선 버전
- **exa**: ls 명령어 개선 버전
- **fd**: find 명령어 개선 버전
- **ripgrep**: grep 명령어 개선 버전

#### 보안 도구
- **SSH 키 관리**: 자동 권한 설정 [400]
- **GPG**: 암호화 및 서명
- **pass**: 비밀번호 관리자

### 3.3 Git 설정

#### Git 전역 설정
```bash
# Git 사용자 정보 설정
git config --global user.name "Your Name"
git config --global user.email "your.email@example.com"

# Git 기본 브랜치명 설정
git config --global init.defaultBranch main

# Git 편집기 설정
git config --global core.editor "vim"

# Git 자동 줄바꿈 설정
git config --global core.autocrlf input

# Git 설정 확인
git config --list --global
```

#### SSH 키 생성 및 설정
```bash
# SSH 키 생성
ssh-keygen -t ed25519 -C "your.email@example.com"

# SSH 키를 SSH 에이전트에 추가
eval "$[ssh-agent -s]"
ssh-add ~/.ssh/id_ed25519

# 공개 키 확인 ["GitHub/GitLab에 등록"]
cat ~/.ssh/id_ed25519.pub
```

### 3.2 개발 도구 설치

#### Visual Studio Code Server
```bash
# VS Code Server 설치
curl -fsSL https://code-server.dev/install.sh | sh

# VS Code Server 시작
code-server --bind-addr 0.0.0.0:8080
```

#### Docker Desktop WSL2 통합
1. Docker Desktop 설치 [Windows]
2. Docker Desktop 실행
3. Settings → Resources → WSL Integration
4. 'Enable integration with my default WSL distro' 체크
5. 사용할 WSL 배포판 선택
6. Docker Desktop 재시작

#### Kubernetes 개발 환경
```bash
# kubectl 설치
curl -LO "https://dl.k8s.io/release/$[curl -L -s https://dl.k8s.io/release/stable.txt]/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/

# Helm 설치
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Minikube 설치 ["로컬 Kubernetes"]
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
sudo install minikube-linux-amd64 /usr/local/bin/minikube
```

### 3.3 프로그래밍 언어 환경

#### Node.js 환경
```bash
# NodeSource 저장소 추가
curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -

# Node.js 설치
sudo apt install -y nodejs

# npm 전역 패키지 설치
npm install -g yarn pnpm typescript ts-node nodemon

# 버전 확인
node --version
npm --version
yarn --version
```

#### Python 환경
```bash
# Python 3 및 pip 설치
sudo apt install -y python3 python3-pip python3-venv python3-dev

# pip 업그레이드
python3 -m pip install --upgrade pip

# 가상환경 도구 설치
pip3 install virtualenv virtualenvwrapper

# 가상환경 설정
echo 'export WORKON_HOME=$HOME/.virtualenvs' >> ~/.bashrc
echo 'source /usr/local/bin/virtualenvwrapper.sh' >> ~/.bashrc
source ~/.bashrc
```

#### Go 환경
```bash
# Go 설치
wget https://go.dev/dl/go1.21.0.linux-amd64.tar.gz
sudo tar -C /usr/local -xzf go1.21.0.linux-amd64.tar.gz

# PATH 설정
echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.bashrc
echo 'export GOPATH=$HOME/go' >> ~/.bashrc
echo 'export PATH=$PATH:$GOPATH/bin' >> ~/.bashrc
source ~/.bashrc
```

### 3.4 설치 후 설정

#### 환경 설정 적용
```bash
# 새로운 터미널을 열거나
source ~/.bashrc

# 또는 환경 설정 파일을 직접 로드
source ~/.mcp-cloud-env

# 환경 검증 실행
./check-environment.sh
```

#### AWS 설정
```bash
# AWS CLI 설정
aws configure
```
설정할 정보:
- AWS Access Key ID
- AWS Secret Access Key
- Default region name ["예: ap-northeast-2"]
- Default output format ["예: json"]

#### GCP 설정
```bash
# GCP 초기화
gcloud init

# GCP 인증 확인
gcloud auth list
```
설정할 정보:
- GCP 계정 로그인
- 프로젝트 선택
- 기본 리전 설정 ["예: asia-northeast3"]
- 기본 존 설정 ["예: asia-northeast3-a"]

#### Docker 권한 설정
```bash
# Docker 그룹 권한 적용
newgrp docker

# 또는 로그아웃 후 다시 로그인

# Docker 서비스 시작 ["WSL에서"]
sudo service docker start
```

#### SSH 키 설정
```bash
# SSH 키 생성 ["없는 경우"]
ssh-keygen -t ed25519 -C "your-email@example.com"

# SSH 키 권한 자동 설정
chmod 400 ~/.ssh/id_ed25519*

# GitHub에 SSH 키 추가
gh auth login
gh ssh-key add ~/.ssh/id_ed25519.pub
```

### 3.5 작업 디렉토리

설치 후 다음 디렉토리가 생성됩니다:
- `~/mcp-cloud-workspace/`: 메인 작업 디렉토리
- `~/mcp-cloud-workspace/projects/`: 프로젝트 파일
- `~/mcp-cloud-workspace/scripts/`: 스크립트 파일
- `~/mcp-cloud-workspace/configs/`: 설정 파일

### 3.6 사용법 예시

#### AWS CLI 사용 예시
```bash
# EC2 인스턴스 목록
aws ec2 describe-instances

# S3 버킷 목록
aws s3 ls

# IAM 사용자 정보
aws sts get-caller-identity

# AWS Vault 사용 ["보안 강화"]
aws-vault exec default -- aws s3 ls
```

#### GCP CLI 사용 예시
```bash
# Compute Engine 인스턴스 목록
gcloud compute instances list

# Storage 버킷 목록
gsutil ls

# 현재 프로젝트 확인
gcloud config get-value project

# GCP 인증 확인
gcloud auth list
```

#### Docker 사용 예시
```bash
# Docker 이미지 빌드
docker build -t my-app .

# 컨테이너 실행
docker run -d -p 8080:80 my-app

# 컨테이너 목록
docker ps

# Docker Compose 사용
docker-compose up -d
```

#### Kubernetes 사용 예시
```bash
# 클러스터 정보
kubectl cluster-info

# Pod 목록
kubectl get pods

# 서비스 목록
kubectl get services

# k9s 대화형 관리
k9s

# Helm 차트 설치
helm install my-app stable/nginx
```

#### SSH 키 관리 예시
```bash
# SSH 키 생성
ssh-keygen -t ed25519 -C "your-email@example.com"

# SSH 키 권한 설정 ["자동"]
chmod 400 ~/.ssh/id_ed25519*

# EC2 인스턴스 연결
ssh -i ~/.ssh/your-key.pem ec2-user@your-instance-ip

# GitHub SSH 연결 테스트
ssh -T git@github.com
```

#### 개발 도구 사용 예시
```bash
# Git 설정
git config --global user.name "Your Name"
git config --global user.email "your-email@example.com"

# GitHub CLI 사용
gh repo clone owner/repo
gh issue list
gh pr create

# 개선된 명령어 사용
bat README.md          # cat 대신
exa -la                 # ls 대신
fd "pattern"           # find 대신
rg "pattern"           # grep 대신
```

---

## 4. 성능 최적화

### 4.1 WSL 2 성능 최적화

#### 메모리 사용량 최적화
```bash
# 메모리 사용량 확인
free -h

# 스왑 사용량 확인
swapon --show

# 불필요한 프로세스 정리
sudo apt autoremove -y
sudo apt autoclean
```

#### 디스크 공간 최적화
```bash
# 디스크 사용량 확인
df -h

# 패키지 캐시 정리
sudo apt clean
sudo apt autoremove -y

# 로그 파일 정리
sudo journalctl --vacuum-time=7d
```

### 4.2 네트워킹 최적화

#### DNS 설정 최적화
```bash
# DNS 서버 설정
sudo tee /etc/resolv.conf > /dev/null <<EOF
nameserver 8.8.8.8
nameserver 8.8.4.4
nameserver 1.1.1.1
EOF

# DNS 설정 고정 ["WSL 재시작 시에도 유지"]
sudo chattr +i /etc/resolv.conf
```

#### 방화벽 설정
```bash
# UFW 방화벽 설치 및 설정
sudo apt install -y ufw

# 기본 정책 설정
sudo ufw default deny incoming
sudo ufw default allow outgoing

# SSH 허용
sudo ufw allow ssh

# 방화벽 활성화
sudo ufw enable
```

---

## 5. GUI 애플리케이션 실행

### 5.1 X 서버 설치 및 설정

#### VcXsrv 설치 [Windows]
1. ["VcXsrv 다운로드"][https://sourceforge.net/projects/vcxsrv/]
2. VcXsrv 설치 및 실행
3. Display settings: Multiple windows
4. Client startup: Start no client
5. Extra settings: Disable access control 체크

#### WSL에서 X 서버 연결
```bash
# DISPLAY 환경 변수 설정
export DISPLAY=$[cat /etc/resolv.conf | grep nameserver | awk '{print $2}']:0

# .bashrc에 추가
echo 'export DISPLAY=$[cat /etc/resolv.conf | grep nameserver | awk '{print $2}']:0' >> ~/.bashrc

# X11 유틸리티 설치
sudo apt install -y x11-apps

# 테스트 ["xeyes 실행"]
xeyes
```

### 5.2 GUI 애플리케이션 설치

#### 웹 브라우저
```bash
# Firefox 설치
sudo apt install -y firefox

# Chrome 설치
wget -q -O - https://dl.google.com/linux/linux_signing_key.pub | sudo apt-key add -
echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" | sudo tee /etc/apt/sources.list.d/google-chrome.list
sudo apt update
sudo apt install -y google-chrome-stable
```

#### 개발 도구
```bash
# Visual Studio Code [GUI]
wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg
sudo install -o root -g root -m 644 packages.microsoft.gpg /etc/apt/trusted.gpg.d/
sudo sh -c 'echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/trusted.gpg.d/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" > /etc/apt/sources.list.d/vscode.list'
sudo apt update
sudo apt install -y code

# IntelliJ IDEA Community Edition
sudo snap install intellij-idea-community --classic
```

---

## 6. 보안 모범 사례

### 6.1 SSH 키 관리
- **키 파일 권한**: 항상 400 ["소유자만 읽기"]
- **SSH 디렉토리 권한**: 700 ["소유자만 접근"]
- **키 생성**: ED25519 알고리즘 사용 권장
- **키 백업**: 안전한 위치에 암호화하여 저장

### 6.2 AWS 보안
- **AWS Vault 사용**: 자격 증명을 안전하게 관리
- **IAM 역할**: 최소 권한 원칙 적용
- **MFA 활성화**: 다중 인증 사용

### 6.3 GCP 보안
- **서비스 계정**: 사용자 계정 대신 서비스 계정 사용
- **키 로테이션**: 정기적인 키 교체
- **감사 로그**: 모든 활동 모니터링

---

## 7. 문제 해결

### 7.1 WSL 환경 확인
```bash
# WSL 버전 확인
wsl --list --verbose

# Linux 배포판 확인
cat /etc/os-release

# WSL 환경 검증
./check-environment.sh
```

### 7.2 일반적인 문제들

#### WSL 시작 문제
```powershell
# WSL 서비스 재시작
wsl --shutdown
wsl

# WSL 상태 확인
wsl --status
```

#### 네트워킹 문제
```bash
# 네트워크 인터페이스 확인
ip addr show

# 라우팅 테이블 확인
ip route show

# DNS 확인
nslookup google.com
```

#### 권한 문제
```bash
# 사용자 그룹 확인
groups

# sudo 권한 확인
sudo -l

# 파일 권한 확인
ls -la
```

### 6.2 성능 문제

#### 메모리 부족
```bash
# 메모리 사용량 확인
free -h
ps aux --sort=-%mem | head

# 스왑 활성화
sudo fallocate -l 2G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
```

#### 디스크 공간 부족
```bash
# 디스크 사용량 확인
df -h
du -sh /*

# 큰 파일 찾기
find / -type f -size +100M 2>/dev/null

# 패키지 캐시 정리
sudo apt clean
sudo apt autoremove -y
```

### 7.3 권한 문제
```bash
# 스크립트 실행 권한 부여
chmod +x *.sh

# sudo 권한 확인
sudo -v

# SSH 키 권한 문제 해결
chmod 400 ~/.ssh/id_*
chmod 700 ~/.ssh
```

### 7.4 네트워크 문제
```bash
# DNS 설정 확인
cat /etc/resolv.conf

# 패키지 저장소 업데이트
sudo apt update

# 네트워크 연결 테스트
ping -c 3 google.com
```

### 7.5 Docker 문제

#### Docker Desktop WSL2 통합 문제
1. Docker Desktop 재시작
2. WSL 재시작: `wsl --shutdown`
3. Docker Desktop에서 WSL Integration 재설정

#### WSL에서 Docker Engine 사용
```bash
# Docker 서비스 상태 확인
sudo systemctl status docker

# Docker 서비스 시작
sudo systemctl start docker

# WSL에서 Docker 서비스 시작
sudo service docker start

# Docker 권한 문제 해결
sudo usermod -aG docker $USER
newgrp docker

# Docker 테스트
docker run hello-world
```

### 7.6 SSH 키 권한 문제
```bash
# 키 파일 권한 자동 수정
find ~/.ssh -name "*.pem" -exec chmod 400 {} \;
find ~/.ssh -name "id_*" -exec chmod 400 {} \;

# SSH 디렉토리 권한 설정
chmod 700 ~/.ssh
chmod 644 ~/.ssh/authorized_keys 2>/dev/null || true
```

### 7.7 설치 실패 문제
```bash
# 설치 로그 확인
tail -f /tmp/mcp-cloud-install.log

# 부분 설치 정리 후 재시도
./install-all-wsl.sh --cleanup
./install-all-wsl.sh
```

### 7.8 로그 확인
```bash
# 설치 로그 확인
tail -f /tmp/mcp-cloud-install.log

# 환경 검증 실행
./check-environment.sh

# 특정 도구 버전 확인
aws --version
gcloud --version
docker --version
kubectl version --client
```

---

## 📚 추가 자료

### 관련 문서
- ["WSL 기본 설치 가이드"](wsl-install.md)
- ["Cloud Master 실습 가이드"](../../execuise-guide.md)
- ["Docker 설치 가이드"][../../repos/install/]

### 유용한 링크
- ["Microsoft WSL 공식 문서"][https://docs.microsoft.com/ko-kr/windows/wsl/]
- ["WSL 2 릴리스 노트"][https://docs.microsoft.com/ko-kr/windows/wsl/release-notes]
- ["Docker Desktop WSL2 백엔드"][https://docs.docker.com/desktop/wsl/]

---

이제 WSL 환경이 완전히 구성되었습니다! Cloud Master 과정의 모든 실습을 진행할 수 있는 환경이 준비되었습니다. 🚀✨