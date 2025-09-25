#!/bin/bash

# AWS 로드 밸런싱 개선 스크립트
# WSL 히스토리 분석을 바탕으로 오류 수정 및 개선

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# VPC ID 설정 (실제 환경에 맞게 수정 필요)
VPC_ID="vpc-0cda6aa4e12d0242b"

# 함수: 기존 리소스 정리
cleanup_existing_resources() {
    log_info "기존 리소스 정리 중..."
    
    # 기존 로드 밸런서 삭제
    EXISTING_ALB=$(aws elbv2 describe-load-balancers \
        --query 'LoadBalancers[?contains(LoadBalancerName, `cloud-master-day3`)].LoadBalancerArn' \
        --output text 2>/dev/null)
    
    if [ ! -z "$EXISTING_ALB" ]; then
        log_info "기존 로드 밸런서 삭제: $EXISTING_ALB"
        
        # 리스너 삭제
        LISTENERS=$(aws elbv2 describe-listeners \
            --load-balancer-arn "$EXISTING_ALB" \
            --query 'Listeners[*].ListenerArn' \
            --output text 2>/dev/null)
        
        for listener in $LISTENERS; do
            aws elbv2 delete-listener --listener-arn "$listener" 2>/dev/null
        done
        
        # 타겟 그룹 삭제
        TARGET_GROUPS=$(aws elbv2 describe-target-groups \
            --query 'TargetGroups[?contains(TargetGroupName, `cloud-master-day3`)].TargetGroupArn' \
            --output text 2>/dev/null)
        
        for tg in $TARGET_GROUPS; do
            aws elbv2 delete-target-group --target-group-arn "$tg" 2>/dev/null
        done
        
        # 로드 밸런서 삭제
        aws elbv2 delete-load-balancer --load-balancer-arn "$EXISTING_ALB" 2>/dev/null
        log_success "기존 리소스 정리 완료"
    fi
}

# 함수: 타겟 그룹 생성
create_target_group() {
    log_info "타겟 그룹 생성 중..."
    
    TARGET_GROUP_ARN=$(aws elbv2 create-target-group \
        --name "cm-day3-tg-$(date +%s)" \
        --protocol HTTP \
        --port 80 \
        --vpc-id "$VPC_ID" \
        --health-check-path "/" \
        --health-check-interval-seconds 30 \
        --health-check-timeout-seconds 5 \
        --healthy-threshold-count 2 \
        --unhealthy-threshold-count 3 \
        --target-type instance \
        --query 'TargetGroups[0].TargetGroupArn' \
        --output text 2>/dev/null)
    
    if [ $? -eq 0 ] && [ ! -z "$TARGET_GROUP_ARN" ]; then
        log_success "타겟 그룹 생성됨: $TARGET_GROUP_ARN"
        echo "$TARGET_GROUP_ARN"
    else
        log_error "타겟 그룹 생성 실패"
        return 1
    fi
}

# 함수: 서브넷 ID 조회
get_subnet_ids() {
    log_info "서브넷 ID 조회 중..."
    
    SUBNET_IDS=$(aws ec2 describe-subnets \
        --filters "Name=vpc-id,Values=$VPC_ID" \
        --query 'Subnets[*].SubnetId' \
        --output text 2>/dev/null)
    
    if [ $? -eq 0 ] && [ ! -z "$SUBNET_IDS" ]; then
        log_success "서브넷 ID 조회됨: $SUBNET_IDS"
        echo "$SUBNET_IDS"
    else
        log_error "서브넷 ID 조회 실패"
        return 1
    fi
}

# 함수: 보안 그룹 ID 조회
get_security_group() {
    log_info "보안 그룹 ID 조회 중..."
    
    SECURITY_GROUP=$(aws ec2 describe-security-groups \
        --filters "Name=vpc-id,Values=$VPC_ID" "Name=group-name,Values=*default*" \
        --query 'SecurityGroups[0].GroupId' \
        --output text 2>/dev/null)
    
    if [ $? -eq 0 ] && [ ! -z "$SECURITY_GROUP" ]; then
        log_success "보안 그룹 ID 조회됨: $SECURITY_GROUP"
        echo "$SECURITY_GROUP"
    else
        log_error "보안 그룹 ID 조회 실패"
        return 1
    fi
}

# 함수: 로드 밸런서 생성
create_load_balancer() {
    local subnet_ids=$1
    local security_group=$2
    
    log_info "로드 밸런서 생성 중..."
    
    ALB_ARN=$(aws elbv2 create-load-balancer \
        --name "cm-day3-alb-$(date +%s)" \
        --subnets $subnet_ids \
        --security-groups "$security_group" \
        --query 'LoadBalancers[0].LoadBalancerArn' \
        --output text 2>/dev/null)
    
    if [ $? -eq 0 ] && [ ! -z "$ALB_ARN" ]; then
        log_success "로드 밸런서 생성됨: $ALB_ARN"
        echo "$ALB_ARN"
    else
        log_error "로드 밸런서 생성 실패"
        return 1
    fi
}

# 함수: 리스너 생성
create_listener() {
    local alb_arn=$1
    local target_group_arn=$2
    
    log_info "리스너 생성 중..."
    
    aws elbv2 create-listener \
        --load-balancer-arn "$alb_arn" \
        --protocol HTTP \
        --port 80 \
        --default-actions Type=forward,TargetGroupArn="$target_group_arn" \
        --output text >/dev/null 2>&1
    
    if [ $? -eq 0 ]; then
        log_success "리스너 생성됨"
    else
        log_error "리스너 생성 실패"
        return 1
    fi
}

# 함수: 인스턴스를 타겟 그룹에 등록
register_targets() {
    local target_group_arn=$1
    local instance_id=$2
    
    log_info "인스턴스를 타겟 그룹에 등록 중..."
    
    aws elbv2 register-targets \
        --target-group-arn "$target_group_arn" \
        --targets "Id=$instance_id,Port=80" \
        --output text >/dev/null 2>&1
    
    if [ $? -eq 0 ]; then
        log_success "인스턴스 등록됨: $instance_id"
    else
        log_error "인스턴스 등록 실패"
        return 1
    fi
}

# 함수: 로드 밸런서 DNS 이름 조회
get_load_balancer_dns() {
    local alb_arn=$1
    
    log_info "로드 밸런서 DNS 이름 조회 중..."
    
    DNS_NAME=$(aws elbv2 describe-load-balancers \
        --load-balancer-arns "$alb_arn" \
        --query 'LoadBalancers[0].DNSName' \
        --output text 2>/dev/null)
    
    if [ $? -eq 0 ] && [ ! -z "$DNS_NAME" ]; then
        log_success "DNS 이름: $DNS_NAME"
        echo "$DNS_NAME"
    else
        log_error "DNS 이름 조회 실패"
        return 1
    fi
}

# 함수: 로드 밸런서 테스트
test_load_balancer() {
    local dns_name=$1
    
    log_info "로드 밸런서 테스트 중..."
    
    # 30초 대기 (로드 밸런서 초기화)
    log_info "로드 밸런서 초기화 대기 중... (30초)"
    sleep 30
    
    # 헬스 체크
    log_info "헬스 체크 실행 중..."
    curl -f "http://$dns_name" >/dev/null 2>&1
    
    if [ $? -eq 0 ]; then
        log_success "로드 밸런서 테스트 성공"
    else
        log_warning "로드 밸런서 테스트 실패 (인스턴스가 아직 준비되지 않았을 수 있음)"
    fi
}

# 메인 실행 함수
main() {
    log_info "AWS 로드 밸런싱 설정 시작"
    
    # 1. 기존 리소스 정리
    cleanup_existing_resources
    
    # 2. 타겟 그룹 생성
    TARGET_GROUP_ARN=$(create_target_group)
    if [ $? -ne 0 ]; then
        log_error "타겟 그룹 생성 실패로 종료"
        exit 1
    fi
    
    # 3. 서브넷 ID 조회
    SUBNET_IDS=$(get_subnet_ids)
    if [ $? -ne 0 ]; then
        log_error "서브넷 ID 조회 실패로 종료"
        exit 1
    fi
    
    # 4. 보안 그룹 ID 조회
    SECURITY_GROUP=$(get_security_group)
    if [ $? -ne 0 ]; then
        log_error "보안 그룹 ID 조회 실패로 종료"
        exit 1
    fi
    
    # 5. 로드 밸런서 생성
    ALB_ARN=$(create_load_balancer "$SUBNET_IDS" "$SECURITY_GROUP")
    if [ $? -ne 0 ]; then
        log_error "로드 밸런서 생성 실패로 종료"
        exit 1
    fi
    
    # 6. 리스너 생성
    create_listener "$ALB_ARN" "$TARGET_GROUP_ARN"
    if [ $? -ne 0 ]; then
        log_error "리스너 생성 실패로 종료"
        exit 1
    fi
    
    # 7. 기존 인스턴스를 타겟 그룹에 등록 (실제 인스턴스 ID로 교체 필요)
    INSTANCE_ID="i-099f55941265d751f"  # WSL 히스토리에서 확인된 인스턴스 ID
    register_targets "$TARGET_GROUP_ARN" "$INSTANCE_ID"
    
    # 8. DNS 이름 조회
    DNS_NAME=$(get_load_balancer_dns "$ALB_ARN")
    if [ $? -ne 0 ]; then
        log_error "DNS 이름 조회 실패로 종료"
        exit 1
    fi
    
    # 9. 로드 밸런서 테스트
    test_load_balancer "$DNS_NAME"
    
    log_success "AWS 로드 밸런싱 설정 완료"
    log_info "로드 밸런서 URL: http://$DNS_NAME"
}

# 스크립트 실행
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
