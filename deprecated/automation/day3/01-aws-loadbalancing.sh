#!/bin/bash

# Cloud Master Day3 - AWS VM 활용 로드밸런싱 실습
# 작성일: 2024년 9월 23일
# 목적: 기존 AWS cloud-deployment-server VM을 활용한 로드밸런싱 설정

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
PROJECT_NAME="cloud-master-day3-aws-vm"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK_DIR="./$PROJECT_NAME"
TIMEOUT=300  # 5분 타임아웃

# 기존 VM 정보
AWS_INSTANCE_ID="i-099f55941265d751f"  # cloud-deployment-server

# 함수 정의
check_prerequisites() {
    log_header "사전 요구사항 확인"
    
    # 필수 도구 확인
    local tools=("aws" "docker" "jq" "curl")
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
    
    # AWS CLI 설정 확인
    if ! timeout 10 aws sts get-caller-identity &> /dev/null; then
        log_error "AWS CLI가 설정되지 않았습니다."
        return 1
    fi
    
    log_success "모든 필수 도구가 설치되어 있습니다."
}

setup_environment() {
    log_header "환경 설정"
    
    # 작업 디렉토리 생성
    mkdir -p "$WORK_DIR"
    cd "$WORK_DIR"
    
    # 타임아웃 설정
    export AWS_CLI_AUTO_PROMPT=off
    
    log_success "환경 설정 완료"
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

verify_existing_vm() {
    log_step "1/5: 기존 AWS VM 확인"
    
    # AWS VM 확인
    log_info "AWS VM 확인 중..."
    local aws_vm_info
    aws_vm_info=$(run_with_timeout 30 aws ec2 describe-instances \
        --instance-ids "$AWS_INSTANCE_ID" \
        --query 'Reservations[0].Instances[0].[InstanceId,State.Name,PublicIpAddress,PrivateIpAddress]' \
        --output text)
    
    if [ $? -ne 0 ] || [ -z "$aws_vm_info" ]; then
        log_error "AWS VM을 찾을 수 없습니다: $AWS_INSTANCE_ID"
        return 1
    fi
    
    read -r aws_instance_id aws_state aws_public_ip aws_private_ip <<< "$aws_vm_info"
    
    if [ "$aws_state" != "running" ]; then
        log_error "AWS VM이 실행 중이 아닙니다: $aws_state"
        return 1
    fi
    
    log_success "AWS VM 확인 완료"
    log_info "  - Instance ID: $aws_instance_id"
    log_info "  - Public IP: $aws_public_ip"
    log_info "  - Private IP: $aws_private_ip"
    
    # VM 정보 저장
    cat > vm-info.env << EOF
AWS_INSTANCE_ID=$aws_instance_id
AWS_PUBLIC_IP=$aws_public_ip
AWS_PRIVATE_IP=$aws_private_ip
EOF
}

setup_aws_load_balancer() {
    log_step "2/5: AWS 로드밸런서 설정"
    
    # VM 정보 로드
    source vm-info.env
    
    # VPC ID 가져오기
    local vpc_id
    vpc_id=$(run_with_timeout 30 aws ec2 describe-instances \
        --instance-ids "$AWS_INSTANCE_ID" \
        --query 'Reservations[0].Instances[0].VpcId' --output text)
    
    log_info "VPC ID: $vpc_id"
    
    # 기본 VPC의 모든 서브넷 가져오기
    local subnet_ids
    subnet_ids=$(run_with_timeout 30 aws ec2 describe-subnets \
        --filters "Name=vpc-id,Values=$vpc_id" \
        --query 'Subnets[*].SubnetId' --output text)
    
    if [ -z "$subnet_ids" ]; then
        log_error "VPC에 서브넷을 찾을 수 없습니다"
        return 1
    fi
    
    # 서브넷 ID를 배열로 변환
    read -ra SUBNET_ARRAY <<< "$subnet_ids"
    
    log_info "사용 가능한 서브넷: ${#SUBNET_ARRAY[@]}개"
    for subnet in "${SUBNET_ARRAY[@]}"; do
        log_info "  - $subnet"
    done
    
    # 최소 2개 서브넷이 있는지 확인
    if [ ${#SUBNET_ARRAY[@]} -lt 2 ]; then
        log_error "ALB 생성에는 최소 2개의 서브넷이 필요합니다"
        return 1
    fi
    
    # VM에 연결된 보안 그룹 가져오기
    local security_group
    security_group=$(run_with_timeout 30 aws ec2 describe-instances \
        --instance-ids "$AWS_INSTANCE_ID" \
        --query 'Reservations[0].Instances[0].SecurityGroups[0].GroupId' --output text)
    
    if [ $? -ne 0 ] || [ "$security_group" = "None" ] || [ -z "$security_group" ]; then
        log_error "VM의 보안 그룹을 찾을 수 없습니다"
        return 1
    fi
    
    log_info "VM의 기존 보안 그룹 사용: $security_group"
    
    # 보안 그룹에 HTTP/HTTPS 규칙이 있는지 확인
    local has_http_rule
    has_http_rule=$(run_with_timeout 30 aws ec2 describe-security-groups \
        --group-ids "$security_group" \
        --query 'SecurityGroups[0].IpPermissions[?FromPort==`80`]' --output text)
    
    if [ -z "$has_http_rule" ]; then
        log_info "HTTP 규칙 추가 중..."
        run_with_timeout 30 aws ec2 authorize-security-group-ingress \
            --group-id "$security_group" \
            --protocol tcp --port 80 --cidr 0.0.0.0/0 &>/dev/null
    else
        log_info "HTTP 규칙이 이미 존재합니다"
    fi
    
    local has_https_rule
    has_https_rule=$(run_with_timeout 30 aws ec2 describe-security-groups \
        --group-ids "$security_group" \
        --query 'SecurityGroups[0].IpPermissions[?FromPort==`443`]' --output text)
    
    if [ -z "$has_https_rule" ]; then
        log_info "HTTPS 규칙 추가 중..."
        run_with_timeout 30 aws ec2 authorize-security-group-ingress \
            --group-id "$security_group" \
            --protocol tcp --port 443 --cidr 0.0.0.0/0 &>/dev/null
    else
        log_info "HTTPS 규칙이 이미 존재합니다"
    fi
    
    
    # ALB 생성 (모든 서브넷 사용)
    local alb_arn
    alb_arn=$(run_with_timeout 120 aws elbv2 create-load-balancer \
        --name "$PROJECT_NAME-alb" \
        --subnets "${SUBNET_ARRAY[@]}" \
        --security-groups "$security_group" \
        --query 'LoadBalancers[0].LoadBalancerArn' --output text)
    
    if [ $? -ne 0 ]; then
        log_error "ALB 생성 실패"
        return 1
    fi
    
    # 기존 리소스 정리 (간단한 방법)
    log_info "기존 리소스 정리 중..."
    cleanup_aws_resources &>/dev/null || true
    
    # Target Group 생성 (고유한 이름 사용)
    local target_group_name="${PROJECT_NAME}-targets-$(date +%s)"
    log_info "Target Group 생성 중: $target_group_name"
    
    local target_group_arn
    target_group_arn=$(run_with_timeout 60 aws elbv2 create-target-group \
        --name "$target_group_name" \
        --protocol HTTP --port 80 --vpc-id "$vpc_id" \
        --health-check-path "/" \
        --health-check-interval-seconds 30 \
        --health-check-timeout-seconds 5 \
        --healthy-threshold-count 2 \
        --unhealthy-threshold-count 3 \
        --target-type instance \
        --query 'TargetGroups[0].TargetGroupArn' --output text)
    
    if [ $? -ne 0 ] || [ -z "$target_group_arn" ]; then
        log_error "Target Group 생성 실패"
        log_info "VPC ID: $vpc_id"
        log_info "Target Group 이름: $target_group_name"
        return 1
    fi
    
    log_success "Target Group 생성 완료: $target_group_arn"
    
    # 인스턴스를 Target Group에 등록
    log_info "VM을 Target Group에 등록 중..."
    run_with_timeout 30 aws elbv2 register-targets \
        --target-group-arn "$target_group_arn" \
        --targets "Id=$AWS_INSTANCE_ID,Port=80" &>/dev/null
    
    if [ $? -ne 0 ]; then
        log_error "VM 등록 실패"
        return 1
    fi
    
    log_success "VM 등록 완료"
    
    # Target Group 상태 확인 (최대 2분 대기)
    log_info "Target Group 상태 확인 중... (최대 2분 대기)"
    local max_attempts=24
    local attempt=0
    local target_healthy=false
    
    while [ $attempt -lt $max_attempts ] && [ "$target_healthy" = false ]; do
        local target_health
        target_health=$(run_with_timeout 30 aws elbv2 describe-target-health \
            --target-group-arn "$target_group_arn" \
            --query 'TargetHealthDescriptions[0].TargetHealth.State' \
            --output text 2>/dev/null || echo "unknown")
        
        if [ "$target_health" = "healthy" ]; then
            target_healthy=true
            log_success "Target Group 상태: healthy"
        elif [ "$target_health" = "unhealthy" ]; then
            log_warning "Target Group 상태: unhealthy (계속 대기 중...)"
        else
            log_info "Target Group 상태: $target_health (대기 중...)"
        fi
        
        if [ "$target_healthy" = false ]; then
            sleep 5
            attempt=$((attempt + 1))
        fi
    done
    
    if [ "$target_healthy" = false ]; then
        log_warning "Target Group이 healthy 상태가 되지 않았습니다. 계속 진행합니다."
    fi
    
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

setup_monitoring() {
    log_step "3/5: 모니터링 설정"
    
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
  
  - job_name: 'aws-vm'
    static_configs:
      - targets: ['aws-vm:9100']
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
    log_step "4/5: 비용 최적화 설정"
    
    # 비용 분석 디렉토리 생성
    mkdir -p cost-reports/aws
    
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
    
    # 비용 최적화 리포트 생성
    cat > cost-reports/cost-optimization-report.md << EOF
# Cloud Master Day3 - AWS VM 활용 비용 최적화 리포트

## 분석 일시
$(date)

## AWS 비용 현황
- 분석 기간: $current_month ~ $next_month
- 사용 중인 인스턴스: $AWS_INSTANCE_ID
- 상세 분석: cost-reports/aws/cost-analysis.json

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
    log_step "5/5: 시스템 테스트"
    
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
    
    # VM 정보 표시
    if [ -f "vm-info.env" ]; then
        source vm-info.env
        log_info "사용 중인 VM:"
        echo "  AWS: $AWS_INSTANCE_ID ($AWS_PUBLIC_IP)"
    fi
    
    # AWS 리소스 상태
    log_info "AWS 리소스 상태:"
    run_with_timeout 30 aws elbv2 describe-load-balancers --query 'LoadBalancers[*].[LoadBalancerName,State.Code,DNSName]' --output table 2>/dev/null || log_warning "AWS 리소스 정보를 가져올 수 없습니다."
    
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
    echo "Cloud Master Day3 - AWS VM 활용 로드밸런싱 실습"
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
    echo "  - 기존 AWS cloud-deployment-server VM 활용"
    echo "  - AWS ALB 로드밸런서 설정"
    echo "  - 통합 모니터링 설정"
    echo "  - 비용 최적화 분석"
}

# 메인 실행
main() {
    case "${1:-setup}" in
        "setup")
            check_prerequisites || exit 1
            setup_environment
            verify_existing_vm
            setup_aws_load_balancer
            setup_monitoring
            setup_cost_optimization
            test_system
            show_status
            log_success "Cloud Master Day3 AWS VM 활용 실습 완료!"
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
