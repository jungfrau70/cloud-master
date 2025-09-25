#!/bin/bash

# Cloud Master Day3 - 오토스케일링 실습 자동화 스크립트
# 작성일: 2024년 9월 22일
# 목적: AWS Auto Scaling, GCP Managed Instance Group 자동 설정 및 테스트

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
AWS_LAUNCH_TEMPLATE=""
AWS_ASG_NAME=""

# GCP 설정
GCP_PROJECT_ID=""
GCP_INSTANCE_TEMPLATE=""
GCP_MIG_NAME=""

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
    
    # stress 도구 확인 (CPU 부하 테스트용)
    if ! command -v stress &> /dev/null; then
        log_warning "stress 도구가 설치되지 않았습니다. CPU 부하 테스트를 위해 설치합니다."
        if command -v apt-get &> /dev/null; then
            sudo apt-get update && sudo apt-get install -y stress
        elif command -v yum &> /dev/null; then
            sudo yum install -y stress
        else
            log_warning "stress 도구를 수동으로 설치해주세요."
        fi
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
        --group-name "$PROJECT_NAME-asg-sg" \
        --description "Security group for Auto Scaling Group" \
        --vpc-id "$AWS_VPC_ID" \
        --query 'GroupId' --output text)
    
    # 보안 그룹 규칙 추가
    aws ec2 authorize-security-group-ingress \
        --group-id "$AWS_SECURITY_GROUP" \
        --protocol tcp \
        --port 22 \
        --cidr 0.0.0.0/0
    
    aws ec2 authorize-security-group-ingress \
        --group-id "$AWS_SECURITY_GROUP" \
        --protocol tcp \
        --port 3000 \
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
    
    log_success "GCP 리소스 정보 수집 완료"
}

create_launch_template() {
    log_header "AWS Launch Template 생성"
    
    # 최신 Ubuntu AMI ID 가져오기
    AMI_ID=$(aws ec2 describe-images \
        --owners 099720109477 \
        --filters "Name=name,Values=ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*" \
        --query 'Images | sort_by(@, &CreationDate) | [-1].ImageId' \
        --output text)
    
    log_info "사용할 AMI ID: $AMI_ID"
    
    # User Data 스크립트 생성
    cat > user-data.sh << 'EOF'
#!/bin/bash
apt-get update
apt-get install -y docker.io stress-ng
systemctl start docker
systemctl enable docker
usermod -aG docker ubuntu

# 테스트 애플리케이션 실행
docker run -d \
  --name test-app \
  -p 3000:3000 \
  -e HOSTNAME=$(hostname) \
  nginx:alpine

# 간단한 웹 서버 설정
cat > /var/www/html/index.html << 'EOL'
<!DOCTYPE html>
<html>
<head>
    <title>Cloud Master Day3 - Auto Scaling Test</title>
</head>
<body>
    <h1>Hello from Auto Scaling Group!</h1>
    <p>Instance: HOSTNAME_PLACEHOLDER</p>
    <p>Timestamp: TIMESTAMP_PLACEHOLDER</p>
    <p>CPU Load: <span id="cpu-load">0%</span></p>
    <script>
        setInterval(() => {
            fetch('/api/cpu')
                .then(response => response.json())
                .then(data => {
                    document.getElementById('cpu-load').textContent = data.cpu + '%';
                });
        }, 1000);
    </script>
</body>
</html>
EOL

# CPU 정보 API 엔드포인트
cat > /var/www/html/api/cpu << 'EOF'
#!/bin/bash
echo "Content-Type: application/json"
echo ""
cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
echo "{\"cpu\": \"$cpu_usage\"}"
EOF

chmod +x /var/www/html/api/cpu

# nginx 설정
cat > /etc/nginx/sites-available/default << 'EOF'
server {
    listen 3000;
    root /var/www/html;
    index index.html;
    
    location / {
        try_files $uri $uri/ =404;
    }
    
    location /api/ {
        fastcgi_pass unix:/var/run/fcgiwrap.socket;
        include fastcgi_params;
    }
    
    location /health {
        return 200 'healthy';
        add_header Content-Type text/plain;
    }
}
EOF

systemctl restart nginx
EOF

    # User Data를 base64로 인코딩
    USER_DATA=$(base64 -w 0 user-data.sh)
    
    # Launch Template 생성
    AWS_LAUNCH_TEMPLATE=$(aws ec2 create-launch-template \
        --launch-template-name "$PROJECT_NAME-template" \
        --launch-template-data "{
            \"ImageId\": \"$AMI_ID\",
            \"InstanceType\": \"t3.micro\",
            \"SecurityGroupIds\": [\"$AWS_SECURITY_GROUP\"],
            \"UserData\": \"$USER_DATA\",
            \"TagSpecifications\": [{
                \"ResourceType\": \"instance\",
                \"Tags\": [{
                    \"Key\": \"Name\",
                    \"Value\": \"$PROJECT_NAME-instance\"
                }]
            }]
        }" \
        --query 'LaunchTemplate.LaunchTemplateName' --output text)
    
    log_success "Launch Template 생성 완료: $AWS_LAUNCH_TEMPLATE"
}

create_auto_scaling_group() {
    log_header "AWS Auto Scaling Group 생성"
    
    # Auto Scaling Group 생성
    AWS_ASG_NAME="$PROJECT_NAME-asg"
    aws autoscaling create-auto-scaling-group \
        --auto-scaling-group-name "$AWS_ASG_NAME" \
        --launch-template LaunchTemplateName="$AWS_LAUNCH_TEMPLATE",Version='$Latest' \
        --min-size 1 \
        --max-size 10 \
        --desired-capacity 2 \
        --vpc-zone-identifier "$AWS_SUBNET_1,$AWS_SUBNET_2" \
        --health-check-type EC2 \
        --health-check-grace-period 300
    
    log_success "Auto Scaling Group 생성 완료: $AWS_ASG_NAME"
    
    # Target Tracking Policy 생성
    log_info "Target Tracking Policy 생성 중..."
    aws autoscaling put-scaling-policy \
        --auto-scaling-group-name "$AWS_ASG_NAME" \
        --policy-name "$PROJECT_NAME-target-tracking-policy" \
        --policy-type TargetTrackingScaling \
        --target-tracking-configuration '{
            "TargetValue": 70.0,
            "PredefinedMetricSpecification": {
                "PredefinedMetricType": "ASGAverageCPUUtilization"
            },
            "ScaleOutCooldown": 300,
            "ScaleInCooldown": 300
        }'
    
    log_success "Target Tracking Policy 생성 완료"
}

create_gcp_instance_template() {
    log_header "GCP Instance Template 생성"
    
    # Startup Script 생성
    cat > startup-script.sh << 'EOF'
#!/bin/bash
apt-get update
apt-get install -y docker.io stress-ng nginx
systemctl start docker
systemctl enable docker
usermod -aG docker ubuntu

# 테스트 애플리케이션 실행
docker run -d \
  --name test-app \
  -p 3000:3000 \
  -e HOSTNAME=$(hostname) \
  nginx:alpine

# 간단한 웹 서버 설정
cat > /var/www/html/index.html << 'EOL'
<!DOCTYPE html>
<html>
<head>
    <title>Cloud Master Day3 - Auto Scaling Test</title>
</head>
<body>
    <h1>Hello from Managed Instance Group!</h1>
    <p>Instance: HOSTNAME_PLACEHOLDER</p>
    <p>Timestamp: TIMESTAMP_PLACEHOLDER</p>
    <p>CPU Load: <span id="cpu-load">0%</span></p>
    <script>
        setInterval(() => {
            fetch('/api/cpu')
                .then(response => response.json())
                .then(data => {
                    document.getElementById('cpu-load').textContent = data.cpu + '%';
                });
        }, 1000);
    </script>
</body>
</html>
EOL

# CPU 정보 API 엔드포인트
cat > /var/www/html/api/cpu << 'EOF'
#!/bin/bash
echo "Content-Type: application/json"
echo ""
cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
echo "{\"cpu\": \"$cpu_usage\"}"
EOF

chmod +x /var/www/html/api/cpu

# nginx 설정
cat > /etc/nginx/sites-available/default << 'EOF'
server {
    listen 3000;
    root /var/www/html;
    index index.html;
    
    location / {
        try_files $uri $uri/ =404;
    }
    
    location /api/ {
        fastcgi_pass unix:/var/run/fcgiwrap.socket;
        include fastcgi_params;
    }
    
    location /health {
        return 200 'healthy';
        add_header Content-Type text/plain;
    }
}
EOF

systemctl restart nginx
EOF

    # Instance Template 생성
    GCP_INSTANCE_TEMPLATE="$PROJECT_NAME-template"
    gcloud compute instance-templates create "$GCP_INSTANCE_TEMPLATE" \
        --machine-type=e2-micro \
        --image-family=ubuntu-2004-lts \
        --image-project=ubuntu-os-cloud \
        --boot-disk-size=10GB \
        --boot-disk-type=pd-standard \
        --tags=http-server \
        --metadata-from-file startup-script=startup-script.sh
    
    log_success "Instance Template 생성 완료: $GCP_INSTANCE_TEMPLATE"
}

create_managed_instance_group() {
    log_header "GCP Managed Instance Group 생성"
    
    # Managed Instance Group 생성
    GCP_MIG_NAME="$PROJECT_NAME-mig"
    gcloud compute instance-groups managed create "$GCP_MIG_NAME" \
        --template="$GCP_INSTANCE_TEMPLATE" \
        --size=2 \
        --zone="$GCP_ZONE"
    
    log_success "Managed Instance Group 생성 완료: $GCP_MIG_NAME"
    
    # Autoscaler 생성
    log_info "Autoscaler 생성 중..."
    gcloud compute instance-groups managed set-autoscaling "$GCP_MIG_NAME" \
        --zone="$GCP_ZONE" \
        --max-num-replicas=10 \
        --min-num-replicas=1 \
        --target-cpu-utilization=0.7 \
        --cool-down-period=60
    
    log_success "Autoscaler 생성 완료"
}

test_auto_scaling() {
    log_header "오토스케일링 테스트"
    
    # AWS Auto Scaling 테스트
    log_info "AWS Auto Scaling Group 상태 확인..."
    aws autoscaling describe-auto-scaling-groups \
        --auto-scaling-group-names "$AWS_ASG_NAME" \
        --query 'AutoScalingGroups[0].{DesiredCapacity:DesiredCapacity,MinSize:MinSize,MaxSize:MaxSize,Instances:Instances[*].InstanceId}' \
        --output table
    
    # GCP Managed Instance Group 테스트
    log_info "GCP Managed Instance Group 상태 확인..."
    gcloud compute instance-groups managed list-instances "$GCP_MIG_NAME" \
        --zone="$GCP_ZONE" \
        --format="table(name,status,instanceStatus)"
    
    log_success "오토스케일링 설정 확인 완료"
}

generate_cpu_load() {
    log_header "CPU 부하 생성 (스케일 아웃 테스트)"
    
    # AWS 인스턴스에 CPU 부하 생성
    log_info "AWS 인스턴스에 CPU 부하 생성 중..."
    INSTANCE_IDS=$(aws autoscaling describe-auto-scaling-groups \
        --auto-scaling-group-names "$AWS_ASG_NAME" \
        --query 'AutoScalingGroups[0].Instances[*].InstanceId' \
        --output text)
    
    for instance_id in $INSTANCE_IDS; do
        PUBLIC_IP=$(aws ec2 describe-instances \
            --instance-ids "$instance_id" \
            --query 'Reservations[0].Instances[0].PublicIpAddress' \
            --output text)
        
        if [ "$PUBLIC_IP" != "None" ] && [ -n "$PUBLIC_IP" ]; then
            log_info "인스턴스 $instance_id ($PUBLIC_IP)에 CPU 부하 생성 중..."
            ssh -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa ubuntu@"$PUBLIC_IP" \
                "nohup stress-ng --cpu 2 --timeout 300 > /dev/null 2>&1 &" || \
                log_warning "SSH 접속 실패: $instance_id"
        fi
    done
    
    # GCP 인스턴스에 CPU 부하 생성
    log_info "GCP 인스턴스에 CPU 부하 생성 중..."
    INSTANCE_NAMES=$(gcloud compute instance-groups managed list-instances "$GCP_MIG_NAME" \
        --zone="$GCP_ZONE" \
        --format="value(name)")
    
    for instance_name in $INSTANCE_NAMES; do
        EXTERNAL_IP=$(gcloud compute instances describe "$instance_name" \
            --zone="$GCP_ZONE" \
            --format="value(networkInterfaces[0].accessConfigs[0].natIP)")
        
        if [ -n "$EXTERNAL_IP" ]; then
            log_info "인스턴스 $instance_name ($EXTERNAL_IP)에 CPU 부하 생성 중..."
            ssh -o StrictHostKeyChecking=no ubuntu@"$EXTERNAL_IP" \
                "nohup stress-ng --cpu 2 --timeout 300 > /dev/null 2>&1 &" || \
                log_warning "SSH 접속 실패: $instance_name"
        fi
    done
    
    log_success "CPU 부하 생성 완료. 5분 후 스케일링 결과를 확인하세요."
}

monitor_scaling() {
    log_header "스케일링 모니터링"
    
    log_info "5분간 스케일링 모니터링을 시작합니다..."
    
    for i in {1..30}; do
        echo "=== 모니터링 $i/30 (10초 간격) ==="
        
        # AWS Auto Scaling Group 상태
        echo "AWS Auto Scaling Group:"
        aws autoscaling describe-auto-scaling-groups \
            --auto-scaling-group-names "$AWS_ASG_NAME" \
            --query 'AutoScalingGroups[0].{DesiredCapacity:DesiredCapacity,CurrentCapacity:length(Instances),Instances:Instances[*].InstanceId}' \
            --output table
        
        # GCP Managed Instance Group 상태
        echo "GCP Managed Instance Group:"
        gcloud compute instance-groups managed list-instances "$GCP_MIG_NAME" \
            --zone="$GCP_ZONE" \
            --format="table(name,status,instanceStatus)" --quiet
        
        sleep 10
    done
    
    log_success "스케일링 모니터링 완료"
}

cleanup() {
    log_header "리소스 정리"
    
    # AWS 리소스 정리
    if [ -n "$AWS_ASG_NAME" ]; then
        log_info "AWS Auto Scaling Group 정리 중..."
        aws autoscaling delete-auto-scaling-group \
            --auto-scaling-group-name "$AWS_ASG_NAME" \
            --force-delete
        log_success "AWS Auto Scaling Group 삭제 완료"
    fi
    
    if [ -n "$AWS_LAUNCH_TEMPLATE" ]; then
        log_info "AWS Launch Template 정리 중..."
        aws ec2 delete-launch-template \
            --launch-template-name "$AWS_LAUNCH_TEMPLATE"
        log_success "AWS Launch Template 삭제 완료"
    fi
    
    if [ -n "$AWS_SECURITY_GROUP" ]; then
        log_info "AWS Security Group 정리 중..."
        aws ec2 delete-security-group \
            --group-id "$AWS_SECURITY_GROUP"
        log_success "AWS Security Group 삭제 완료"
    fi
    
    # GCP 리소스 정리
    if [ -n "$GCP_MIG_NAME" ]; then
        log_info "GCP Managed Instance Group 정리 중..."
        gcloud compute instance-groups managed delete "$GCP_MIG_NAME" \
            --zone="$GCP_ZONE" --quiet
        log_success "GCP Managed Instance Group 삭제 완료"
    fi
    
    if [ -n "$GCP_INSTANCE_TEMPLATE" ]; then
        log_info "GCP Instance Template 정리 중..."
        gcloud compute instance-templates delete "$GCP_INSTANCE_TEMPLATE" --quiet
        log_success "GCP Instance Template 삭제 완료"
    fi
    
    # 로컬 파일 정리
    rm -f user-data.sh startup-script.sh
    
    log_success "모든 리소스 정리 완료"
}

show_help() {
    echo "Cloud Master Day3 - 오토스케일링 실습 자동화 스크립트"
    echo ""
    echo "사용법: $0 [옵션]"
    echo ""
    echo "옵션:"
    echo "  setup     오토스케일링 설정 (기본값)"
    echo "  test      오토스케일링 테스트"
    echo "  load      CPU 부하 생성 (스케일 아웃 테스트)"
    echo "  monitor   스케일링 모니터링"
    echo "  cleanup   리소스 정리"
    echo "  help      도움말 표시"
    echo ""
    echo "예시:"
    echo "  $0 setup    # 오토스케일링 설정"
    echo "  $0 test     # 오토스케일링 테스트"
    echo "  $0 load     # CPU 부하 생성"
    echo "  $0 monitor  # 스케일링 모니터링"
    echo "  $0 cleanup  # 리소스 정리"
}

# 메인 실행
main() {
    case "${1:-setup}" in
        "setup")
            check_prerequisites
            get_aws_resources
            get_gcp_resources
            create_launch_template
            create_auto_scaling_group
            create_gcp_instance_template
            create_managed_instance_group
            test_auto_scaling
            log_success "오토스케일링 설정 완료!"
            ;;
        "test")
            test_auto_scaling
            ;;
        "load")
            generate_cpu_load
            ;;
        "monitor")
            monitor_scaling
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
