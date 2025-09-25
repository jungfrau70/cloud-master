#!/bin/bash

# 로드밸런서 자동 설정 스크립트
# Cloud Master Day3용 - 로드밸런싱 & 모니터링 & 비용 최적화

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

# 설정 변수
PROJECT_NAME="cloud-master-lb"
REGION="us-central1"
ZONE="us-central1-a"
INSTANCE_COUNT=3
MACHINE_TYPE="e2-micro"
IMAGE_FAMILY="ubuntu-2004-lts"
IMAGE_PROJECT="ubuntu-os-cloud"

# 체크포인트 파일
CHECKPOINT_FILE="load-balancer-checkpoint.json"

# 체크포인트 로드
load_checkpoint() {
    if [ -f "$CHECKPOINT_FILE" ]; then
        log_info "체크포인트 파일 로드 중..."
        source "$CHECKPOINT_FILE"
    fi
}

# 체크포인트 저장
save_checkpoint() {
    log_info "체크포인트 저장 중..."
    cat > "$CHECKPOINT_FILE" << EOF
INSTANCES_CREATED=$INSTANCES_CREATED
INSTANCE_GROUP_CREATED=$INSTANCE_GROUP_CREATED
HEALTH_CHECK_CREATED=$HEALTH_CHECK_CREATED
BACKEND_SERVICE_CREATED=$BACKEND_SERVICE_CREATED
URL_MAP_CREATED=$URL_MAP_CREATED
HTTP_PROXY_CREATED=$HTTP_PROXY_CREATED
FORWARDING_RULE_CREATED=$FORWARDING_RULE_CREATED
EOF
}

# 환경 체크
check_environment() {
    log_info "환경 체크 중..."
    
    # gcloud CLI 체크
    if ! command -v gcloud &> /dev/null; then
        log_error "gcloud CLI가 설치되지 않았습니다."
        exit 1
    fi
    
    # AWS CLI 체크 (선택사항)
    if command -v aws &> /dev/null; then
        log_info "AWS CLI 감지됨"
        AWS_MODE=true
    else
        log_warning "AWS CLI가 설치되지 않았습니다. GCP 모드로 실행합니다."
        AWS_MODE=false
    fi
    
    # 인증 체크
    if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q .; then
        log_error "GCP 인증이 필요합니다. 'gcloud auth login'을 실행하세요."
        exit 1
    fi
    
    # 프로젝트 설정 체크
    if ! gcloud config get-value project &> /dev/null; then
        log_error "GCP 프로젝트가 설정되지 않았습니다."
        exit 1
    fi
    
    log_success "환경 체크 완료"
}

# GCP 인스턴스 생성
create_gcp_instances() {
    if [ "$INSTANCES_CREATED" = "true" ]; then
        log_info "인스턴스가 이미 생성되어 있습니다."
        return 0
    fi
    
    log_info "GCP 인스턴스 생성 중..."
    
    # 인스턴스 템플릿 생성
    gcloud compute instance-templates create "$PROJECT_NAME-template" \
        --machine-type="$MACHINE_TYPE" \
        --image-family="$IMAGE_FAMILY" \
        --image-project="$IMAGE_PROJECT" \
        --boot-disk-size=10GB \
        --boot-disk-type=pd-standard \
        --tags=http-server,https-server \
        --metadata=startup-script='#!/bin/bash
apt-get update
apt-get install -y nginx
systemctl start nginx
systemctl enable nginx
echo "Hello from Cloud Master Load Balancer!" > /var/www/html/index.html'
    
    # Managed Instance Group 생성
    gcloud compute instance-groups managed create "$PROJECT_NAME-mig" \
        --template="$PROJECT_NAME-template" \
        --size="$INSTANCE_COUNT" \
        --zone="$ZONE"
    
    if [ $? -eq 0 ]; then
        INSTANCES_CREATED="true"
        log_success "GCP 인스턴스 생성 완료"
    else
        log_error "GCP 인스턴스 생성 실패"
        exit 1
    fi
}

# AWS 인스턴스 생성
create_aws_instances() {
    if [ "$AWS_MODE" = "false" ]; then
        return 0
    fi
    
    log_info "AWS 인스턴스 생성 중..."
    
    # 보안 그룹 생성
    aws ec2 create-security-group \
        --group-name "$PROJECT_NAME-sg" \
        --description "Security group for Cloud Master Load Balancer"
    
    # 보안 그룹 규칙 추가
    aws ec2 authorize-security-group-ingress \
        --group-name "$PROJECT_NAME-sg" \
        --protocol tcp \
        --port 80 \
        --cidr 0.0.0.0/0
    
    # Launch Template 생성
    aws ec2 create-launch-template \
        --launch-template-name "$PROJECT_NAME-template" \
        --launch-template-data '{
            "ImageId": "ami-0abcdef1234567890",
            "InstanceType": "t2.micro",
            "SecurityGroupIds": ["sg-12345678"],
            "UserData": "IyEvYmluL2Jhc2gKc3VkbyB5dW0gdXBkYXRlIC15CnN1ZG8geXVtIGluc3RhbGwgLXkgbmdpbngKc3VkbyBzeXN0ZW1jdGwgc3RhcnQgbmdpbngKc3VkbyBzeXN0ZW1jdGwgZW5hYmxlIG5naW54CmVjaG8gIkhlbGxvIGZyb20gQ2xvdWQgTWFzdGVyIExvYWQgQmFsYW5jZXIhIiA+IC92YXIvd3d3L2h0bWwvaW5kZXguaHRtbA=="
        }'
    
    # Auto Scaling Group 생성
    aws autoscaling create-auto-scaling-group \
        --auto-scaling-group-name "$PROJECT_NAME-asg" \
        --launch-template LaunchTemplateName="$PROJECT_NAME-template",Version='$Latest' \
        --min-size 1 \
        --max-size 10 \
        --desired-capacity "$INSTANCE_COUNT" \
        --vpc-zone-identifier "subnet-12345678,subnet-87654321"
    
    log_success "AWS 인스턴스 생성 완료"
}

# GCP 로드밸런서 설정
setup_gcp_load_balancer() {
    if [ "$FORWARDING_RULE_CREATED" = "true" ]; then
        log_info "GCP 로드밸런서가 이미 설정되어 있습니다."
        return 0
    fi
    
    log_info "GCP 로드밸런서 설정 중..."
    
    # Health Check 생성
    gcloud compute health-checks create http "$PROJECT_NAME-health-check" \
        --port=80 \
        --request-path="/" \
        --check-interval=10s \
        --timeout=5s \
        --unhealthy-threshold=3 \
        --healthy-threshold=2
    
    if [ $? -eq 0 ]; then
        HEALTH_CHECK_CREATED="true"
        log_success "Health Check 생성 완료"
    fi
    
    # Backend Service 생성
    gcloud compute backend-services create "$PROJECT_NAME-backend-service" \
        --protocol=HTTP \
        --port-name=http \
        --health-checks="$PROJECT_NAME-health-check" \
        --global
    
    if [ $? -eq 0 ]; then
        BACKEND_SERVICE_CREATED="true"
        log_success "Backend Service 생성 완료"
    fi
    
    # Backend Service에 Instance Group 추가
    gcloud compute backend-services add-backend "$PROJECT_NAME-backend-service" \
        --instance-group="$PROJECT_NAME-mig" \
        --instance-group-zone="$ZONE" \
        --global
    
    # URL Map 생성
    gcloud compute url-maps create "$PROJECT_NAME-url-map" \
        --default-service="$PROJECT_NAME-backend-service"
    
    if [ $? -eq 0 ]; then
        URL_MAP_CREATED="true"
        log_success "URL Map 생성 완료"
    fi
    
    # HTTP Proxy 생성
    gcloud compute target-http-proxies create "$PROJECT_NAME-http-proxy" \
        --url-map="$PROJECT_NAME-url-map"
    
    if [ $? -eq 0 ]; then
        HTTP_PROXY_CREATED="true"
        log_success "HTTP Proxy 생성 완료"
    fi
    
    # Global Forwarding Rule 생성
    gcloud compute forwarding-rules create "$PROJECT_NAME-forwarding-rule" \
        --global \
        --target-http-proxy="$PROJECT_NAME-http-proxy" \
        --ports=80
    
    if [ $? -eq 0 ]; then
        FORWARDING_RULE_CREATED="true"
        log_success "Global Forwarding Rule 생성 완료"
    fi
}

# AWS 로드밸런서 설정
setup_aws_load_balancer() {
    if [ "$AWS_MODE" = "false" ]; then
        return 0
    fi
    
    log_info "AWS 로드밸런서 설정 중..."
    
    # Application Load Balancer 생성
    aws elbv2 create-load-balancer \
        --name "$PROJECT_NAME-alb" \
        --subnets subnet-12345678 subnet-87654321 \
        --security-groups sg-12345678
    
    # Target Group 생성
    aws elbv2 create-target-group \
        --name "$PROJECT_NAME-targets" \
        --protocol HTTP \
        --port 80 \
        --vpc-id vpc-12345678 \
        --health-check-path="/" \
        --health-check-interval-seconds=30 \
        --health-check-timeout-seconds=5 \
        --healthy-threshold-count=2 \
        --unhealthy-threshold-count=3
    
    # Listener 생성
    aws elbv2 create-listener \
        --load-balancer-arn arn:aws:elasticloadbalancing:region:account:loadbalancer/app/$PROJECT_NAME-alb/1234567890123456 \
        --protocol HTTP \
        --port 80 \
        --default-actions Type=forward,TargetGroupArn=arn:aws:elasticloadbalancing:region:account:targetgroup/$PROJECT_NAME-targets/1234567890123456
    
    log_success "AWS 로드밸런서 설정 완료"
}

# 로드밸런서 상태 확인
check_load_balancer_status() {
    log_info "로드밸런서 상태 확인 중..."
    
    # GCP 로드밸런서 상태 확인
    log_info "GCP 로드밸런서 상태:"
    gcloud compute forwarding-rules describe "$PROJECT_NAME-forwarding-rule" --global
    
    # 외부 IP 확인
    EXTERNAL_IP=$(gcloud compute forwarding-rules describe "$PROJECT_NAME-forwarding-rule" --global --format="value(IPAddress)")
    
    if [ ! -z "$EXTERNAL_IP" ]; then
        log_info "GCP 로드밸런서 IP: $EXTERNAL_IP"
        log_info "테스트: curl http://$EXTERNAL_IP"
    fi
    
    # Backend Service 상태 확인
    log_info "Backend Service 상태:"
    gcloud compute backend-services describe "$PROJECT_NAME-backend-service" --global
    
    # Instance Group 상태 확인
    log_info "Instance Group 상태:"
    gcloud compute instance-groups managed list-instances "$PROJECT_NAME-mig" --zone="$ZONE"
    
    # Health Check 상태 확인
    log_info "Health Check 상태:"
    gcloud compute health-checks describe "$PROJECT_NAME-health-check"
}

# 로드밸런서 테스트
test_load_balancer() {
    log_info "로드밸런서 테스트 중..."
    
    # 외부 IP 가져오기
    EXTERNAL_IP=$(gcloud compute forwarding-rules describe "$PROJECT_NAME-forwarding-rule" --global --format="value(IPAddress)")
    
    if [ ! -z "$EXTERNAL_IP" ]; then
        log_info "로드밸런서 테스트 실행 중..."
        
        # 여러 번 요청하여 로드밸런싱 확인
        for i in {1..5}; do
            log_info "요청 $i:"
            curl -s "http://$EXTERNAL_IP" | head -1
            sleep 1
        done
        
        log_success "로드밸런서 테스트 완료"
    else
        log_warning "외부 IP를 가져올 수 없습니다."
    fi
}

# 정리 함수
cleanup() {
    log_info "정리 중..."
    
    # GCP 리소스 정리
    gcloud compute forwarding-rules delete "$PROJECT_NAME-forwarding-rule" --global --quiet
    gcloud compute target-http-proxies delete "$PROJECT_NAME-http-proxy" --quiet
    gcloud compute url-maps delete "$PROJECT_NAME-url-map" --quiet
    gcloud compute backend-services delete "$PROJECT_NAME-backend-service" --global --quiet
    gcloud compute health-checks delete "$PROJECT_NAME-health-check" --quiet
    gcloud compute instance-groups managed delete "$PROJECT_NAME-mig" --zone="$ZONE" --quiet
    gcloud compute instance-templates delete "$PROJECT_NAME-template" --quiet
    
    # AWS 리소스 정리 (선택사항)
    if [ "$AWS_MODE" = "true" ]; then
        aws elbv2 delete-load-balancer --load-balancer-arn arn:aws:elasticloadbalancing:region:account:loadbalancer/app/$PROJECT_NAME-alb/1234567890123456
        aws elbv2 delete-target-group --target-group-arn arn:aws:elasticloadbalancing:region:account:targetgroup/$PROJECT_NAME-targets/1234567890123456
        aws autoscaling delete-auto-scaling-group --auto-scaling-group-name "$PROJECT_NAME-asg" --force-delete
        aws ec2 delete-launch-template --launch-template-name "$PROJECT_NAME-template"
    fi
    
    # 체크포인트 파일 삭제
    rm -f "$CHECKPOINT_FILE"
    
    log_success "정리 완료"
}

# 메인 함수
main() {
    log_info "=== Cloud Master Day3 - 로드밸런서 설정 시작 ==="
    
    # 체크포인트 로드
    load_checkpoint
    
    # 환경 체크
    check_environment
    
    # 인스턴스 생성
    create_gcp_instances
    create_aws_instances
    save_checkpoint
    
    # 로드밸런서 설정
    setup_gcp_load_balancer
    setup_aws_load_balancer
    save_checkpoint
    
    # 로드밸런서 상태 확인
    check_load_balancer_status
    
    # 로드밸런서 테스트
    test_load_balancer
    
    log_success "=== 로드밸런서 설정 완료 ==="
    log_info "프로젝트 이름: $PROJECT_NAME"
    log_info "리전: $REGION"
    log_info "존: $ZONE"
    log_info "인스턴스 수: $INSTANCE_COUNT"
    log_info "머신 타입: $MACHINE_TYPE"
    
    log_info "다음 단계:"
    log_info "1. 로드밸런서 IP로 애플리케이션 접속 테스트"
    log_info "2. Health Check 상태 모니터링"
    log_info "3. 오토스케일링 정책 설정"
}

# 스크립트 실행
if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    main "$@"
fi
