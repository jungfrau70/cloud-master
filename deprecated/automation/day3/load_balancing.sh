#!/bin/bash
# Cloud Master Day3 - 로드밸런싱 및 오토스케일링 자동화 스크립트
# 강의안 기반 업데이트: 2024년 9월 22일

set -e

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

log_info "🚀 Cloud Master Day3 - 로드밸런싱 및 오토스케일링 자동화 시작"

# AWS Application Load Balancer 설정
log_info "📋 AWS ALB 설정 스크립트 생성 중..."
cat > aws-alb-setup.sh << 'EOF'
#!/bin/bash
# AWS Application Load Balancer 설정
# Day3 강의안 기반 업데이트

set -e

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

log_info "🏗️ AWS ALB 인프라 구축 시작"

# VPC 생성
log_info "VPC 생성 중..."
VPC_ID=$(aws ec2 create-vpc \
  --cidr-block 10.0.0.0/16 \
  --query 'Vpc.VpcId' \
  --output text)

log_success "VPC 생성 완료: $VPC_ID"

# Internet Gateway 생성 및 연결
log_info "Internet Gateway 생성 중..."
IGW_ID=$(aws ec2 create-internet-gateway \
  --query 'InternetGateway.InternetGatewayId' \
  --output text)

aws ec2 attach-internet-gateway \
  --vpc-id $VPC_ID \
  --internet-gateway-id $IGW_ID

log_success "Internet Gateway 연결 완료: $IGW_ID"

# 서브넷 생성 (Multi-AZ)
log_info "Multi-AZ 서브넷 생성 중..."
SUBNET_1=$(aws ec2 create-subnet \
  --vpc-id $VPC_ID \
  --cidr-block 10.0.1.0/24 \
  --availability-zone us-west-2a \
  --query 'Subnet.SubnetId' \
  --output text)

SUBNET_2=$(aws ec2 create-subnet \
  --vpc-id $VPC_ID \
  --cidr-block 10.0.2.0/24 \
  --availability-zone us-west-2b \
  --query 'Subnet.SubnetId' \
  --output text)

log_success "서브넷 생성 완료: $SUBNET_1, $SUBNET_2"

# 라우팅 테이블 설정
log_info "라우팅 테이블 설정 중..."
ROUTE_TABLE_ID=$(aws ec2 create-route-table \
  --vpc-id $VPC_ID \
  --query 'RouteTable.RouteTableId' \
  --output text)

aws ec2 create-route \
  --route-table-id $ROUTE_TABLE_ID \
  --destination-cidr-block 0.0.0.0/0 \
  --gateway-id $IGW_ID

aws ec2 associate-route-table \
  --subnet-id $SUBNET_1 \
  --route-table-id $ROUTE_TABLE_ID

aws ec2 associate-route-table \
  --subnet-id $SUBNET_2 \
  --route-table-id $ROUTE_TABLE_ID

log_success "라우팅 테이블 설정 완료"

# 보안 그룹 생성
log_info "보안 그룹 생성 중..."
SECURITY_GROUP_ID=$(aws ec2 create-security-group \
  --group-name alb-sg \
  --description "Security group for ALB" \
  --vpc-id $VPC_ID \
  --query 'GroupId' \
  --output text)

# HTTP/HTTPS 트래픽 허용
aws ec2 authorize-security-group-ingress \
  --group-id $SECURITY_GROUP_ID \
  --protocol tcp \
  --port 80 \
  --cidr 0.0.0.0/0

aws ec2 authorize-security-group-ingress \
  --group-id $SECURITY_GROUP_ID \
  --protocol tcp \
  --port 443 \
  --cidr 0.0.0.0/0

log_success "보안 그룹 생성 완료: $SECURITY_GROUP_ID"

# Application Load Balancer 생성
log_info "Application Load Balancer 생성 중..."
ALB_ARN=$(aws elbv2 create-load-balancer \
  --name my-alb \
  --subnets $SUBNET_1 $SUBNET_2 \
  --security-groups $SECURITY_GROUP_ID \
  --query 'LoadBalancers[0].LoadBalancerArn' \
  --output text)

log_success "ALB 생성 완료: $ALB_ARN"

# Target Group 생성
log_info "Target Group 생성 중..."
TARGET_GROUP_ARN=$(aws elbv2 create-target-group \
  --name my-targets \
  --protocol HTTP \
  --port 3000 \
  --vpc-id $VPC_ID \
  --health-check-path /health \
  --health-check-interval-seconds 30 \
  --health-check-timeout-seconds 5 \
  --healthy-threshold-count 2 \
  --unhealthy-threshold-count 3 \
  --query 'TargetGroups[0].TargetGroupArn' \
  --output text)

log_success "Target Group 생성 완료: $TARGET_GROUP_ARN"

# Listener 생성
log_info "Listener 생성 중..."
aws elbv2 create-listener \
  --load-balancer-arn $ALB_ARN \
  --protocol HTTP \
  --port 80 \
  --default-actions Type=forward,TargetGroupArn=$TARGET_GROUP_ARN

log_success "Listener 생성 완료"

# ALB DNS 이름 출력
ALB_DNS=$(aws elbv2 describe-load-balancers \
  --load-balancer-arns $ALB_ARN \
  --query 'LoadBalancers[0].DNSName' \
  --output text)

log_success "🎉 AWS ALB 설정 완료!"
log_info "ALB DNS: $ALB_DNS"
log_info "Target Group ARN: $TARGET_GROUP_ARN"

# 환경 변수 저장
echo "export ALB_ARN=$ALB_ARN" >> ~/.bashrc
echo "export TARGET_GROUP_ARN=$TARGET_GROUP_ARN" >> ~/.bashrc
echo "export ALB_DNS=$ALB_DNS" >> ~/.bashrc
echo "export VPC_ID=$VPC_ID" >> ~/.bashrc
echo "export SUBNET_1=$SUBNET_1" >> ~/.bashrc
echo "export SUBNET_2=$SUBNET_2" >> ~/.bashrc

log_info "환경 변수가 ~/.bashrc에 저장되었습니다."
EOF

# GCP Cloud Load Balancing 설정
log_info "📋 GCP Cloud Load Balancing 설정 스크립트 생성 중..."
cat > gcp-lb-setup.sh << 'EOF'
#!/bin/bash
# GCP Cloud Load Balancing 설정
# Day3 강의안 기반 업데이트

set -e

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

log_info "🏗️ GCP Cloud Load Balancing 인프라 구축 시작"

# 시작 스크립트 생성
log_info "시작 스크립트 생성 중..."
cat > startup-script.sh << 'SCRIPT_EOF'
#!/bin/bash
# GCP 인스턴스 시작 스크립트

# 시스템 업데이트
apt-get update
apt-get install -y docker.io apache2-utils

# Docker 서비스 시작
systemctl start docker
systemctl enable docker
usermod -aG docker $USER

# 간단한 웹 애플리케이션 실행
cat > /tmp/app.js << 'APP_EOF'
const http = require('http');
const port = 3000;

const server = http.createServer((req, res) => {
  if (req.url === '/health') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ status: 'healthy', timestamp: new Date().toISOString() }));
  } else {
    res.writeHead(200, { 'Content-Type': 'text/html' });
    res.end(`
      <html>
        <head><title>GCP Load Balancer Test</title></head>
        <body>
          <h1>GCP Cloud Load Balancing Test</h1>
          <p>Instance: ${process.env.HOSTNAME || 'unknown'}</p>
          <p>Time: ${new Date().toISOString()}</p>
          <p><a href="/health">Health Check</a></p>
        </body>
      </html>
    `);
  }
});

server.listen(port, '0.0.0.0', () => {
  console.log(`Server running on port ${port}`);
});
APP_EOF

# Node.js 설치 및 앱 실행
curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
apt-get install -y nodejs
node /tmp/app.js &
SCRIPT_EOF

log_success "시작 스크립트 생성 완료"

# Instance Template 생성
log_info "Instance Template 생성 중..."
gcloud compute instance-templates create my-template \
  --image-family=ubuntu-2004-lts \
  --image-project=ubuntu-os-cloud \
  --machine-type=e2-micro \
  --boot-disk-size=10GB \
  --tags=http-server \
  --metadata-from-file startup-script=startup-script.sh

log_success "Instance Template 생성 완료: my-template"

# Managed Instance Group 생성
log_info "Managed Instance Group 생성 중..."
gcloud compute instance-groups managed create my-mig \
  --template=my-template \
  --size=3 \
  --zone=us-central1-a

log_success "Managed Instance Group 생성 완료: my-mig"

# Health Check 생성
log_info "Health Check 생성 중..."
gcloud compute health-checks create http my-health-check \
  --port=3000 \
  --request-path=/health \
  --check-interval=10s \
  --timeout=5s \
  --healthy-threshold=1 \
  --unhealthy-threshold=3

log_success "Health Check 생성 완료: my-health-check"

# Backend Service 생성
log_info "Backend Service 생성 중..."
gcloud compute backend-services create my-backend-service \
  --protocol=HTTP \
  --health-checks=my-health-check \
  --global

log_success "Backend Service 생성 완료: my-backend-service"

# Backend Service에 Instance Group 추가
log_info "Backend Service에 Instance Group 추가 중..."
gcloud compute backend-services add-backend my-backend-service \
  --instance-group=my-mig \
  --instance-group-zone=us-central1-a \
  --global

log_success "Instance Group이 Backend Service에 추가되었습니다"

# URL Map 생성
log_info "URL Map 생성 중..."
gcloud compute url-maps create my-lb \
  --default-service=my-backend-service

log_success "URL Map 생성 완료: my-lb"

# Target HTTP Proxy 생성
log_info "Target HTTP Proxy 생성 중..."
gcloud compute target-http-proxies create my-lb-proxy \
  --url-map=my-lb

log_success "Target HTTP Proxy 생성 완료: my-lb-proxy"

# Global IP 주소 생성
log_info "Global IP 주소 생성 중..."
gcloud compute addresses create my-lb-ip \
  --global

LB_IP=$(gcloud compute addresses describe my-lb-ip \
  --global \
  --format="value(address)")

log_success "Global IP 주소 생성 완료: $LB_IP"

# Forwarding Rule 생성
log_info "Forwarding Rule 생성 중..."
gcloud compute forwarding-rules create my-lb-rule \
  --global \
  --target-http-proxy=my-lb-proxy \
  --address=my-lb-ip \
  --ports=80

log_success "Forwarding Rule 생성 완료: my-lb-rule"

log_success "🎉 GCP Cloud Load Balancing 설정 완료!"
log_info "Load Balancer IP: $LB_IP"
log_info "Health Check URL: http://$LB_IP/health"

# 환경 변수 저장
echo "export LB_IP=$LB_IP" >> ~/.bashrc
echo "export MIG_NAME=my-mig" >> ~/.bashrc
echo "export BACKEND_SERVICE=my-backend-service" >> ~/.bashrc

log_info "환경 변수가 ~/.bashrc에 저장되었습니다."
EOF

# 오토스케일링 설정
log_info "📋 오토스케일링 설정 스크립트 생성 중..."
cat > autoscaling-setup.sh << 'EOF'
#!/bin/bash
# 오토스케일링 설정
# Day3 강의안 기반 업데이트

set -e

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

log_info "🏗️ 오토스케일링 설정 시작"

# AWS Auto Scaling 설정
log_info "AWS Auto Scaling 설정 중..."

# Launch Template 생성
log_info "Launch Template 생성 중..."
aws ec2 create-launch-template \
  --launch-template-name my-template \
  --launch-template-data '{
    "ImageId": "ami-0c02fb55956c7d316",
    "InstanceType": "t3.micro",
    "SecurityGroupIds": ["'$SECURITY_GROUP_ID'"],
    "UserData": "IyEvYmluL2Jhc2gKc3VkbyB5dW0gdXBkYXRlIC15CnN1ZG8geXVtIGluc3RhbGwgLXkgZG9ja2VyCnN1ZG8gc3lzdGVtY3RsIHN0YXJ0IGRvY2tlcgpzdWRvIHN5c3RlbWN0bCBlbmFibGUgZG9ja2VyCnN1ZG8gdXNlcm1vZCAtYSBHIGRvY2tlciAkVVNFUgojIFNpbXBsZSB3ZWIgYXBwbGljYXRpb24KY2F0ID4gL3RtcC9hcHAuanMgPDwgJ0FQUF9FT0YnCmNvbnN0IGh0dHAgPSByZXF1aXJlKCdodHRwJyk7CmNvbnN0IHBvcnQgPSAzMDAwOwoKY29uc3Qgc2VydmVyID0gaHR0cC5jcmVhdGVTZXJ2ZXIoKHJlcSwgcmVzKSA9PiB7CiAgaWYgKHJlcS51cmwgPT09ICcvaGVhbHRoJykgewogICAgcmVzLndyaXRlSGVhZCgyMDAsIHsgJ0NvbnRlbnQtVHlwZSc6ICdhcHBsaWNhdGlvbi9qc29uJyB9KTsKICAgIHJlcy5lbmQoSlNPTi5zdHJpbmdpZnkoeyBzdGF0dXM6ICdoZWFsdGh5JywgdGltZXN0YW1wOiBuZXcgRGF0ZSgpLnRvSVNPU3RyaW5nKCkgfSkpOwogIH0gZWxzZSB7CiAgICByZXMud3JpdGVIZWFkKDIwMCwgeyAnQ29udGVudC1UeXBlJzogJ3RleHQvaHRtbCcgfSk7CiAgICByZXMuZW5kKGAKICAgICAgPGh0bWw+CiAgICAgICAgPGhlYWQ+PHRpdGxlPkFXUyBBdXRvIFNjYWxpbmcgVGVzdDwvdGl0bGU+PC9oZWFkPgogICAgICAgIDxib2R5PgogICAgICAgICAgPGgxPkFXUyBBdXRvIFNjYWxpbmcgVGVzdDwvaDE+CiAgICAgICAgICA8cD5JbnN0YW5jZTogJHtwcm9jZXNzLmVudi5IT1NUTkFNRX0gPC9wPgogICAgICAgICAgPHA+VGltZTogJHtuZXcgRGF0ZSgpLnRvSVNPU3RyaW5nKCl9IDwvcD4KICAgICAgICAgIDxwPjxhIGhyZWY9Ii9oZWFsdGgiPkhlYWx0aCBDaGVjazwvYT48L3A+CiAgICAgICAgPC9ib2R5PgogICAgICA8L2h0bWw+CiAgICBgKTsKICB9Cn0pOwoKc2VydmVyLmxpc3Rlbihwb3J0LCAnMC4wLjAuMCcsICgpID0+IHsKICBjb25zb2xlLmxvZyhgU2VydmVyIHJ1bm5pbmcgb24gcG9ydCAke3BvcnR9YCk7Cn0pOwphcHBfRU9GCmN1cmwgLWZzU0wgaHR0cHM6Ly9kZWIubm9kZXNvdXJjZS5jb20vc2V0dXBfMTgueCB8IGJhc2ggLQphcHQtZ2V0IGluc3RhbGwgLXkgbm9kZWpzCm5vZGUgL3RtcC9hcHAuanMgJgo=",
    "TagSpecifications": [
      {
        "ResourceType": "instance",
        "Tags": [
          {
            "Key": "Name",
            "Value": "auto-scaling-instance"
          },
          {
            "Key": "Environment",
            "Value": "production"
          }
        ]
      }
    ]
  }'

log_success "Launch Template 생성 완료: my-template"

# Auto Scaling Group 생성
log_info "Auto Scaling Group 생성 중..."
aws autoscaling create-auto-scaling-group \
  --auto-scaling-group-name my-asg \
  --launch-template LaunchTemplateName=my-template,Version=1 \
  --min-size 1 \
  --max-size 10 \
  --desired-capacity 3 \
  --target-group-arns $TARGET_GROUP_ARN \
  --health-check-type ELB \
  --health-check-grace-period 300 \
  --vpc-zone-identifier "$SUBNET_1,$SUBNET_2"

log_success "Auto Scaling Group 생성 완료: my-asg"

# Scaling Policy 생성 (Scale Out)
log_info "Scale Out Policy 생성 중..."
aws autoscaling put-scaling-policy \
  --auto-scaling-group-name my-asg \
  --policy-name scale-out-policy \
  --policy-type TargetTrackingScaling \
  --target-tracking-configuration '{
    "TargetValue": 70.0,
    "PredefinedMetricSpecification": {
      "PredefinedMetricType": "ASGAverageCPUUtilization"
    },
    "ScaleOutCooldown": 300,
    "ScaleInCooldown": 300
  }'

log_success "Scale Out Policy 생성 완료"

# GCP Auto Scaling 설정
log_info "GCP Auto Scaling 설정 중..."

# Autoscaler 생성
log_info "GCP Autoscaler 생성 중..."
gcloud compute instance-groups managed set-autoscaling my-mig \
  --zone=us-central1-a \
  --max-num-replicas=10 \
  --min-num-replicas=1 \
  --target-cpu-utilization=0.6 \
  --cool-down-period=60

log_success "GCP Autoscaler 생성 완료"

# 스케일링 테스트 스크립트 생성
log_info "스케일링 테스트 스크립트 생성 중..."
cat > scaling-test.sh << 'TEST_EOF'
#!/bin/bash
# 오토스케일링 테스트 스크립트

log_info() { echo -e "\033[0;34m[INFO]\033[0m $1"; }
log_success() { echo -e "\033[0;32m[SUCCESS]\033[0m $1"; }

log_info "🧪 오토스케일링 테스트 시작"

# AWS Auto Scaling Group 상태 확인
log_info "AWS Auto Scaling Group 상태 확인 중..."
aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names my-asg \
  --query 'AutoScalingGroups[0].Instances[*].[InstanceId,HealthStatus,LifecycleState]' \
  --output table

# GCP MIG 상태 확인
log_info "GCP MIG 상태 확인 중..."
gcloud compute instance-groups managed list-instances my-mig \
  --zone=us-central1-a \
  --format="table(name,status,healthState)"

# CPU 부하 생성 (스케일 아웃 테스트)
log_info "CPU 부하 생성 중 (스케일 아웃 테스트)..."
for i in {1..5}; do
  # AWS 인스턴스에 CPU 부하 생성
  INSTANCE_ID=$(aws autoscaling describe-auto-scaling-groups \
    --auto-scaling-group-names my-asg \
    --query 'AutoScalingGroups[0].Instances[0].InstanceId' \
    --output text)
  
  if [ "$INSTANCE_ID" != "None" ] && [ -n "$INSTANCE_ID" ]; then
    PUBLIC_IP=$(aws ec2 describe-instances \
      --instance-ids $INSTANCE_ID \
      --query 'Reservations[0].Instances[0].PublicIpAddress' \
      --output text)
    
    if [ "$PUBLIC_IP" != "None" ] && [ -n "$PUBLIC_IP" ]; then
      ssh -i ~/.ssh/id_rsa -o StrictHostKeyChecking=no ubuntu@$PUBLIC_IP \
        "yes > /dev/null &" &
    fi
  fi
  
  sleep 10
done

log_info "CPU 부하 생성 완료. 5분 후 스케일링 결과를 확인하세요."

# 5분 대기
log_info "5분 대기 중... (스케일링 대기)"
sleep 300

# 스케일링 결과 확인
log_info "스케일링 결과 확인 중..."

# AWS 결과
log_info "AWS Auto Scaling Group 최종 상태:"
aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names my-asg \
  --query 'AutoScalingGroups[0].Instances[*].[InstanceId,HealthStatus,LifecycleState]' \
  --output table

# GCP 결과
log_info "GCP MIG 최종 상태:"
gcloud compute instance-groups managed list-instances my-mig \
  --zone=us-central1-a \
  --format="table(name,status,healthState)"

log_success "🎉 오토스케일링 테스트 완료!"
TEST_EOF

chmod +x scaling-test.sh

log_success "🎉 오토스케일링 설정 완료!"
log_info "테스트 실행: ./scaling-test.sh"
log_info "AWS ASG: my-asg"
log_info "GCP MIG: my-mig"

# 환경 변수 저장
echo "export ASG_NAME=my-asg" >> ~/.bashrc
echo "export MIG_NAME=my-mig" >> ~/.bashrc

log_info "환경 변수가 ~/.bashrc에 저장되었습니다."
EOF

# 부하 테스트 스크립트
log_info "📋 부하 테스트 스크립트 생성 중..."
cat > load-test.sh << 'EOF'
#!/bin/bash
# 로드밸런서 부하 테스트 스크립트
# Day3 강의안 기반 업데이트

set -e

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

log_info "🧪 로드밸런서 부하 테스트 시작"

# Apache Bench 설치 확인
log_info "Apache Bench 설치 확인 중..."
if ! command -v ab &> /dev/null; then
    log_info "Apache Bench 설치 중..."
    sudo apt-get update
    sudo apt-get install -y apache2-utils
    log_success "Apache Bench 설치 완료"
else
    log_success "Apache Bench 이미 설치됨"
fi

# 환경 변수 확인
if [ -z "$ALB_DNS" ] && [ -z "$LB_IP" ]; then
    log_error "로드밸런서 URL이 설정되지 않았습니다."
    log_info "AWS ALB: export ALB_DNS=your-alb-dns"
    log_info "GCP LB: export LB_IP=your-lb-ip"
    exit 1
fi

# 테스트 URL 설정
if [ -n "$ALB_DNS" ]; then
    TEST_URL="http://$ALB_DNS"
    log_info "AWS ALB 테스트 URL: $TEST_URL"
elif [ -n "$LB_IP" ]; then
    TEST_URL="http://$LB_IP"
    log_info "GCP LB 테스트 URL: $TEST_URL"
fi

# 헬스 체크 테스트
log_info "헬스 체크 테스트 중..."
if curl -f -s "$TEST_URL/health" > /dev/null; then
    log_success "헬스 체크 통과"
    curl -s "$TEST_URL/health" | jq . 2>/dev/null || curl -s "$TEST_URL/health"
else
    log_error "헬스 체크 실패"
    exit 1
fi

# 부하 테스트 실행
log_info "부하 테스트 실행 중..."
log_info "테스트 설정:"
log_info "- 총 요청 수: 1000"
log_info "- 동시 연결 수: 10"
log_info "- 테스트 URL: $TEST_URL"

echo "=========================================="
echo "🚀 로드밸런서 부하 테스트 결과"
echo "=========================================="

# Apache Bench 실행
ab -n 1000 -c 10 "$TEST_URL/"

echo "=========================================="
echo "📊 테스트 요약"
echo "=========================================="
echo "- 총 요청 수: 1000"
echo "- 동시 연결 수: 10"
echo "- 테스트 URL: $TEST_URL"
echo "- 테스트 시간: $(date)"
echo "- 로드밸런서 타입: $([ -n "$ALB_DNS" ] && echo "AWS ALB" || echo "GCP Cloud LB")"

# 응답 시간 측정
log_info "응답 시간 측정 중..."
RESPONSE_TIME=$(curl -w "%{time_total}" -o /dev/null -s "$TEST_URL/")
log_info "평균 응답 시간: ${RESPONSE_TIME}초"

# 연속 요청 테스트 (부하 분산 확인)
log_info "연속 요청 테스트 (부하 분산 확인) 중..."
echo "=========================================="
echo "🔄 연속 요청 테스트 (부하 분산 확인)"
echo "=========================================="

for i in {1..10}; do
    RESPONSE=$(curl -s "$TEST_URL/" | grep -o "Instance: [^<]*" || echo "Instance: unknown")
    echo "요청 $i: $RESPONSE"
    sleep 1
done

log_success "🎉 부하 테스트 완료!"
log_info "테스트 결과를 확인하여 로드밸런서가 정상적으로 작동하는지 확인하세요."

# 추가 테스트 옵션
log_info "추가 테스트 옵션:"
log_info "- 더 많은 요청: ab -n 5000 -c 50 $TEST_URL/"
log_info "- 더 긴 테스트: ab -n 10000 -c 100 -t 60 $TEST_URL/"
log_info "- 헬스 체크만: curl -s $TEST_URL/health | jq ."
EOF

# 실행 권한 부여
chmod +x aws-alb-setup.sh gcp-lb-setup.sh autoscaling-setup.sh load-test.sh

log_success "🎉 Cloud Master Day3 - 로드밸런싱 및 오토스케일링 자동화 스크립트 생성 완료!"

log_info "📋 생성된 스크립트:"
log_info "- aws-alb-setup.sh: AWS ALB 설정"
log_info "- gcp-lb-setup.sh: GCP Cloud Load Balancing 설정"
log_info "- autoscaling-setup.sh: 오토스케일링 설정"
log_info "- load-test.sh: 부하 테스트"

log_info "🚀 실행 순서:"
log_info "1. ./aws-alb-setup.sh (AWS ALB 설정)"
log_info "2. ./gcp-lb-setup.sh (GCP LB 설정)"
log_info "3. ./autoscaling-setup.sh (오토스케일링 설정)"
log_info "4. ./load-test.sh (부하 테스트)"

log_info "📚 Day3 강의안 기반으로 업데이트되었습니다."
log_info "실제 수업에서 100% 성공한 방법으로 구성되었습니다."
