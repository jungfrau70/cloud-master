#!/bin/bash

# Kubernetes 도구 설치 스크립트 (WSL 환경용)
# kubectl, helm, k9s 등 Kubernetes 관련 도구들을 설치합니다.

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

log_info "=== Kubernetes 도구 설치 시작 ==="

# 1. kubectl 설치
log_info "kubectl 설치 중..."
if ! command -v kubectl &> /dev/null; then
    # 최신 kubectl 버전 다운로드
    KUBECTL_VERSION=$(curl -L -s https://dl.k8s.io/release/stable.txt)
    curl -LO "https://dl.k8s.io/release/$KUBECTL_VERSION/bin/linux/amd64/kubectl"
    
    # kubectl 설치
    sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
    rm kubectl
    
    log_success "kubectl 설치 완료"
else
    log_info "kubectl이 이미 설치되어 있습니다: $(kubectl version --client --short)"
fi

# 2. Helm 설치
log_info "Helm 설치 중..."
if ! command -v helm &> /dev/null; then
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
    log_success "Helm 설치 완료"
else
    log_info "Helm이 이미 설치되어 있습니다: $(helm version --short)"
fi

# 3. k9s 설치 (Kubernetes 클러스터 관리 도구)
log_info "k9s 설치 중..."
if ! command -v k9s &> /dev/null; then
    # k9s 최신 버전 다운로드
    K9S_VERSION=$(curl -s https://api.github.com/repos/derailed/k9s/releases/latest | grep tag_name | cut -d '"' -f 4)
    wget https://github.com/derailed/k9s/releases/download/$K9S_VERSION/k9s_Linux_amd64.tar.gz
    
    # k9s 설치
    tar -xzf k9s_Linux_amd64.tar.gz
    sudo mv k9s /usr/local/bin/
    rm k9s_Linux_amd64.tar.gz LICENSE README.md
    
    log_success "k9s 설치 완료"
else
    log_info "k9s가 이미 설치되어 있습니다: $(k9s version --short)"
fi

# 4. kustomize 설치
log_info "kustomize 설치 중..."
if ! command -v kustomize &> /dev/null; then
    # kustomize 최신 버전 다운로드
    KUSTOMIZE_VERSION=$(curl -s https://api.github.com/repos/kubernetes-sigs/kustomize/releases/latest | grep tag_name | cut -d '"' -f 4)
    wget https://github.com/kubernetes-sigs/kustomize/releases/download/$KUSTOMIZE_VERSION/kustomize_${KUSTOMIZE_VERSION}_linux_amd64.tar.gz
    
    # kustomize 설치
    tar -xzf kustomize_${KUSTOMIZE_VERSION}_linux_amd64.tar.gz
    sudo mv kustomize /usr/local/bin/
    rm kustomize_${KUSTOMIZE_VERSION}_linux_amd64.tar.gz
    
    log_success "kustomize 설치 완료"
else
    log_info "kustomize가 이미 설치되어 있습니다: $(kustomize version --short)"
fi

# 5. stern 설치 (Kubernetes 로그 도구)
log_info "stern 설치 중..."
if ! command -v stern &> /dev/null; then
    # stern 최신 버전 다운로드
    STERN_VERSION=$(curl -s https://api.github.com/repos/stern/stern/releases/latest | grep tag_name | cut -d '"' -f 4)
    wget https://github.com/stern/stern/releases/download/$STERN_VERSION/stern_${STERN_VERSION}_linux_amd64.tar.gz
    
    # stern 설치
    tar -xzf stern_${STERN_VERSION}_linux_amd64.tar.gz
    sudo mv stern /usr/local/bin/
    rm stern_${STERN_VERSION}_linux_amd64.tar.gz
    
    log_success "stern 설치 완료"
else
    log_info "stern이 이미 설치되어 있습니다: $(stern --version)"
fi

# 6. kubectx 및 kubens 설치
log_info "kubectx 및 kubens 설치 중..."
if ! command -v kubectx &> /dev/null; then
    # kubectx 설치
    wget https://raw.githubusercontent.com/ahmetb/kubectx/master/kubectx
    chmod +x kubectx
    sudo mv kubectx /usr/local/bin/
    
    # kubens 설치
    wget https://raw.githubusercontent.com/ahmetb/kubectx/master/kubens
    chmod +x kubens
    sudo mv kubens /usr/local/bin/
    
    log_success "kubectx 및 kubens 설치 완료"
else
    log_info "kubectx가 이미 설치되어 있습니다: $(kubectx --version)"
fi

# 7. 설치 확인
log_info "=== 설치된 Kubernetes 도구 버전 확인 ==="
echo "kubectl: $(kubectl version --client --short 2>/dev/null || echo '설치되지 않음')"
echo "helm: $(helm version --short 2>/dev/null || echo '설치되지 않음')"
echo "k9s: $(k9s version --short 2>/dev/null || echo '설치되지 않음')"
echo "kustomize: $(kustomize version --short 2>/dev/null || echo '설치되지 않음')"
echo "stern: $(stern --version 2>/dev/null || echo '설치되지 않음')"
echo "kubectx: $(kubectx --version 2>/dev/null || echo '설치되지 않음')"
echo "kubens: $(kubens --version 2>/dev/null || echo '설치되지 않음')"

# 8. 사용법 안내
log_info "=== Kubernetes 도구 사용법 안내 ==="
log_info "kubectl: Kubernetes 클러스터 관리"
echo "  kubectl get pods"
echo "  kubectl get nodes"
echo "  kubectl apply -f deployment.yaml"
echo ""

log_info "helm: Kubernetes 패키지 관리"
echo "  helm list"
echo "  helm install my-release stable/nginx"
echo "  helm upgrade my-release stable/nginx"
echo ""

log_info "k9s: Kubernetes 클러스터 대화형 관리"
echo "  k9s"
echo ""

log_info "stern: 여러 Pod의 로그 동시 확인"
echo "  stern my-app"
echo "  stern -l app=nginx"
echo ""

log_info "kubectx: Kubernetes 컨텍스트 전환"
echo "  kubectx                    # 컨텍스트 목록"
echo "  kubectx my-cluster         # 컨텍스트 전환"
echo ""

log_info "kubens: Kubernetes 네임스페이스 전환"
echo "  kubens                     # 네임스페이스 목록"
echo "  kubens my-namespace        # 네임스페이스 전환"
echo ""

log_success "Kubernetes 도구 설치 스크립트 완료"
