#!/bin/bash
# Master → Container 과정 연계 브리지 스크립트
# Cloud Master 과정에서 생성된 리소스를 Cloud Container 과정에서 활용할 수 있도록 설정

set -e

echo "🔗 Cloud Master → Cloud Container 연계 설정 시작..."

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 로그 함수
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 공유 리소스 디렉토리 확인
SHARED_DIR="../../shared_resources"
if [ ! -d "$SHARED_DIR" ]; then
    log_error "공유 리소스 디렉토리를 찾을 수 없습니다: $SHARED_DIR"
    exit 1
fi

# 1. Master 과정에서 생성된 Docker 리소스 확인
log_info "Docker 리소스 상태 확인 중..."
if command -v docker &> /dev/null; then
    # Docker 이미지 목록 확인
    DOCKER_IMAGES=$(docker images --format "table {{.Repository}}:{{.Tag}}" | grep -v "REPOSITORY" | head -10)
    if [ -n "$DOCKER_IMAGES" ]; then
        log_success "Docker 이미지 발견:"
        echo "$DOCKER_IMAGES" | while read -r image; do
            echo "  - $image"
        done
        
        # 이미지 정보를 JSON으로 저장
        docker images --format "{{json .}}" | jq -s '.' > "$SHARED_DIR/docker_images.json" 2>/dev/null || {
            log_warning "jq가 설치되지 않아 이미지 정보를 JSON으로 저장할 수 없습니다."
        }
    else
        log_warning "Docker 이미지를 찾을 수 없습니다."
    fi
    
    # Docker 컨테이너 상태 확인
    RUNNING_CONTAINERS=$(docker ps --format "{{.Names}}" | wc -l)
    if [ "$RUNNING_CONTAINERS" -gt 0 ]; then
        log_success "실행 중인 컨테이너: $RUNNING_CONTAINERS개"
        docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}" | head -5
    else
        log_info "실행 중인 컨테이너가 없습니다."
    fi
else
    log_warning "Docker가 설치되지 않았습니다."
fi

# 2. GitHub 저장소 정보 확인
log_info "GitHub 저장소 정보 확인 중..."
if command -v gh &> /dev/null; then
    # GitHub CLI 인증 상태 확인
    if gh auth status &> /dev/null; then
        log_success "GitHub CLI 인증 완료"
        
        # 현재 사용자 정보 확인
        GITHUB_USER=$(gh api user --jq .login 2>/dev/null || echo "")
        if [ -n "$GITHUB_USER" ]; then
            log_success "GitHub 사용자: $GITHUB_USER"
            echo "GITHUB_USER=$GITHUB_USER" > "$SHARED_DIR/github_resources.env"
            
            # 저장소 목록 확인
            REPOS=$(gh repo list --limit 5 --json name --jq '.[].name' 2>/dev/null || echo "")
            if [ -n "$REPOS" ]; then
                log_success "GitHub 저장소 발견:"
                echo "$REPOS" | while read -r repo; do
                    echo "  - $repo"
                done
            fi
        fi
    else
        log_warning "GitHub CLI 인증이 필요합니다. 'gh auth login'을 실행하세요."
    fi
else
    log_warning "GitHub CLI가 설치되지 않았습니다."
fi

# 3. CI/CD 파이프라인 상태 확인
log_info "CI/CD 파이프라인 상태 확인 중..."
if [ -d ".github/workflows" ]; then
    WORKFLOW_FILES=$(find .github/workflows -name "*.yml" -o -name "*.yaml" | wc -l)
    if [ "$WORKFLOW_FILES" -gt 0 ]; then
        log_success "GitHub Actions 워크플로우 발견: $WORKFLOW_FILES개"
        find .github/workflows -name "*.yml" -o -name "*.yaml" | while read -r workflow; do
            echo "  - $(basename "$workflow")"
        done
    else
        log_warning "GitHub Actions 워크플로우를 찾을 수 없습니다."
    fi
else
    log_warning ".github/workflows 디렉토리를 찾을 수 없습니다."
fi

# 4. Kubernetes 환경 준비
log_info "Kubernetes 환경 준비 중..."
if command -v kubectl &> /dev/null; then
    # kubectl 설정 확인
    if kubectl cluster-info &> /dev/null; then
        log_success "Kubernetes 클러스터 연결됨"
        
        # 클러스터 정보 저장
        kubectl cluster-info > "$SHARED_DIR/kubernetes_cluster_info.txt" 2>/dev/null || true
        
        # 노드 정보 확인
        NODE_COUNT=$(kubectl get nodes --no-headers | wc -l)
        log_success "Kubernetes 노드 수: $NODE_COUNT"
        
        # 네임스페이스 확인
        NAMESPACES=$(kubectl get namespaces --no-headers | awk '{print $1}' | grep -v "kube-")
        if [ -n "$NAMESPACES" ]; then
            log_success "사용자 네임스페이스:"
            echo "$NAMESPACES" | while read -r ns; do
                echo "  - $ns"
            done
        fi
    else
        log_warning "Kubernetes 클러스터에 연결할 수 없습니다."
    fi
else
    log_warning "kubectl이 설치되지 않았습니다."
fi

# 5. Helm 환경 준비
log_info "Helm 환경 준비 중..."
if command -v helm &> /dev/null; then
    # Helm 버전 확인
    HELM_VERSION=$(helm version --short 2>/dev/null || echo "unknown")
    log_success "Helm 버전: $HELM_VERSION"
    
    # Helm 차트 저장소 확인
    if helm repo list &> /dev/null; then
        REPO_COUNT=$(helm repo list | wc -l)
        log_success "Helm 저장소 수: $((REPO_COUNT - 1))"
    fi
else
    log_warning "Helm이 설치되지 않았습니다."
fi

# 6. AWS EKS 클러스터 확인
log_info "AWS EKS 클러스터 확인 중..."
if command -v aws &> /dev/null; then
    # EKS 클러스터 목록 확인
    EKS_CLUSTERS=$(aws eks list-clusters --query 'clusters[]' --output text 2>/dev/null || echo "")
    if [ -n "$EKS_CLUSTERS" ]; then
        log_success "EKS 클러스터 발견:"
        echo "$EKS_CLUSTERS" | while read -r cluster; do
            echo "  - $cluster"
        done
        echo "EKS_CLUSTERS=$EKS_CLUSTERS" > "$SHARED_DIR/eks_resources.env"
    else
        log_info "EKS 클러스터를 찾을 수 없습니다."
    fi
else
    log_warning "AWS CLI가 설치되지 않았습니다."
fi

# 7. GCP GKE 클러스터 확인
log_info "GCP GKE 클러스터 확인 중..."
if command -v gcloud &> /dev/null; then
    # GKE 클러스터 목록 확인
    GKE_CLUSTERS=$(gcloud container clusters list --format="value(name)" 2>/dev/null || echo "")
    if [ -n "$GKE_CLUSTERS" ]; then
        log_success "GKE 클러스터 발견:"
        echo "$GKE_CLUSTERS" | while read -r cluster; do
            echo "  - $cluster"
        done
        echo "GKE_CLUSTERS=$GKE_CLUSTERS" > "$SHARED_DIR/gke_resources.env"
    else
        log_info "GKE 클러스터를 찾을 수 없습니다."
    fi
else
    log_warning "GCP CLI가 설치되지 않았습니다."
fi

# 8. Container 과정용 설정 파일 생성
log_info "Container 과정용 설정 파일 생성 중..."
cat > "$SHARED_DIR/container_course_config.env" << EOF
# Cloud Container 과정 설정
# Master 과정에서 전달받은 리소스 정보

# Docker 리소스
export DOCKER_REGISTRY="docker.io"
export DOCKER_IMAGES_FILE="$SHARED_DIR/docker_images.json"

# GitHub 리소스
export GITHUB_USER=${GITHUB_USER:-""}
export GITHUB_ORG="cloud-training-org"

# Kubernetes 리소스
export KUBECONFIG=${KUBECONFIG:-"$HOME/.kube/config"}
export KUBERNETES_NAMESPACE="cloud-training"

# EKS 리소스
export EKS_CLUSTERS="${EKS_CLUSTERS:-""}"

# GKE 리소스
export GKE_CLUSTERS="${GKE_CLUSTERS:-""}"

# Container 과정에서 사용할 추가 설정
export ENABLE_ISTIO=true
export ENABLE_MONITORING=true
export ENABLE_LOGGING=true
export ENABLE_TRACING=true
export ENABLE_SERVICE_MESH=true

# 고가용성 설정
export ENABLE_HA=true
export REPLICA_COUNT=3
export ENABLE_AUTO_SCALING=true
export MIN_REPLICAS=2
export MAX_REPLICAS=10

# 보안 설정
export ENABLE_RBAC=true
export ENABLE_NETWORK_POLICIES=true
export ENABLE_POD_SECURITY_POLICIES=true
EOF

log_success "Container 과정 설정 파일 생성 완료: $SHARED_DIR/container_course_config.env"

# 9. 연계 상태 저장
log_info "연계 상태 저장 중..."
cat > "$SHARED_DIR/master_to_container_bridge_status.json" << EOF
{
  "bridge_name": "master_to_container",
  "completed_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "docker_resources": {
    "images_count": $(docker images --format "{{.Repository}}" | wc -l),
    "containers_count": $(docker ps -a --format "{{.Names}}" | wc -l)
  },
  "github_resources": {
    "user": "${GITHUB_USER:-null}",
    "repos_count": $(gh repo list --json name --jq 'length' 2>/dev/null || echo "0")
  },
  "kubernetes_resources": {
    "cluster_connected": $(kubectl cluster-info &> /dev/null && echo "true" || echo "false"),
    "nodes_count": $(kubectl get nodes --no-headers 2>/dev/null | wc -l || echo "0")
  },
  "eks_clusters": "${EKS_CLUSTERS:-""}",
  "gke_clusters": "${GKE_CLUSTERS:-""}",
  "status": "completed"
}
EOF

log_success "연계 상태 저장 완료"

# 10. Container 과정 실행 준비
log_info "Container 과정 실행 준비 중..."
CONTAINER_SCRIPT="../../cloud_container/automation_tests/container_course_automation.py"
if [ -f "$CONTAINER_SCRIPT" ]; then
    log_success "Container 과정 스크립트 발견: $CONTAINER_SCRIPT"
    log_info "Container 과정을 실행하려면 다음 명령어를 사용하세요:"
    echo "  cd ../../cloud_container/automation_tests"
    echo "  source ../../integrated_automation/shared_resources/container_course_config.env"
    echo "  python container_course_automation.py"
else
    log_warning "Container 과정 스크립트를 찾을 수 없습니다: $CONTAINER_SCRIPT"
fi

log_success "🎉 Cloud Master → Cloud Container 연계 설정 완료!"
log_info "다음 단계: Container 과정 실행"
