#!/bin/bash

# 🚀 배포 스크립트
# 다양한 환경에 애플리케이션을 배포합니다

set -e  # 오류 발생 시 스크립트 중단

# 환경 변수 로드
source scripts/load-env.sh

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 로그 함수
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# 환경 변수
CLOUD_PROVIDER=${1:-local}
RESOURCE_TYPE=${2:-vm}
ENVIRONMENT=${3:-dev}
DOCKER_IMAGE="${DOCKER_IMAGE_NAME}:${DOCKER_TAG}"
CONTAINER_NAME="${PROJECT_NAME}"

# 도움말 표시
show_help() {
    echo "사용법: $0 [클라우드프로바이더] [리소스타입] [환경]"
    echo ""
    echo "클라우드 프로바이더:"
    echo "  local       로컬 환경 (개발용)"
    echo "  aws         Amazon Web Services (EC2)"
    echo "  gcp         Google Cloud Platform (Compute Engine)"
    echo "  azure       Microsoft Azure"
    echo "  multi       멀티 클라우드 (AWS + GCP)"
    echo ""
    echo "리소스 타입:"
    echo "  vm          가상머신 (EC2, Compute Engine, VM)"
    echo "  k8s         Kubernetes 클러스터 (EKS, GKE, AKS)"
    echo "  production  프로덕션 환경 (멀티 클라우드)"
    echo ""
    echo "환경 (선택사항):"
    echo "  dev         개발 환경"
    echo "  staging     스테이징 환경"
    echo "  prod        프로덕션 환경"
    echo ""
    echo "예시:"
    echo "  $0 local vm dev        # 로컬 VM에 개발 환경으로 배포"
    echo "  $0 aws vm dev          # AWS EC2에 개발 환경으로 배포"
    echo "  $0 gcp k8s staging     # GCP GKE에 스테이징 환경으로 배포"
    echo "  $0 aws k8s prod        # AWS EKS에 프로덕션 환경으로 배포"
    echo "  $0 production prod     # 프로덕션 환경에 배포"
    echo ""
    echo "Cloud Master 과정별 배포:"
    echo "  Day 1: $0 aws vm dev      # AWS EC2에 배포"
    echo "  Day 2: $0 gcp k8s staging # GCP GKE에 배포"
    echo "  Day 3: $0 production prod # 프로덕션 환경에 배포"
}

# VM 배포 (Day 1)
deploy_vm() {
    log_info "${CLOUD_PROVIDER} VM에 배포하는 중... (Day 1)"
    
    # 클라우드 프로바이더별 VM 접속 정보 확인
    case $CLOUD_PROVIDER in
        local)
            VM_NAME=${LOCAL_VM_NAME:-local-vm}
            VM_HOST=${LOCAL_VM_HOST:-localhost}
            VM_USERNAME=${LOCAL_VM_USERNAME:-ubuntu}
            VM_SSH_KEY=${LOCAL_VM_SSH_KEY:-~/.ssh/id_rsa}
            ;;
        aws)
            VM_NAME=${AWS_VM_NAME}
            VM_HOST=${AWS_VM_HOST}
            VM_USERNAME=${AWS_VM_USERNAME:-ubuntu}
            VM_SSH_KEY=${AWS_VM_SSH_KEY:-~/.ssh/aws-key.pem}
            VM_INSTANCE_ID=${AWS_VM_INSTANCE_ID}
            ;;
        gcp)
            VM_NAME=${GCP_VM_NAME}
            VM_HOST=${GCP_VM_HOST}
            VM_USERNAME=${GCP_VM_USERNAME:-ubuntu}
            VM_SSH_KEY=${GCP_VM_SSH_KEY:-~/.ssh/gcp-key}
            VM_INSTANCE_NAME=${GCP_VM_INSTANCE_NAME}
            VM_ZONE=${GCP_VM_ZONE}
            ;;
        azure)
            VM_NAME=${AZURE_VM_NAME}
            VM_HOST=${AZURE_VM_HOST}
            VM_USERNAME=${AZURE_VM_USERNAME:-azureuser}
            VM_SSH_KEY=${AZURE_VM_SSH_KEY:-~/.ssh/azure-key}
            VM_RESOURCE_GROUP=${AZURE_VM_RESOURCE_GROUP}
            ;;
        *)
            log_error "지원하지 않는 클라우드 프로바이더: $CLOUD_PROVIDER"
            exit 1
            ;;
    esac
    
    # VM 접속 정보 확인
    if [ -z "$VM_HOST" ] || [ -z "$VM_USERNAME" ]; then
        log_error "${CLOUD_PROVIDER} VM 접속 정보가 설정되지 않았습니다."
        log_info "다음 환경 변수를 설정하세요:"
        case $CLOUD_PROVIDER in
            aws)
                log_info "  export AWS_VM_NAME='your-ec2-instance-name'"
                log_info "  export AWS_VM_INSTANCE_ID='i-1234567890abcdef0'"
                log_info "  export AWS_VM_HOST='your-ec2-ip'"
                log_info "  export AWS_VM_USERNAME='ubuntu'"
                log_info "  export AWS_VM_SSH_KEY='~/.ssh/aws-key.pem'"
                ;;
            gcp)
                log_info "  export GCP_VM_NAME='your-compute-instance-name'"
                log_info "  export GCP_VM_INSTANCE_NAME='your-compute-instance-name'"
                log_info "  export GCP_VM_ZONE='us-central1-a'"
                log_info "  export GCP_VM_HOST='your-compute-engine-ip'"
                log_info "  export GCP_VM_USERNAME='ubuntu'"
                log_info "  export GCP_VM_SSH_KEY='~/.ssh/gcp-key'"
                ;;
            azure)
                log_info "  export AZURE_VM_NAME='your-azure-vm-name'"
                log_info "  export AZURE_VM_RESOURCE_GROUP='your-resource-group'"
                log_info "  export AZURE_VM_HOST='your-azure-vm-ip'"
                log_info "  export AZURE_VM_USERNAME='azureuser'"
                log_info "  export AZURE_VM_SSH_KEY='~/.ssh/azure-key'"
                ;;
        esac
        exit 1
    fi
    
    # VM 리소스 확인 및 정보 출력
    log_info "VM 리소스 정보:"
    log_info "  - VM 이름: $VM_NAME"
    log_info "  - VM 호스트: $VM_HOST"
    log_info "  - VM 사용자: $VM_USERNAME"
    
    # 클라우드 프로바이더별 추가 정보 출력
    case $CLOUD_PROVIDER in
        aws)
            if [ -n "$VM_INSTANCE_ID" ]; then
                log_info "  - 인스턴스 ID: $VM_INSTANCE_ID"
            fi
            ;;
        gcp)
            if [ -n "$VM_INSTANCE_NAME" ]; then
                log_info "  - 인스턴스 이름: $VM_INSTANCE_NAME"
            fi
            if [ -n "$VM_ZONE" ]; then
                log_info "  - 존: $VM_ZONE"
            fi
            ;;
        azure)
            if [ -n "$VM_RESOURCE_GROUP" ]; then
                log_info "  - 리소스 그룹: $VM_RESOURCE_GROUP"
            fi
            ;;
    esac
    
    # Docker 이미지 빌드
    log_info "Docker 이미지 빌드 중..."
    docker build -t $DOCKER_IMAGE .
    
    # VM에 이미지 전송 및 배포
    log_info "${CLOUD_PROVIDER} VM에 이미지 전송 중..."
    docker save $DOCKER_IMAGE | ssh -i ${VM_SSH_KEY} ${VM_USERNAME}@${VM_HOST} "docker load"
    
    # VM에서 컨테이너 실행
    log_info "${CLOUD_PROVIDER} VM에서 컨테이너 실행 중..."
    ssh -i ${VM_SSH_KEY} ${VM_USERNAME}@${VM_HOST} << EOF
        # 기존 컨테이너 중지 및 제거
        docker stop $CONTAINER_NAME 2>/dev/null || true
        docker rm $CONTAINER_NAME 2>/dev/null || true
        
        # 새 컨테이너 실행
        docker run -d \
            --name $CONTAINER_NAME \
            --restart unless-stopped \
            -p 3000:3000 \
            -e NODE_ENV=$ENVIRONMENT \
            -e CLOUD_PROVIDER=$CLOUD_PROVIDER \
            $DOCKER_IMAGE
EOF
    
    # 헬스 체크
    sleep 10
    if curl -f http://${VM_HOST}:3000/health > /dev/null 2>&1; then
        log_success "${CLOUD_PROVIDER} VM 배포 완료! http://${VM_HOST}:3000"
    else
        log_error "${CLOUD_PROVIDER} VM 배포 실패"
        exit 1
    fi
}

# Kubernetes 배포 (Day 2)
deploy_k8s() {
    log_info "${CLOUD_PROVIDER} Kubernetes 클러스터에 배포하는 중... (Day 2)"
    
    # kubectl 설정 확인
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl이 설치되지 않았습니다."
        exit 1
    fi
    
    # 클라우드 프로바이더별 K8s 클러스터 설정
    case $CLOUD_PROVIDER in
        aws)
            K8S_CLUSTER_NAME=${AWS_EKS_CLUSTER_NAME}
            K8S_REGION=${AWS_REGION:-us-west-2}
            K8S_NAMESPACE=${AWS_EKS_NAMESPACE:-github-actions-demo}
            K8S_NODE_GROUP=${AWS_EKS_NODE_GROUP}
            K8S_VPC_ID=${AWS_EKS_VPC_ID}
            ;;
        gcp)
            K8S_CLUSTER_NAME=${GCP_GKE_CLUSTER_NAME}
            K8S_ZONE=${GCP_ZONE:-us-central1-a}
            K8S_NAMESPACE=${GCP_GKE_NAMESPACE:-github-actions-demo}
            K8S_PROJECT_ID=${GCP_PROJECT_ID}
            K8S_NODE_POOL=${GCP_GKE_NODE_POOL}
            ;;
        azure)
            K8S_CLUSTER_NAME=${AZURE_AKS_CLUSTER_NAME}
            K8S_RESOURCE_GROUP=${AZURE_RESOURCE_GROUP}
            K8S_NAMESPACE=${AZURE_AKS_NAMESPACE:-github-actions-demo}
            K8S_NODE_POOL=${AZURE_AKS_NODE_POOL}
            K8S_SUBSCRIPTION_ID=${AZURE_SUBSCRIPTION_ID}
            ;;
        *)
            log_error "지원하지 않는 클라우드 프로바이더: $CLOUD_PROVIDER"
            exit 1
            ;;
    esac
    
    # K8s 클러스터 정보 확인
    if [ -z "$K8S_CLUSTER_NAME" ]; then
        log_error "${CLOUD_PROVIDER} Kubernetes 클러스터 이름이 설정되지 않았습니다."
        log_info "다음 환경 변수를 설정하세요:"
        case $CLOUD_PROVIDER in
            aws)
                log_info "  export AWS_EKS_CLUSTER_NAME='your-eks-cluster-name'"
                log_info "  export AWS_EKS_NODE_GROUP='your-node-group-name'"
                log_info "  export AWS_EKS_VPC_ID='vpc-12345678'"
                log_info "  export AWS_REGION='us-west-2'"
                ;;
            gcp)
                log_info "  export GCP_GKE_CLUSTER_NAME='your-gke-cluster-name'"
                log_info "  export GCP_GKE_NODE_POOL='your-node-pool-name'"
                log_info "  export GCP_PROJECT_ID='your-project-id'"
                log_info "  export GCP_ZONE='us-central1-a'"
                ;;
            azure)
                log_info "  export AZURE_AKS_CLUSTER_NAME='your-aks-cluster-name'"
                log_info "  export AZURE_AKS_NODE_POOL='your-node-pool-name'"
                log_info "  export AZURE_RESOURCE_GROUP='your-resource-group'"
                log_info "  export AZURE_SUBSCRIPTION_ID='your-subscription-id'"
                ;;
        esac
        exit 1
    fi
    
    # K8s 클러스터 접속 확인
    if ! kubectl cluster-info &> /dev/null; then
        log_error "${CLOUD_PROVIDER} Kubernetes 클러스터에 접속할 수 없습니다."
        log_info "다음 명령어로 클러스터에 접속하세요:"
        case $CLOUD_PROVIDER in
            aws)
                log_info "  aws eks update-kubeconfig --region $K8S_REGION --name $K8S_CLUSTER_NAME"
                ;;
            gcp)
                log_info "  gcloud container clusters get-credentials $K8S_CLUSTER_NAME --zone $K8S_ZONE"
                ;;
            azure)
                log_info "  az aks get-credentials --resource-group $K8S_RESOURCE_GROUP --name $K8S_CLUSTER_NAME"
                ;;
        esac
        exit 1
    fi
    
    # K8s 클러스터 리소스 정보 출력
    log_info "Kubernetes 클러스터 리소스 정보:"
    log_info "  - 클러스터 이름: $K8S_CLUSTER_NAME"
    log_info "  - 네임스페이스: $K8S_NAMESPACE"
    
    # 클라우드 프로바이더별 추가 정보 출력
    case $CLOUD_PROVIDER in
        aws)
            log_info "  - 리전: $K8S_REGION"
            if [ -n "$K8S_NODE_GROUP" ]; then
                log_info "  - 노드 그룹: $K8S_NODE_GROUP"
            fi
            if [ -n "$K8S_VPC_ID" ]; then
                log_info "  - VPC ID: $K8S_VPC_ID"
            fi
            ;;
        gcp)
            log_info "  - 존: $K8S_ZONE"
            if [ -n "$K8S_PROJECT_ID" ]; then
                log_info "  - 프로젝트 ID: $K8S_PROJECT_ID"
            fi
            if [ -n "$K8S_NODE_POOL" ]; then
                log_info "  - 노드 풀: $K8S_NODE_POOL"
            fi
            ;;
        azure)
            log_info "  - 리소스 그룹: $K8S_RESOURCE_GROUP"
            if [ -n "$K8S_NODE_POOL" ]; then
                log_info "  - 노드 풀: $K8S_NODE_POOL"
            fi
            if [ -n "$K8S_SUBSCRIPTION_ID" ]; then
                log_info "  - 구독 ID: $K8S_SUBSCRIPTION_ID"
            fi
            ;;
    esac
    
    # 네임스페이스 생성
    kubectl create namespace $K8S_NAMESPACE --dry-run=client -o yaml | kubectl apply -f -
    
    # Docker 이미지 빌드 및 푸시
    log_info "Docker 이미지 빌드 및 푸시 중..."
    docker build -t $DOCKER_IMAGE .
    docker push $DOCKER_IMAGE
    
    # 클라우드 프로바이더별 Kubernetes 매니페스트 생성
    case $CLOUD_PROVIDER in
        aws)
            # AWS EKS용 매니페스트
            cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: $CONTAINER_NAME
  namespace: $K8S_NAMESPACE
spec:
  replicas: 2
  selector:
    matchLabels:
      app: $CONTAINER_NAME
  template:
    metadata:
      labels:
        app: $CONTAINER_NAME
    spec:
      containers:
      - name: $CONTAINER_NAME
        image: $DOCKER_IMAGE
        ports:
        - containerPort: 3000
        env:
        - name: NODE_ENV
          value: "$ENVIRONMENT"
        - name: CLOUD_PROVIDER
          value: "$CLOUD_PROVIDER"
        resources:
          requests:
            memory: "256Mi"
            cpu: "250m"
          limits:
            memory: "512Mi"
            cpu: "500m"
---
apiVersion: v1
kind: Service
metadata:
  name: $CONTAINER_NAME-service
  namespace: $K8S_NAMESPACE
spec:
  selector:
    app: $CONTAINER_NAME
  ports:
  - port: 80
    targetPort: 3000
  type: LoadBalancer
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: $CONTAINER_NAME-ingress
  namespace: $K8S_NAMESPACE
  annotations:
    kubernetes.io/ingress.class: alb
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
spec:
  rules:
  - host: ${AWS_EKS_INGRESS_HOST:-localhost}
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: $CONTAINER_NAME-service
            port:
              number: 80
EOF
            ;;
        gcp)
            # GCP GKE용 매니페스트
            cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: $CONTAINER_NAME
  namespace: $K8S_NAMESPACE
spec:
  replicas: 2
  selector:
    matchLabels:
      app: $CONTAINER_NAME
  template:
    metadata:
      labels:
        app: $CONTAINER_NAME
    spec:
      containers:
      - name: $CONTAINER_NAME
        image: $DOCKER_IMAGE
        ports:
        - containerPort: 3000
        env:
        - name: NODE_ENV
          value: "$ENVIRONMENT"
        - name: CLOUD_PROVIDER
          value: "$CLOUD_PROVIDER"
        resources:
          requests:
            memory: "256Mi"
            cpu: "250m"
          limits:
            memory: "512Mi"
            cpu: "500m"
---
apiVersion: v1
kind: Service
metadata:
  name: $CONTAINER_NAME-service
  namespace: $K8S_NAMESPACE
spec:
  selector:
    app: $CONTAINER_NAME
  ports:
  - port: 80
    targetPort: 3000
  type: LoadBalancer
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: $CONTAINER_NAME-ingress
  namespace: $K8S_NAMESPACE
  annotations:
    kubernetes.io/ingress.class: gce
spec:
  rules:
  - host: ${GCP_GKE_INGRESS_HOST:-localhost}
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: $CONTAINER_NAME-service
            port:
              number: 80
EOF
            ;;
        azure)
            # Azure AKS용 매니페스트
            cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: $CONTAINER_NAME
  namespace: $K8S_NAMESPACE
spec:
  replicas: 2
  selector:
    matchLabels:
      app: $CONTAINER_NAME
  template:
    metadata:
      labels:
        app: $CONTAINER_NAME
    spec:
      containers:
      - name: $CONTAINER_NAME
        image: $DOCKER_IMAGE
        ports:
        - containerPort: 3000
        env:
        - name: NODE_ENV
          value: "$ENVIRONMENT"
        - name: CLOUD_PROVIDER
          value: "$CLOUD_PROVIDER"
        resources:
          requests:
            memory: "256Mi"
            cpu: "250m"
          limits:
            memory: "512Mi"
            cpu: "500m"
---
apiVersion: v1
kind: Service
metadata:
  name: $CONTAINER_NAME-service
  namespace: $K8S_NAMESPACE
spec:
  selector:
    app: $CONTAINER_NAME
  ports:
  - port: 80
    targetPort: 3000
  type: LoadBalancer
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: $CONTAINER_NAME-ingress
  namespace: $K8S_NAMESPACE
  annotations:
    kubernetes.io/ingress.class: azure/application-gateway
spec:
  rules:
  - host: ${AZURE_AKS_INGRESS_HOST:-localhost}
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: $CONTAINER_NAME-service
            port:
              number: 80
EOF
            ;;
    esac
    
    # 배포 상태 확인
    log_info "배포 상태 확인 중..."
    kubectl rollout status deployment/$CONTAINER_NAME -n $K8S_NAMESPACE
    
    # 서비스 정보 출력
    log_success "${CLOUD_PROVIDER} K8s 배포 완료!"
    kubectl get svc -n $K8S_NAMESPACE
    kubectl get ingress -n $K8S_NAMESPACE
}

# 로컬 배포 (개발용)
deploy_local() {
    log_info "로컬 환경에 배포하는 중... (개발용)"
    
    # 기존 컨테이너 중지 및 제거
    docker stop $CONTAINER_NAME 2>/dev/null || true
    docker rm $CONTAINER_NAME 2>/dev/null || true
    
    # 새 컨테이너 실행
    docker run -d \
        --name $CONTAINER_NAME \
        --restart unless-stopped \
        -p ${APP_PORT}:${APP_PORT} \
        -e NODE_ENV=$ENVIRONMENT \
        $DOCKER_IMAGE
    
    # 헬스 체크
    sleep 5
    if curl -f http://${APP_HOST}:${APP_PORT}/health > /dev/null 2>&1; then
        log_success "로컬 배포 완료! http://${APP_HOST}:${APP_PORT}"
    else
        log_error "로컬 배포 실패"
        exit 1
    fi
}

# 스테이징 배포
deploy_staging() {
    log_info "스테이징 환경에 배포하는 중..."
    
    # Docker Hub에서 이미지 풀
    docker pull $DOCKER_IMAGE
    
    # 기존 컨테이너 중지 및 제거
    docker stop $CONTAINER_NAME-staging 2>/dev/null || true
    docker rm $CONTAINER_NAME-staging 2>/dev/null || true
    
    # 새 컨테이너 실행
    docker run -d \
        --name $CONTAINER_NAME-staging \
        --restart unless-stopped \
        -p 3001:3000 \
        -e NODE_ENV=staging \
        $DOCKER_IMAGE
    
    # 헬스 체크
    sleep 10
    if curl -f http://localhost:3001/health > /dev/null 2>&1; then
        log_success "스테이징 배포 완료! http://localhost:3001"
    else
        log_error "스테이징 배포 실패"
        exit 1
    fi
}

# 프로덕션 배포
deploy_production() {
    log_info "프로덕션 환경에 배포하는 중..."
    
    # 확인 메시지
    read -p "정말로 프로덕션 환경에 배포하시겠습니까? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "프로덕션 배포가 취소되었습니다."
        exit 0
    fi
    
    # Docker Hub에서 이미지 풀
    docker pull $DOCKER_IMAGE
    
    # 기존 컨테이너 중지 및 제거
    docker stop $CONTAINER_NAME-prod 2>/dev/null || true
    docker rm $CONTAINER_NAME-prod 2>/dev/null || true
    
    # 새 컨테이너 실행
    docker run -d \
        --name $CONTAINER_NAME-prod \
        --restart unless-stopped \
        -p 80:3000 \
        -e NODE_ENV=production \
        $DOCKER_IMAGE
    
    # 헬스 체크
    sleep 15
    if curl -f http://localhost/health > /dev/null 2>&1; then
        log_success "프로덕션 배포 완료! http://localhost"
    else
        log_error "프로덕션 배포 실패"
        exit 1
    fi
}

# 롤백
rollback() {
    log_info "이전 버전으로 롤백하는 중..."
    
    # 이전 이미지 태그 (예: latest-1)
    PREVIOUS_IMAGE="github-actions-demo:latest-1"
    
    # 이전 이미지가 있는지 확인
    if ! docker image inspect $PREVIOUS_IMAGE > /dev/null 2>&1; then
        log_error "이전 이미지를 찾을 수 없습니다: $PREVIOUS_IMAGE"
        exit 1
    fi
    
    # 현재 컨테이너 중지
    docker stop $CONTAINER_NAME-$ENVIRONMENT 2>/dev/null || true
    docker rm $CONTAINER_NAME-$ENVIRONMENT 2>/dev/null || true
    
    # 이전 이미지로 실행
    docker run -d \
        --name $CONTAINER_NAME-$ENVIRONMENT \
        --restart unless-stopped \
        -p 3000:3000 \
        -e NODE_ENV=$ENVIRONMENT \
        $PREVIOUS_IMAGE
    
    log_success "롤백 완료!"
}

# 인증 확인
check_authentication() {
    log_info "인증 상태를 확인하는 중..."
    
    if ! ./scripts/check-auth.sh; then
        log_error "인증 확인 실패. 필요한 인증을 완료한 후 다시 시도하세요."
        exit 1
    fi
    
    log_success "인증 확인 완료!"
}

# 메인 실행
main() {
    # help 명령어는 인증 확인 없이 실행
    if [ "$1" = "help" ] || [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
        show_help
        return
    fi
    
    # 인증 확인
    check_authentication
    
    # 리소스 타입에 따른 배포 실행
    case $RESOURCE_TYPE in
        vm)
            deploy_vm
            ;;
        k8s)
            deploy_k8s
            ;;
        production)
            deploy_production
            ;;
        *)
            log_error "알 수 없는 리소스 타입: $RESOURCE_TYPE"
            show_help
            exit 1
            ;;
    esac
}

# 스크립트 실행
main "$@"
