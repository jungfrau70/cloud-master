#!/bin/bash

# Cloud Master Day3 - 로드밸런싱 실습 자동화 스크립트
# 작성일: 2024년 9월 22일
# 목적: AWS ALB, GCP Cloud Load Balancing 자동 설정 및 테스트

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# 로그 함수
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_header() { echo -e "${PURPLE}=== $1 ===${NC}"; }

# 설정 변수
PROJECT_NAME="cloud-master-day3"
AWS_REGION="us-west-2"
GCP_ZONE="us-central1-a"
GCP_REGION="us-central1"

# AWS 설정
AWS_VPC_ID=""
AWS_SUBNET_1=""
AWS_SUBNET_2=""
AWS_SECURITY_GROUP=""

# GCP 설정
GCP_PROJECT_ID=""
GCP_NETWORK="default"

# 함수 정의
check_prerequisites() {
    log_header "사전 요구사항 확인"
    
    # AWS CLI 확인
    if ! command -v aws &> /dev/null; then
        log_error "AWS CLI가 설치되지 않았습니다."
        exit 1
    fi
    
    # GCP CLI 확인
    if ! command -v gcloud &> /dev/null; then
        log_error "GCP CLI가 설치되지 않았습니다."
        exit 1
    fi
    
    # Docker 확인
    if ! command -v docker &> /dev/null; then
        log_error "Docker가 설치되지 않았습니다."
        exit 1
    fi
    
    log_success "모든 필수 도구가 설치되어 있습니다."
}

get_aws_resources() {
    log_header "AWS 리소스 정보 수집"
    
    # VPC ID 가져오기
    AWS_VPC_ID=$(aws ec2 describe-vpcs --filters "Name=is-default,Values=true" --query 'Vpcs[0].VpcId' --output text)
    if [ "$AWS_VPC_ID" = "None" ] || [ -z "$AWS_VPC_ID" ]; then
        log_error "기본 VPC를 찾을 수 없습니다."
        exit 1
    fi
    log_info "VPC ID: $AWS_VPC_ID"
    
    # 서브넷 ID 가져오기
    AWS_SUBNET_1=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$AWS_VPC_ID" --query 'Subnets[0].SubnetId' --output text)
    AWS_SUBNET_2=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$AWS_VPC_ID" --query 'Subnets[1].SubnetId' --output text)
    log_info "서브넷 1: $AWS_SUBNET_1"
    log_info "서브넷 2: $AWS_SUBNET_2"
    
    # 보안 그룹 생성
    AWS_SECURITY_GROUP=$(aws ec2 create-security-group \
        --group-name "$PROJECT_NAME-alb-sg" \
        --description "Security group for ALB" \
        --vpc-id "$AWS_VPC_ID" \
        --query 'GroupId' --output text)
    
    # 보안 그룹 규칙 추가
    aws ec2 authorize-security-group-ingress \
        --group-id "$AWS_SECURITY_GROUP" \
        --protocol tcp \
        --port 80 \
        --cidr 0.0.0.0/0
    
    aws ec2 authorize-security-group-ingress \
        --group-id "$AWS_SECURITY_GROUP" \
        --protocol tcp \
        --port 443 \
        --cidr 0.0.0.0/0
    
    log_success "AWS 리소스 정보 수집 완료"
}

get_gcp_resources() {
    log_header "GCP 리소스 정보 수집"
    
    # GCP 프로젝트 ID 가져오기
    GCP_PROJECT_ID=$(gcloud config get-value project)
    if [ -z "$GCP_PROJECT_ID" ]; then
        log_error "GCP 프로젝트가 설정되지 않았습니다."
        exit 1
    fi
    log_info "GCP 프로젝트 ID: $GCP_PROJECT_ID"
    
    # 네트워크 확인
    GCP_NETWORK=$(gcloud compute networks list --filter="name:default" --format="value(name)")
    log_info "GCP 네트워크: $GCP_NETWORK"
    
    log_success "GCP 리소스 정보 수집 완료"
}

setup_aws_alb() {
    log_header "AWS ALB 설정"
    
    # ALB 생성
    log_info "ALB 생성 중..."
    ALB_ARN=$(aws elbv2 create-load-balancer \
        --name "$PROJECT_NAME-alb" \
        --subnets "$AWS_SUBNET_1" "$AWS_SUBNET_2" \
        --security-groups "$AWS_SECURITY_GROUP" \
        --query 'LoadBalancers[0].LoadBalancerArn' --output text)
    
    if [ "$ALB_ARN" = "None" ] || [ -z "$ALB_ARN" ]; then
        log_error "ALB 생성 실패"
        exit 1
    fi
    
    log_success "ALB 생성 완료: $ALB_ARN"
    
    # Target Group 생성
    log_info "Target Group 생성 중..."
    TARGET_GROUP_ARN=$(aws elbv2 create-target-group \
        --name "$PROJECT_NAME-targets" \
        --protocol HTTP \
        --port 3000 \
        --vpc-id "$AWS_VPC_ID" \
        --query 'TargetGroups[0].TargetGroupArn' --output text)
    
    if [ "$TARGET_GROUP_ARN" = "None" ] || [ -z "$TARGET_GROUP_ARN" ]; then
        log_error "Target Group 생성 실패"
        exit 1
    fi
    
    log_success "Target Group 생성 완료: $TARGET_GROUP_ARN"
    
    # Listener 생성
    log_info "Listener 생성 중..."
    aws elbv2 create-listener \
        --load-balancer-arn "$ALB_ARN" \
        --protocol HTTP \
        --port 80 \
        --default-actions Type=forward,TargetGroupArn="$TARGET_GROUP_ARN"
    
    log_success "Listener 생성 완료"
    
    # ALB DNS 이름 가져오기
    ALB_DNS=$(aws elbv2 describe-load-balancers \
        --load-balancer-arns "$ALB_ARN" \
        --query 'LoadBalancers[0].DNSName' --output text)
    
    log_success "AWS ALB 설정 완료"
    log_info "ALB DNS: $ALB_DNS"
    
    # 설정 정보 저장
    echo "ALB_ARN=$ALB_ARN" > aws-lb-config.env
    echo "TARGET_GROUP_ARN=$TARGET_GROUP_ARN" >> aws-lb-config.env
    echo "ALB_DNS=$ALB_DNS" >> aws-lb-config.env
}

setup_gcp_load_balancer() {
    log_header "GCP HTTP(S) Load Balancer 설정"
    
    # Health Check 생성
    log_info "Health Check 생성 중..."
    gcloud compute health-checks create http "$PROJECT_NAME-health-check" \
        --port 3000 \
        --request-path /health \
        --check-interval 10s \
        --timeout 5s \
        --healthy-threshold 1 \
        --unhealthy-threshold 3
    
    # Instance Group 생성
    log_info "Instance Group 생성 중..."
    gcloud compute instance-groups unmanaged create "$PROJECT_NAME-instance-group" \
        --zone="$GCP_ZONE"
    
    # Backend Service 생성
    log_info "Backend Service 생성 중..."
    gcloud compute backend-services create "$PROJECT_NAME-backend-service" \
        --protocol HTTP \
        --port-name http \
        --health-checks "$PROJECT_NAME-health-check" \
        --global
    
    # URL Map 생성
    log_info "URL Map 생성 중..."
    gcloud compute url-maps create "$PROJECT_NAME-url-map" \
        --default-service "$PROJECT_NAME-backend-service"
    
    # Target HTTP Proxy 생성
    log_info "Target HTTP Proxy 생성 중..."
    gcloud compute target-http-proxies create "$PROJECT_NAME-http-proxy" \
        --url-map "$PROJECT_NAME-url-map"
    
    # Forwarding Rule 생성
    log_info "Forwarding Rule 생성 중..."
    gcloud compute forwarding-rules create "$PROJECT_NAME-forwarding-rule" \
        --global \
        --target-http-proxy "$PROJECT_NAME-http-proxy" \
        --ports 80
    
    # Load Balancer IP 가져오기
    LB_IP=$(gcloud compute forwarding-rules describe "$PROJECT_NAME-forwarding-rule" \
        --global --format="value(IPAddress)")
    
    log_success "GCP Load Balancer 설정 완료"
    log_info "Load Balancer IP: $LB_IP"
    
    # 설정 정보 저장
    echo "LB_IP=$LB_IP" > gcp-lb-config.env
    echo "INSTANCE_GROUP=$PROJECT_NAME-instance-group" >> gcp-lb-config.env
    echo "BACKEND_SERVICE=$PROJECT_NAME-backend-service" >> gcp-lb-config.env
}

create_test_application() {
    log_header "테스트 애플리케이션 생성"
    
    # 간단한 Node.js 애플리케이션 생성
    cat > app.js << 'EOF'
const express = require('express');
const app = express();
const port = 3000;

// Health check endpoint
app.get('/health', (req, res) => {
    res.status(200).json({ status: 'healthy', timestamp: new Date().toISOString() });
});

// Main endpoint
app.get('/', (req, res) => {
    res.json({
        message: 'Hello from Cloud Master Day3 Load Balancer Test!',
        instance: process.env.HOSTNAME || 'unknown',
        timestamp: new Date().toISOString()
    });
});

// Metrics endpoint for Prometheus
app.get('/metrics', (req, res) => {
    res.set('Content-Type', 'text/plain');
    res.send(`
# HELP http_requests_total Total number of HTTP requests
# TYPE http_requests_total counter
http_requests_total{method="GET",endpoint="/"} 0
http_requests_total{method="GET",endpoint="/health"} 0
http_requests_total{method="GET",endpoint="/metrics"} 0
`);
});

app.listen(port, '0.0.0.0', () => {
    console.log(`Test app listening at http://0.0.0.0:${port}`);
});
EOF

    # package.json 생성
    cat > package.json << 'EOF'
{
  "name": "cloud-master-day3-test-app",
  "version": "1.0.0",
  "description": "Test application for load balancer testing",
  "main": "app.js",
  "scripts": {
    "start": "node app.js"
  },
  "dependencies": {
    "express": "^4.18.2"
  }
}
EOF

    # Dockerfile 생성
    cat > Dockerfile << 'EOF'
FROM node:18-alpine

WORKDIR /app

COPY package*.json ./
RUN npm install

COPY . .

EXPOSE 3000

CMD ["npm", "start"]
EOF

    # Docker 이미지 빌드
    log_info "Docker 이미지 빌드 중..."
    docker build -t "$PROJECT_NAME-test-app" .
    
    log_success "테스트 애플리케이션 생성 완료"
}

test_load_balancers() {
    log_header "로드밸런서 테스트"
    
    # AWS ALB 테스트
    if [ -f "aws-lb-config.env" ]; then
        source aws-lb-config.env
        log_info "AWS ALB 테스트 중..."
        
        # 헬스 체크 테스트
        if curl -f -s "http://$ALB_DNS/health" > /dev/null; then
            log_success "AWS ALB 헬스 체크 성공"
        else
            log_warning "AWS ALB 헬스 체크 실패 (인스턴스가 등록되지 않음)"
        fi
        
        # 부하 분산 테스트
        log_info "AWS ALB 부하 분산 테스트 중..."
        for i in {1..5}; do
            curl -s "http://$ALB_DNS/" | jq -r '.instance // "No instance info"'
            sleep 1
        done
    fi
    
    # GCP Load Balancer 테스트
    if [ -f "gcp-lb-config.env" ]; then
        source gcp-lb-config.env
        log_info "GCP Load Balancer 테스트 중..."
        
        # 헬스 체크 테스트
        if curl -f -s "http://$LB_IP/health" > /dev/null; then
            log_success "GCP Load Balancer 헬스 체크 성공"
        else
            log_warning "GCP Load Balancer 헬스 체크 실패 (인스턴스가 등록되지 않음)"
        fi
        
        # 부하 분산 테스트
        log_info "GCP Load Balancer 부하 분산 테스트 중..."
        for i in {1..5}; do
            curl -s "http://$LB_IP/" | jq -r '.instance // "No instance info"'
            sleep 1
        done
    fi
}

cleanup() {
    log_header "리소스 정리"
    
    # AWS 리소스 정리
    if [ -f "aws-lb-config.env" ]; then
        source aws-lb-config.env
        log_info "AWS 리소스 정리 중..."
        
        # ALB 삭제
        if [ -n "$ALB_ARN" ]; then
            aws elbv2 delete-load-balancer --load-balancer-arn "$ALB_ARN"
            log_success "AWS ALB 삭제 완료"
        fi
        
        # Target Group 삭제
        if [ -n "$TARGET_GROUP_ARN" ]; then
            aws elbv2 delete-target-group --target-group-arn "$TARGET_GROUP_ARN"
            log_success "AWS Target Group 삭제 완료"
        fi
        
        # Security Group 삭제
        if [ -n "$AWS_SECURITY_GROUP" ]; then
            aws ec2 delete-security-group --group-id "$AWS_SECURITY_GROUP"
            log_success "AWS Security Group 삭제 완료"
        fi
    fi
    
    # GCP 리소스 정리
    if [ -f "gcp-lb-config.env" ]; then
        source gcp-lb-config.env
        log_info "GCP 리소스 정리 중..."
        
        # Forwarding Rule 삭제
        gcloud compute forwarding-rules delete "$PROJECT_NAME-forwarding-rule" --global --quiet
        
        # Target HTTP Proxy 삭제
        gcloud compute target-http-proxies delete "$PROJECT_NAME-http-proxy" --quiet
        
        # URL Map 삭제
        gcloud compute url-maps delete "$PROJECT_NAME-url-map" --quiet
        
        # Backend Service 삭제
        gcloud compute backend-services delete "$PROJECT_NAME-backend-service" --global --quiet
        
        # Instance Group 삭제
        gcloud compute instance-groups unmanaged delete "$PROJECT_NAME-instance-group" --zone="$GCP_ZONE" --quiet
        
        # Health Check 삭제
        gcloud compute health-checks delete "$PROJECT_NAME-health-check" --quiet
        
        log_success "GCP 리소스 정리 완료"
    fi
    
    # 로컬 파일 정리
    rm -f aws-lb-config.env gcp-lb-config.env
    rm -f app.js package.json Dockerfile
    
    log_success "모든 리소스 정리 완료"
}

show_help() {
    echo "Cloud Master Day3 - 로드밸런싱 실습 자동화 스크립트"
    echo ""
    echo "사용법: $0 [옵션]"
    echo ""
    echo "옵션:"
    echo "  setup     로드밸런서 설정 (기본값)"
    echo "  test      로드밸런서 테스트"
    echo "  cleanup   리소스 정리"
    echo "  help      도움말 표시"
    echo ""
    echo "예시:"
    echo "  $0 setup    # 로드밸런서 설정"
    echo "  $0 test     # 로드밸런서 테스트"
    echo "  $0 cleanup  # 리소스 정리"
}

# 메인 실행
main() {
    case "${1:-setup}" in
        "setup")
            check_prerequisites
            get_aws_resources
            get_gcp_resources
            setup_aws_alb
            setup_gcp_load_balancer
            create_test_application
            log_success "로드밸런싱 설정 완료!"
            ;;
        "test")
            test_load_balancers
            ;;
        "cleanup")
            cleanup
            ;;
        "help"|"-h"|"--help")
            show_help
            ;;
        *)
            log_error "알 수 없는 옵션: $1"
            show_help
            exit 1
            ;;
    esac
}

# 스크립트 실행
main "$@"
