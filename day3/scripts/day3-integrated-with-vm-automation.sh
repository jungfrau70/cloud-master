#!/bin/bash

# Cloud Master Day3 - VM 연계 통합 실습 자동화 스크립트
# 작성일: 2024년 9월 23일
# 목적: 기존 helper 스크립트와 VM 배포 스크립트를 활용한 통합 실습

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 로그 함수
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_header() { echo -e "${PURPLE}=== $1 ===${NC}"; }
log_step() { echo -e "${CYAN}[STEP]${NC} $1"; }

# 설정 변수
PROJECT_NAME="cloud-master-day3-vm"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLOUD_SCRIPTS_DIR="$SCRIPT_DIR/../../cloud-scripts"
WORK_DIR="./$PROJECT_NAME"
TIMEOUT=300  # 5분 타임아웃

# 함수 정의
check_prerequisites() {
    log_header "사전 요구사항 확인"
    
    # 필수 도구 확인
    local tools=("aws" "gcloud" "docker" "jq" "curl")
    local missing_tools=()
    
    for tool in "${tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            missing_tools+=("$tool")
        fi
    done
    
    if [ ${#missing_tools[@]} -gt 0 ]; then
        log_error "다음 도구들이 설치되지 않았습니다: ${missing_tools[*]}"
        return 1
    fi
    
    # Cloud Scripts 디렉토리 확인
    if [ ! -d "$CLOUD_SCRIPTS_DIR" ]; then
        log_error "Cloud Scripts 디렉토리를 찾을 수 없습니다: $CLOUD_SCRIPTS_DIR"
        return 1
    fi
    
    log_success "모든 필수 도구가 설치되어 있습니다."
}

setup_environment() {
    log_header "환경 설정"
    
    # 작업 디렉토리 생성
    mkdir -p "$WORK_DIR"
    cd "$WORK_DIR"
    
    # Cloud Scripts 디렉토리로 이동하여 환경 설정
    cd "$CLOUD_SCRIPTS_DIR"
    
    # AWS 환경 설정
    if [ ! -f "aws-environment.env" ]; then
        log_info "AWS 환경 설정 중..."
        ./aws-setup-helper.sh
        if [ $? -ne 0 ]; then
            log_error "AWS 환경 설정 실패"
            return 1
        fi
    else
        log_success "AWS 환경 파일이 이미 존재합니다."
    fi
    
    # GCP 환경 설정
    if [ ! -f "gcp-environment.env" ]; then
        log_info "GCP 환경 설정 중..."
        ./gcp-setup-helper.sh
        if [ $? -ne 0 ]; then
            log_error "GCP 환경 설정 실패"
            return 1
        fi
    else
        log_success "GCP 환경 파일이 이미 존재합니다."
    fi
    
    # 환경 파일들을 작업 디렉토리로 복사
    cp aws-environment.env "$WORK_DIR/"
    cp gcp-environment.env "$WORK_DIR/"
    
    cd "$WORK_DIR"
    
    # 환경 파일 로드
    source aws-environment.env
    source gcp-environment.env
    
    log_success "환경 설정 완료"
    log_info "AWS 리전: $REGION"
    log_info "GCP 프로젝트: $GCP_PROJECT_ID"
}

run_with_timeout() {
    local timeout_seconds=$1
    shift
    local command="$@"
    
    timeout "$timeout_seconds" bash -c "$command" 2>/dev/null
    local exit_code=$?
    
    if [ $exit_code -eq 124 ]; then
        log_warning "명령어가 타임아웃되었습니다 ($timeout_seconds초)"
        return 1
    elif [ $exit_code -ne 0 ]; then
        log_warning "명령어 실행 실패 (종료 코드: $exit_code)"
        return 1
    fi
    
    return 0
}

deploy_aws_vm() {
    log_step "1/6: AWS EC2 VM 배포"
    
    cd "$CLOUD_SCRIPTS_DIR"
    
    # AWS EC2 인스턴스 생성
    log_info "AWS EC2 인스턴스 생성 중..."
    ./aws-ec2-create.sh --name "$PROJECT_NAME-web" --count 2 --auto-confirm
    
    if [ $? -ne 0 ]; then
        log_error "AWS EC2 인스턴스 생성 실패"
        return 1
    fi
    
    # 생성된 인스턴스 정보 가져오기
    local instance_ids
    instance_ids=$(aws ec2 describe-instances \
        --filters "Name=tag:Name,Values=$PROJECT_NAME-web" "Name=instance-state-name,Values=running" \
        --query 'Reservations[*].Instances[*].InstanceId' --output text)
    
    if [ -z "$instance_ids" ]; then
        log_error "생성된 인스턴스를 찾을 수 없습니다."
        return 1
    fi
    
    # 인스턴스 정보를 배열로 변환
    read -ra INSTANCE_IDS <<< "$instance_ids"
    
    log_success "AWS EC2 인스턴스 생성 완료: ${#INSTANCE_IDS[@]}개"
    for instance_id in "${INSTANCE_IDS[@]}"; do
        log_info "  - $instance_id"
    done
    
    # 인스턴스 정보 저장
    echo "AWS_INSTANCE_IDS=(${INSTANCE_IDS[*]})" > "$WORK_DIR/aws-vm-config.env"
    
    cd "$WORK_DIR"
}

deploy_gcp_vm() {
    log_step "2/6: GCP Compute Engine VM 배포"
    
    cd "$CLOUD_SCRIPTS_DIR"
    
    # GCP Compute Engine 인스턴스 생성
    log_info "GCP Compute Engine 인스턴스 생성 중..."
    ./gcp-compute-create.sh --name "$PROJECT_NAME-web" --count 2 --auto-confirm
    
    if [ $? -ne 0 ]; then
        log_error "GCP Compute Engine 인스턴스 생성 실패"
        return 1
    fi
    
    # 생성된 인스턴스 정보 가져오기
    local instance_names
    instance_names=$(gcloud compute instances list \
        --filter="name~$PROJECT_NAME-web AND status=RUNNING" \
        --format="value(name)")
    
    if [ -z "$instance_names" ]; then
        log_error "생성된 인스턴스를 찾을 수 없습니다."
        return 1
    fi
    
    # 인스턴스 정보를 배열로 변환
    read -ra INSTANCE_NAMES <<< "$instance_names"
    
    log_success "GCP Compute Engine 인스턴스 생성 완료: ${#INSTANCE_NAMES[@]}개"
    for instance_name in "${INSTANCE_NAMES[@]}"; do
        log_info "  - $instance_name"
    done
    
    # 인스턴스 정보 저장
    echo "GCP_INSTANCE_NAMES=(${INSTANCE_NAMES[*]})" > "$WORK_DIR/gcp-vm-config.env"
    
    cd "$WORK_DIR"
}

setup_aws_load_balancer() {
    log_step "3/6: AWS 로드밸런서 설정"
    
    # 환경 파일 로드
    source aws-vm-config.env
    
    # VPC ID 가져오기
    local vpc_id
    vpc_id=$(run_with_timeout 30 aws ec2 describe-vpcs --filters "Name=is-default,Values=true" --query 'Vpcs[0].VpcId' --output text)
    
    if [ "$vpc_id" = "None" ] || [ -z "$vpc_id" ]; then
        log_error "기본 VPC를 찾을 수 없습니다."
        return 1
    fi
    
    log_info "VPC ID: $vpc_id"
    
    # 서브넷 ID 가져오기
    local subnet1 subnet2
    subnet1=$(run_with_timeout 30 aws ec2 describe-subnets --filters "Name=vpc-id,Values=$vpc_id" --query 'Subnets[0].SubnetId' --output text)
    subnet2=$(run_with_timeout 30 aws ec2 describe-subnets --filters "Name=vpc-id,Values=$vpc_id" --query 'Subnets[1].SubnetId' --output text)
    
    # 기존 보안 그룹 확인 및 삭제
    local existing_sg
    existing_sg=$(run_with_timeout 30 aws ec2 describe-security-groups \
        --filters "Name=group-name,Values=$PROJECT_NAME-sg" "Name=vpc-id,Values=$vpc_id" \
        --query 'SecurityGroups[0].GroupId' --output text 2>/dev/null)
    
    if [ "$existing_sg" != "None" ] && [ -n "$existing_sg" ]; then
        log_info "기존 보안 그룹 삭제 중: $existing_sg"
        run_with_timeout 30 aws ec2 delete-security-group --group-id "$existing_sg" &>/dev/null
        sleep 5
    fi
    
    # 보안 그룹 생성
    local security_group
    security_group=$(run_with_timeout 60 aws ec2 create-security-group \
        --group-name "$PROJECT_NAME-sg" \
        --description "Security group for $PROJECT_NAME" \
        --vpc-id "$vpc_id" \
        --query 'GroupId' --output text)
    
    if [ $? -ne 0 ] || [ "$security_group" = "None" ] || [ -z "$security_group" ]; then
        log_error "보안 그룹 생성 실패"
        return 1
    fi
    
    # 보안 그룹 규칙 추가
    run_with_timeout 30 aws ec2 authorize-security-group-ingress \
        --group-id "$security_group" \
        --protocol tcp --port 80 --cidr 0.0.0.0/0 &>/dev/null
    
    run_with_timeout 30 aws ec2 authorize-security-group-ingress \
        --group-id "$security_group" \
        --protocol tcp --port 443 --cidr 0.0.0.0/0 &>/dev/null
    
    # ALB 생성
    local alb_arn
    alb_arn=$(run_with_timeout 120 aws elbv2 create-load-balancer \
        --name "$PROJECT_NAME-alb" \
        --subnets "$subnet1" "$subnet2" \
        --security-groups "$security_group" \
        --query 'LoadBalancers[0].LoadBalancerArn' --output text)
    
    if [ $? -ne 0 ]; then
        log_error "ALB 생성 실패"
        return 1
    fi
    
    # Target Group 생성
    local target_group_arn
    target_group_arn=$(run_with_timeout 60 aws elbv2 create-target-group \
        --name "$PROJECT_NAME-targets" \
        --protocol HTTP --port 80 --vpc-id "$vpc_id" \
        --query 'TargetGroups[0].TargetGroupArn' --output text)
    
    if [ $? -ne 0 ]; then
        log_error "Target Group 생성 실패"
        return 1
    fi
    
    # 인스턴스를 Target Group에 등록
    for instance_id in "${INSTANCE_IDS[@]}"; do
        run_with_timeout 30 aws elbv2 register-targets \
            --target-group-arn "$target_group_arn" \
            --targets "Id=$instance_id,Port=80" &>/dev/null
    done
    
    # Listener 생성
    run_with_timeout 30 aws elbv2 create-listener \
        --load-balancer-arn "$alb_arn" \
        --protocol HTTP --port 80 \
        --default-actions Type=forward,TargetGroupArn="$target_group_arn" &>/dev/null
    
    # ALB DNS 이름 가져오기
    local alb_dns
    alb_dns=$(run_with_timeout 30 aws elbv2 describe-load-balancers \
        --load-balancer-arns "$alb_arn" \
        --query 'LoadBalancers[0].DNSName' --output text)
    
    # 설정 정보 저장
    cat > aws-lb-config.env << EOF
ALB_ARN=$alb_arn
TARGET_GROUP_ARN=$target_group_arn
ALB_DNS=$alb_dns
SECURITY_GROUP=$security_group
EOF
    
    log_success "AWS 로드밸런서 설정 완료"
    log_info "ALB DNS: $alb_dns"
}

setup_gcp_load_balancer() {
    log_step "4/6: GCP 로드밸런서 설정"
    
    # 환경 파일 로드
    source gcp-vm-config.env
    
    # Instance Group 생성
    run_with_timeout 30 gcloud compute instance-groups unmanaged create "$PROJECT_NAME-instance-group" \
        --zone=us-central1-a &>/dev/null
    
    # 인스턴스를 Instance Group에 추가
    for instance_name in "${INSTANCE_NAMES[@]}"; do
        run_with_timeout 30 gcloud compute instance-groups unmanaged add-instances "$PROJECT_NAME-instance-group" \
            --instances="$instance_name" --zone=us-central1-a &>/dev/null
    done
    
    # Health Check 생성
    run_with_timeout 60 gcloud compute health-checks create http "$PROJECT_NAME-health-check" \
        --port 80 --request-path / --check-interval 10s --timeout 5s \
        --healthy-threshold 1 --unhealthy-threshold 3 &>/dev/null
    
    # Backend Service 생성
    run_with_timeout 60 gcloud compute backend-services create "$PROJECT_NAME-backend-service" \
        --protocol HTTP --port-name http --health-checks "$PROJECT_NAME-health-check" --global &>/dev/null
    
    # Backend Service에 Instance Group 추가
    run_with_timeout 30 gcloud compute backend-services add-backend "$PROJECT_NAME-backend-service" \
        --instance-group="$PROJECT_NAME-instance-group" \
        --instance-group-zone=us-central1-a --global &>/dev/null
    
    # URL Map 생성
    run_with_timeout 30 gcloud compute url-maps create "$PROJECT_NAME-url-map" \
        --default-service "$PROJECT_NAME-backend-service" &>/dev/null
    
    # Target HTTP Proxy 생성
    run_with_timeout 30 gcloud compute target-http-proxies create "$PROJECT_NAME-http-proxy" \
        --url-map "$PROJECT_NAME-url-map" &>/dev/null
    
    # Forwarding Rule 생성
    run_with_timeout 60 gcloud compute forwarding-rules create "$PROJECT_NAME-forwarding-rule" \
        --global --target-http-proxy "$PROJECT_NAME-http-proxy" --ports 80 &>/dev/null
    
    # Load Balancer IP 가져오기
    local lb_ip
    lb_ip=$(run_with_timeout 30 gcloud compute forwarding-rules describe "$PROJECT_NAME-forwarding-rule" \
        --global --format="value(IPAddress)")
    
    # 설정 정보 저장
    cat > gcp-lb-config.env << EOF
LB_IP=$lb_ip
INSTANCE_GROUP=$PROJECT_NAME-instance-group
BACKEND_SERVICE=$PROJECT_NAME-backend-service
PROJECT_ID=$GCP_PROJECT_ID
EOF
    
    log_success "GCP 로드밸런서 설정 완료"
    log_info "Load Balancer IP: $lb_ip"
}

setup_monitoring() {
    log_step "5/6: 모니터링 설정"
    
    # 모니터링 디렉토리 생성
    mkdir -p monitoring-stack/{prometheus,grafana}
    
    # Prometheus 설정
    cat > monitoring-stack/prometheus/prometheus.yml << 'EOF'
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']
  
  - job_name: 'node-exporter'
    static_configs:
      - targets: ['node-exporter:9100']
  
  - job_name: 'aws-ec2'
    static_configs:
      - targets: ['aws-ec2:9100']
  
  - job_name: 'gcp-compute'
    static_configs:
      - targets: ['gcp-compute:9100']
EOF

    # Grafana 설정
    cat > monitoring-stack/grafana/datasources.yml << 'EOF'
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
    editable: true
EOF

    # Docker Compose 설정
    cat > monitoring-stack/docker-compose.yml << 'EOF'
version: '3.8'

services:
  prometheus:
    image: prom/prometheus:latest
    container_name: prometheus
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus/prometheus.yml:/etc/prometheus/prometheus.yml
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--web.enable-lifecycle'
    networks:
      - monitoring

  node-exporter:
    image: prom/node-exporter:latest
    container_name: node-exporter
    ports:
      - "9100:9100"
    volumes:
      - /proc:/host/proc:ro
      - /sys:/host/sys:ro
      - /:/rootfs:ro
    command:
      - '--path.procfs=/host/proc'
      - '--path.rootfs=/rootfs'
      - '--path.sysfs=/host/sys'
    networks:
      - monitoring

  grafana:
    image: grafana/grafana:latest
    container_name: grafana
    ports:
      - "3001:3000"
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin
      - GF_USERS_ALLOW_SIGN_UP=false
    volumes:
      - grafana-storage:/var/lib/grafana
      - ./grafana/datasources.yml:/etc/grafana/provisioning/datasources/datasources.yml
    networks:
      - monitoring

volumes:
  grafana-storage:

networks:
  monitoring:
    driver: bridge
EOF

    # 모니터링 스택 시작
    cd monitoring-stack
    run_with_timeout 60 docker-compose up -d &>/dev/null
    cd ..
    
    log_success "모니터링 설정 완료"
}

setup_cost_optimization() {
    log_step "6/6: 비용 최적화 설정"
    
    # 비용 분석 디렉토리 생성
    mkdir -p cost-reports/{aws,gcp}
    
    # AWS 비용 분석
    local current_month
    current_month=$(date +%Y-%m-01)
    local next_month
    next_month=$(date -d "$current_month +1 month" +%Y-%m-01)
    
    log_info "AWS 비용 분석 중... ($current_month ~ $next_month)"
    
    run_with_timeout 60 aws ce get-cost-and-usage \
        --time-period Start="$current_month",End="$next_month" \
        --granularity MONTHLY \
        --metrics BlendedCost \
        --group-by Type=DIMENSION,Key=SERVICE \
        --output json > cost-reports/aws/cost-analysis.json 2>/dev/null
    
    # GCP 비용 분석
    log_info "GCP 비용 분석 중... (프로젝트: $GCP_PROJECT_ID)"
    
    run_with_timeout 30 gcloud billing accounts list --format=json > cost-reports/gcp/billing-accounts.json 2>/dev/null
    
    # 비용 최적화 리포트 생성
    cat > cost-reports/cost-optimization-report.md << EOF
# Cloud Master Day3 - VM 연계 비용 최적화 리포트

## 분석 일시
$(date)

## AWS 비용 현황
- 분석 기간: $current_month ~ $next_month
- 생성된 인스턴스: ${#INSTANCE_IDS[@]}개
- 상세 분석: cost-reports/aws/cost-analysis.json

## GCP 비용 현황
- 프로젝트: $GCP_PROJECT_ID
- 생성된 인스턴스: ${#INSTANCE_NAMES[@]}개
- 상세 분석: cost-reports/gcp/billing-accounts.json

## 권장사항
1. 미사용 리소스 정리
2. 인스턴스 크기 최적화
3. 예약 인스턴스 활용 검토
4. 스팟 인스턴스 활용 검토
5. VM 인스턴스 자동 종료 설정
EOF
    
    log_success "비용 최적화 설정 완료"
}

test_system() {
    log_header "시스템 테스트"
    
    # AWS ALB 테스트
    if [ -f "aws-lb-config.env" ]; then
        source aws-lb-config.env
        log_info "AWS ALB 테스트 중..."
        
        if run_with_timeout 10 curl -f -s "http://$ALB_DNS/" &>/dev/null; then
            log_success "AWS ALB 헬스 체크 성공"
        else
            log_warning "AWS ALB 헬스 체크 실패 (인스턴스가 등록되지 않음)"
        fi
    fi
    
    # GCP Load Balancer 테스트
    if [ -f "gcp-lb-config.env" ]; then
        source gcp-lb-config.env
        log_info "GCP Load Balancer 테스트 중..."
        
        if run_with_timeout 10 curl -f -s "http://$LB_IP/" &>/dev/null; then
            log_success "GCP Load Balancer 헬스 체크 성공"
        else
            log_warning "GCP Load Balancer 헬스 체크 실패 (인스턴스가 등록되지 않음)"
        fi
    fi
    
    # 모니터링 테스트
    if run_with_timeout 10 curl -f -s "http://localhost:9090" &>/dev/null; then
        log_success "Prometheus 접속 성공: http://localhost:9090"
    else
        log_warning "Prometheus 접속 실패"
    fi
    
    if run_with_timeout 10 curl -f -s "http://localhost:3001" &>/dev/null; then
        log_success "Grafana 접속 성공: http://localhost:3001 (admin/admin)"
    else
        log_warning "Grafana 접속 실패"
    fi
    
    log_success "시스템 테스트 완료"
}

show_status() {
    log_header "시스템 상태"
    
    # AWS 리소스 상태
    log_info "AWS 리소스 상태:"
    run_with_timeout 30 aws elbv2 describe-load-balancers --query 'LoadBalancers[*].[LoadBalancerName,State.Code,DNSName]' --output table 2>/dev/null || log_warning "AWS 리소스 정보를 가져올 수 없습니다."
    
    # GCP 리소스 상태
    log_info "GCP 리소스 상태:"
    run_with_timeout 30 gcloud compute forwarding-rules list --format="table(name,IPAddress,status)" 2>/dev/null || log_warning "GCP 리소스 정보를 가져올 수 없습니다."
    
    # Docker 컨테이너 상태
    log_info "Docker 컨테이너 상태:"
    run_with_timeout 10 docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null || log_warning "Docker 컨테이너 정보를 가져올 수 없습니다."
    
    # 접속 URL 정보
    log_info "접속 URL:"
    echo "  Prometheus: http://localhost:9090"
    echo "  Grafana: http://localhost:3001 (admin/admin)"
    echo "  Node Exporter: http://localhost:9100"
    
    if [ -f "aws-lb-config.env" ]; then
        source aws-lb-config.env
        echo "  AWS ALB: http://$ALB_DNS"
    fi
    
    if [ -f "gcp-lb-config.env" ]; then
        source gcp-lb-config.env
        echo "  GCP Load Balancer: http://$LB_IP"
    fi
}

cleanup() {
    log_header "리소스 정리"
    
    # AWS 리소스 정리
    if [ -f "aws-lb-config.env" ]; then
        source aws-lb-config.env
        log_info "AWS 리소스 정리 중..."
        
        run_with_timeout 60 aws elbv2 delete-load-balancer --load-balancer-arn "$ALB_ARN" &>/dev/null
        run_with_timeout 30 aws elbv2 delete-target-group --target-group-arn "$TARGET_GROUP_ARN" &>/dev/null
        run_with_timeout 30 aws ec2 delete-security-group --group-id "$SECURITY_GROUP" &>/dev/null
    fi
    
    # AWS VM 정리
    if [ -f "aws-vm-config.env" ]; then
        source aws-vm-config.env
        log_info "AWS VM 정리 중..."
        
        for instance_id in "${INSTANCE_IDS[@]}"; do
            run_with_timeout 30 aws ec2 terminate-instances --instance-ids "$instance_id" &>/dev/null
        done
    fi
    
    # GCP 리소스 정리
    if [ -f "gcp-lb-config.env" ]; then
        source gcp-lb-config.env
        log_info "GCP 리소스 정리 중..."
        
        run_with_timeout 30 gcloud compute forwarding-rules delete "$PROJECT_NAME-forwarding-rule" --global --quiet &>/dev/null
        run_with_timeout 30 gcloud compute target-http-proxies delete "$PROJECT_NAME-http-proxy" --quiet &>/dev/null
        run_with_timeout 30 gcloud compute url-maps delete "$PROJECT_NAME-url-map" --quiet &>/dev/null
        run_with_timeout 30 gcloud compute backend-services delete "$PROJECT_NAME-backend-service" --global --quiet &>/dev/null
        run_with_timeout 30 gcloud compute instance-groups unmanaged delete "$PROJECT_NAME-instance-group" --zone=us-central1-a --quiet &>/dev/null
        run_with_timeout 30 gcloud compute health-checks delete "$PROJECT_NAME-health-check" --quiet &>/dev/null
    fi
    
    # GCP VM 정리
    if [ -f "gcp-vm-config.env" ]; then
        source gcp-vm-config.env
        log_info "GCP VM 정리 중..."
        
        for instance_name in "${INSTANCE_NAMES[@]}"; do
            run_with_timeout 30 gcloud compute instances delete "$instance_name" --zone=us-central1-a --quiet &>/dev/null
        done
    fi
    
    # 모니터링 스택 정리
    if [ -d "monitoring-stack" ]; then
        cd monitoring-stack
        run_with_timeout 30 docker-compose down &>/dev/null
        cd ..
    fi
    
    # 로컬 디렉토리 정리
    cd ..
    if [ -d "$PROJECT_NAME" ]; then
        rm -rf "$PROJECT_NAME"
        log_success "로컬 디렉토리 정리 완료"
    fi
    
    log_success "모든 리소스 정리 완료"
}

show_help() {
    echo "Cloud Master Day3 - VM 연계 통합 실습 자동화 스크립트"
    echo ""
    echo "사용법: $0 [옵션]"
    echo ""
    echo "옵션:"
    echo "  setup      전체 실습 환경 설정 (기본값)"
    echo "  test       시스템 테스트"
    echo "  status     시스템 상태 확인"
    echo "  cleanup    전체 리소스 정리"
    echo "  help       도움말 표시"
    echo ""
    echo "특징:"
    echo "  - 기존 helper 스크립트 활용"
    echo "  - AWS/GCP VM 자동 배포"
    echo "  - 로드밸런서와 VM 연계"
    echo "  - 통합 모니터링 설정"
    echo "  - 비용 최적화 분석"
}

# 메인 실행
main() {
    case "${1:-setup}" in
        "setup")
            check_prerequisites || exit 1
            setup_environment
            deploy_aws_vm
            deploy_gcp_vm
            setup_aws_load_balancer
            setup_gcp_load_balancer
            setup_monitoring
            setup_cost_optimization
            test_system
            show_status
            log_success "Cloud Master Day3 VM 연계 실습 완료!"
            ;;
        "test")
            test_system
            ;;
        "status")
            show_status
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
