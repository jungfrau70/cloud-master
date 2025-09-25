# 🚀 GCP Compute Engine 배포 가이드

## 📋 개요

이 가이드는 GitHub Actions Demo 애플리케이션을 GCP Compute Engine VM에 배포하는 방법을 설명합니다.

## 🔧 사전 준비

### 1. GCP 프로젝트 설정
- GCP 프로젝트 생성
- Compute Engine API 활성화
- 서비스 계정 생성 및 권한 설정

### 2. GCP VM 생성
```bash
# GCP VM 인스턴스 생성
gcloud compute instances create github-actions-demo-gcp \
    --zone=us-central1-a \
    --machine-type=e2-medium \
    --image-family=ubuntu-2004-lts \
    --image-project=ubuntu-os-cloud \
    --boot-disk-size=20GB \
    --tags=github-actions-demo
```

### 3. 방화벽 규칙 설정
```bash
# HTTP 트래픽 허용
gcloud compute firewall-rules create allow-http \
    --allow tcp:3000 \
    --source-ranges 0.0.0.0/0 \
    --target-tags github-actions-demo

# SSH 트래픽 허용
gcloud compute firewall-rules create allow-ssh \
    --allow tcp:22 \
    --source-ranges 0.0.0.0/0 \
    --target-tags github-actions-demo
```

## 🔑 SSH 키 설정

### 1. SSH 키 생성
```bash
# SSH 키 생성
ssh-keygen -t rsa -b 4096 -f ~/.ssh/gcp-deployment-key -C "github-actions-demo"

# 공개키를 GCP VM에 추가
gcloud compute instances add-metadata github-actions-demo-gcp \
    --zone=us-central1-a \
    --metadata-from-file ssh-keys=<[echo "ubuntu:$[cat ~/.ssh/gcp-deployment-key.pub]"]
```

### 2. SSH 접속 테스트
```bash
# SSH 접속 테스트
ssh -i ~/.ssh/gcp-deployment-key ubuntu@[GCP_VM_IP]
```

## 🐳 Docker 설치 [GCP VM]

GCP VM에 Docker를 설치합니다:

```bash
# Docker 설치
sudo apt-get update
sudo apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release

curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $[lsb_release -cs] stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io

# Docker 서비스 시작
sudo systemctl start docker
sudo systemctl enable docker

# ubuntu 사용자를 docker 그룹에 추가
sudo usermod -aG docker ubuntu
```

## 🔐 GitHub Secrets 설정

GitHub Repository → Settings → Secrets and variables → Actions에서 다음 Secrets를 추가:

### 필수 Secrets
- `GCP_VM_HOST`: GCP VM의 외부 IP 주소
- `GCP_VM_USERNAME`: `ubuntu`
- `GCP_VM_SSH_KEY`: SSH 개인키 전체 내용
- `DOCKER_USERNAME`: Docker Hub 사용자명
- `DOCKER_PASSWORD`: Docker Hub Personal Access Token


## 🚀 배포 실행

### 1. GitHub Actions를 통한 자동 배포
- `master` 브랜치에 푸시하면 자동으로 GCP VM에 배포됩니다
- 또는 Actions 탭에서 수동으로 워크플로우를 실행할 수 있습니다

### 2. 수동 배포
```bash
# 환경 변수 설정
export GCP_VM_HOST="[GCP_VM_IP]"
export GCP_VM_USERNAME="ubuntu"
export GCP_VM_SSH_KEY="$[cat ~/.ssh/gcp-deployment-key]"
export DOCKER_USERNAME="your-dockerhub-username"
export DOCKER_PASSWORD="your-dockerhub-pat"

# 배포 스크립트 실행
./scripts/deploy-gcp.sh
```

## ✅ 배포 확인

### 1. 애플리케이션 접속
- **메인 페이지**: `http://[GCP_VM_IP]:3000`
- **헬스 체크**: `http://[GCP_VM_IP]:3000/health`
- **메트릭**: `http://[GCP_VM_IP]:3000/metrics`

### 2. 컨테이너 상태 확인
```bash
# GCP VM에 SSH 접속
ssh -i ~/.ssh/gcp-deployment-key ubuntu@[GCP_VM_IP]

# 실행 중인 컨테이너 확인
docker ps

# 애플리케이션 로그 확인
docker logs github-actions-demo
```

## 🔧 문제 해결

### 1. SSH 연결 실패
- 방화벽 규칙 확인
- SSH 키 권한 확인 [`chmod 600 ~/.ssh/gcp-deployment-key`]
- GCP VM 상태 확인

### 2. Docker 이미지 풀 실패
- Docker Hub 로그인 상태 확인
- 네트워크 연결 확인
- 이미지 태그 확인

### 3. 애플리케이션 접속 불가
- 방화벽 규칙 확인 ["포트 3000"]
- 컨테이너 실행 상태 확인
- 애플리케이션 로그 확인

## 📊 모니터링

### 1. GCP Cloud Monitoring
- Compute Engine 인스턴스 모니터링
- 네트워크 트래픽 모니터링
- 디스크 사용량 모니터링

### 2. 애플리케이션 메트릭
- Prometheus 메트릭: `http://[GCP_VM_IP]:3000/metrics`
- 헬스 체크: `http://[GCP_VM_IP]:3000/health`

## 🧹 정리

### 1. 리소스 정리
```bash
# VM 인스턴스 삭제
gcloud compute instances delete github-actions-demo-gcp --zone=us-central1-a

# 방화벽 규칙 삭제
gcloud compute firewall-rules delete allow-http
gcloud compute firewall-rules delete allow-ssh
```

### 2. SSH 키 정리
```bash
# 로컬 SSH 키 삭제
rm ~/.ssh/gcp-deployment-key*
```

## 📚 참고 자료

- ["GCP Compute Engine 문서"][https://cloud.google.com/compute/docs]
- ["Docker 설치 가이드"][https://docs.docker.com/engine/install/ubuntu/]
- ["GitHub Actions 문서"][https://docs.github.com/en/actions]

