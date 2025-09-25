#!/bin/bash

# 고가용성 배포 스크립트
# AWS ELB + Auto Scaling Group + GCP Cloud Load Balancing + MIG 통합 배포

set -e

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 로깅 함수
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 환경 변수 설정
export AWS_DEFAULT_REGION=${AWS_DEFAULT_REGION:-ap-northeast-2}
export GCP_PROJECT_ID=${GCP_PROJECT_ID:-your-project-id}
export GCP_ZONE=${GCP_ZONE:-asia-northeast3-a}
export PROJECT_NAME=${PROJECT_NAME:-my-app-ha}
export VPC_CIDR=${VPC_CIDR:-10.0.0.0/16}
export SUBNET_1_CIDR=${SUBNET_1_CIDR:-10.0.1.0/24}
export SUBNET_2_CIDR=${SUBNET_2_CIDR:-10.0.2.0/24}

# 함수 정의
check_prerequisites() {
    log "사전 요구사항 확인 중..."
    
    # AWS CLI 확인
    if ! command -v aws &> /dev/null; then
        error "AWS CLI가 설치되지 않았습니다."
        exit 1
    fi
    
    # GCP CLI 확인
    if ! command -v gcloud &> /dev/null; then
        error "Google Cloud CLI가 설치되지 않았습니다."
        exit 1
    fi
    
    # kubectl 확인
    if ! command -v kubectl &> /dev/null; then
        error "kubectl이 설치되지 않았습니다."
        exit 1
    fi
    
    # Terraform 확인
    if ! command -v terraform &> /dev/null; then
        error "Terraform이 설치되지 않았습니다."
        exit 1
    fi
    
    success "모든 사전 요구사항이 충족되었습니다."
}

deploy_aws_infrastructure() {
    log "AWS 인프라 배포 시작..."
    
    cd infrastructure/aws/terraform
    
    # Terraform 초기화
    terraform init
    
    # Terraform 계획
    terraform plan -var="project_name=$PROJECT_NAME" \
                   -var="vpc_cidr=$VPC_CIDR" \
                   -var="subnet_1_cidr=$SUBNET_1_CIDR" \
                   -var="subnet_2_cidr=$SUBNET_2_CIDR"
    
    # Terraform 적용
    terraform apply -auto-approve \
                   -var="project_name=$PROJECT_NAME" \
                   -var="vpc_cidr=$VPC_CIDR" \
                   -var="subnet_1_cidr=$SUBNET_1_CIDR" \
                   -var="subnet_2_cidr=$SUBNET_2_CIDR"
    
    # 출력 값 가져오기
    ALB_DNS=$(terraform output -raw alb_dns_name)
    ASG_NAME=$(terraform output -raw asg_name)
    
    success "AWS 인프라 배포 완료"
    log "ALB DNS: $ALB_DNS"
    log "ASG Name: $ASG_NAME"
    
    cd ../../..
}

deploy_gcp_infrastructure() {
    log "GCP 인프라 배포 시작..."
    
    # GCP 프로젝트 설정
    gcloud config set project $GCP_PROJECT_ID
    
    cd infrastructure/gcp/terraform
    
    # Terraform 초기화
    terraform init
    
    # Terraform 계획
    terraform plan -var="project_id=$GCP_PROJECT_ID" \
                   -var="zone=$GCP_ZONE" \
                   -var="project_name=$PROJECT_NAME"
    
    # Terraform 적용
    terraform apply -auto-approve \
                   -var="project_id=$GCP_PROJECT_ID" \
                   -var="zone=$GCP_ZONE" \
                   -var="project_name=$PROJECT_NAME"
    
    # 출력 값 가져오기
    LB_IP=$(terraform output -raw load_balancer_ip)
    MIG_NAME=$(terraform output -raw mig_name)
    
    success "GCP 인프라 배포 완료"
    log "Load Balancer IP: $LB_IP"
    log "MIG Name: $MIG_NAME"
    
    cd ../../..
}

deploy_kubernetes() {
    log "Kubernetes 애플리케이션 배포 시작..."
    
    # 네임스페이스 생성
    kubectl create namespace $PROJECT_NAME --dry-run=client -o yaml | kubectl apply -f -
    
    # ConfigMap 생성
    kubectl apply -f k8s/configmap.yaml -n $PROJECT_NAME
    
    # Secret 생성
    kubectl apply -f k8s/secret.yaml -n $PROJECT_NAME
    
    # Deployment 생성
    kubectl apply -f k8s/deployment.yaml -n $PROJECT_NAME
    
    # Service 생성
    kubectl apply -f k8s/service.yaml -n $PROJECT_NAME
    
    # Ingress 생성
    kubectl apply -f k8s/ingress.yaml -n $PROJECT_NAME
    
    # 배포 상태 확인
    kubectl rollout status deployment/$PROJECT_NAME -n $PROJECT_NAME --timeout=300s
    
    success "Kubernetes 애플리케이션 배포 완료"
}

setup_monitoring() {
    log "모니터링 설정 시작..."
    
    # Prometheus 배포
    kubectl apply -f monitoring/prometheus/ -n $PROJECT_NAME
    
    # Grafana 배포
    kubectl apply -f monitoring/grafana/ -n $PROJECT_NAME
    
    # AlertManager 배포
    kubectl apply -f monitoring/alertmanager/ -n $PROJECT_NAME
    
    # 모니터링 서비스 확인
    kubectl rollout status deployment/prometheus -n $PROJECT_NAME --timeout=300s
    kubectl rollout status deployment/grafana -n $PROJECT_NAME --timeout=300s
    
    success "모니터링 설정 완료"
}

run_health_checks() {
    log "헬스 체크 실행 중..."
    
    # AWS ALB 헬스 체크
    if [ ! -z "$ALB_DNS" ]; then
        log "AWS ALB 헬스 체크: http://$ALB_DNS"
        for i in {1..10}; do
            if curl -f -s http://$ALB_DNS/health > /dev/null; then
                success "AWS ALB 헬스 체크 성공"
                break
            else
                warning "AWS ALB 헬스 체크 실패 (시도 $i/10)"
                sleep 10
            fi
        done
    fi
    
    # GCP Load Balancer 헬스 체크
    if [ ! -z "$LB_IP" ]; then
        log "GCP Load Balancer 헬스 체크: http://$LB_IP"
        for i in {1..10}; do
            if curl -f -s http://$LB_IP/health > /dev/null; then
                success "GCP Load Balancer 헬스 체크 성공"
                break
            else
                warning "GCP Load Balancer 헬스 체크 실패 (시도 $i/10)"
                sleep 10
            fi
        done
    fi
    
    # Kubernetes Pod 상태 확인
    kubectl get pods -n $PROJECT_NAME
    kubectl get services -n $PROJECT_NAME
    kubectl get ingress -n $PROJECT_NAME
}

run_load_test() {
    log "부하 테스트 실행 중..."
    
    # Apache Bench를 사용한 부하 테스트
    if command -v ab &> /dev/null; then
        if [ ! -z "$ALB_DNS" ]; then
            log "AWS ALB 부하 테스트 실행..."
            ab -n 1000 -c 10 http://$ALB_DNS/ > load_test_aws.log 2>&1
            success "AWS ALB 부하 테스트 완료"
        fi
        
        if [ ! -z "$LB_IP" ]; then
            log "GCP Load Balancer 부하 테스트 실행..."
            ab -n 1000 -c 10 http://$LB_IP/ > load_test_gcp.log 2>&1
            success "GCP Load Balancer 부하 테스트 완료"
        fi
    else
        warning "Apache Bench가 설치되지 않았습니다. 부하 테스트를 건너뜁니다."
    fi
}

cleanup() {
    log "정리 작업 실행 중..."
    
    # AWS 리소스 정리 (선택사항)
    if [ "$1" = "--cleanup" ]; then
        log "AWS 리소스 정리 중..."
        cd infrastructure/aws/terraform
        terraform destroy -auto-approve
        cd ../../..
        
        log "GCP 리소스 정리 중..."
        cd infrastructure/gcp/terraform
        terraform destroy -auto-approve
        cd ../../..
        
        log "Kubernetes 리소스 정리 중..."
        kubectl delete namespace $PROJECT_NAME
    fi
}

# 메인 실행
main() {
    log "고가용성 배포 스크립트 시작"
    log "프로젝트: $PROJECT_NAME"
    log "AWS 리전: $AWS_DEFAULT_REGION"
    log "GCP 프로젝트: $GCP_PROJECT_ID"
    log "GCP 존: $GCP_ZONE"
    
    # 사전 요구사항 확인
    check_prerequisites
    
    # AWS 인프라 배포
    deploy_aws_infrastructure
    
    # GCP 인프라 배포
    deploy_gcp_infrastructure
    
    # Kubernetes 애플리케이션 배포
    deploy_kubernetes
    
    # 모니터링 설정
    setup_monitoring
    
    # 헬스 체크 실행
    run_health_checks
    
    # 부하 테스트 실행
    run_load_test
    
    success "고가용성 배포 완료!"
    
    # 정리 작업 (옵션)
    if [ "$1" = "--cleanup" ]; then
        cleanup --cleanup
    fi
}

# 스크립트 실행
main "$@"
