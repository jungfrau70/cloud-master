#!/bin/bash

# VPC 진단 스크립트
# VPC 삭제 실패 원인을 분석합니다.

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

# VPC ID 입력 받기
if [ -z "$1" ]; then
    echo "사용법: $0 <VPC_ID>"
    echo "예시: $0 vpc-02817770456cc5f5d"
    exit 1
fi

VPC_ID="$1"

log_info "=== VPC 진단 시작: $VPC_ID ==="

# VPC 존재 확인
log_info "1. VPC 존재 확인..."
vpc_info=$(aws ec2 describe-vpcs --vpc-ids "$VPC_ID" 2>/dev/null)
if [ -z "$vpc_info" ]; then
    log_error "VPC를 찾을 수 없습니다: $VPC_ID"
    exit 1
fi
log_success "VPC 존재 확인됨"

# ENI 확인
log_info "2. ENI (Elastic Network Interface) 확인..."
enis=$(aws ec2 describe-network-interfaces \
    --filters "Name=vpc-id,Values=$VPC_ID" \
    --query 'NetworkInterfaces[*].[NetworkInterfaceId,Status,Description]' \
    --output table 2>/dev/null)

if [ -n "$enis" ] && [ "$enis" != "None" ]; then
    log_warning "ENI가 발견되었습니다:"
    echo "$enis"
else
    log_success "ENI 없음"
fi

# NAT Gateway 확인
log_info "3. NAT Gateway 확인..."
nat_gateways=$(aws ec2 describe-nat-gateways \
    --filter "Name=vpc-id,Values=$VPC_ID" \
    --query 'NatGateways[*].[NatGatewayId,State,SubnetId]' \
    --output table 2>/dev/null)

if [ -n "$nat_gateways" ] && [ "$nat_gateways" != "None" ]; then
    log_warning "NAT Gateway가 발견되었습니다:"
    echo "$nat_gateways"
else
    log_success "NAT Gateway 없음"
fi

# VPC Endpoint 확인
log_info "4. VPC Endpoint 확인..."
vpc_endpoints=$(aws ec2 describe-vpc-endpoints \
    --filters "Name=vpc-id,Values=$VPC_ID" \
    --query 'VpcEndpoints[*].[VpcEndpointId,State,ServiceName]' \
    --output table 2>/dev/null)

if [ -n "$vpc_endpoints" ] && [ "$vpc_endpoints" != "None" ]; then
    log_warning "VPC Endpoint가 발견되었습니다:"
    echo "$vpc_endpoints"
else
    log_success "VPC Endpoint 없음"
fi

# EKS 클러스터 확인
log_info "5. EKS 클러스터 확인..."
eks_clusters=$(aws eks list-clusters --query 'clusters[*]' --output text 2>/dev/null)
if [ -n "$eks_clusters" ]; then
    for cluster in $eks_clusters; do
        cluster_vpc=$(aws eks describe-cluster --name "$cluster" --query 'cluster.resourcesVpcConfig.vpcId' --output text 2>/dev/null)
        if [ "$cluster_vpc" = "$VPC_ID" ]; then
            log_warning "EKS 클러스터가 이 VPC를 사용 중입니다: $cluster"
        fi
    done
else
    log_success "EKS 클러스터 없음"
fi

# RDS 인스턴스 확인
log_info "6. RDS 인스턴스 확인..."
rds_instances=$(aws rds describe-db-instances \
    --query 'DBInstances[?DBSubnetGroup.VpcId==`'$VPC_ID'`].[DBInstanceIdentifier,DBInstanceStatus]' \
    --output table 2>/dev/null)

if [ -n "$rds_instances" ] && [ "$rds_instances" != "None" ]; then
    log_warning "RDS 인스턴스가 이 VPC를 사용 중입니다:"
    echo "$rds_instances"
else
    log_success "RDS 인스턴스 없음"
fi

# ELB 확인
log_info "7. ELB (Elastic Load Balancer) 확인..."
elbs=$(aws elbv2 describe-load-balancers \
    --query 'LoadBalancers[?VpcId==`'$VPC_ID'`].[LoadBalancerName,State.Code]' \
    --output table 2>/dev/null)

if [ -n "$elbs" ] && [ "$elbs" != "None" ]; then
    log_warning "ELB가 이 VPC를 사용 중입니다:"
    echo "$elbs"
else
    log_success "ELB 없음"
fi

# VPC 삭제 시도 및 오류 메시지 확인
log_info "8. VPC 삭제 시도 및 오류 분석..."
delete_output=$(aws ec2 delete-vpc --vpc-id "$VPC_ID" 2>&1)
delete_result=$?

if [ $delete_result -eq 0 ]; then
    log_success "VPC 삭제 성공!"
else
    log_error "VPC 삭제 실패"
    log_error "오류 메시지: $delete_output"
    
    # 오류 메시지 분석
    if echo "$delete_output" | grep -q "DependencyViolation"; then
        log_warning "종속 리소스가 남아있어 삭제할 수 없습니다."
        log_info "해결 방법:"
        log_info "1. 위에서 확인된 리소스들을 먼저 삭제하세요"
        log_info "2. AWS 콘솔에서 VPC를 확인하세요"
    elif echo "$delete_output" | grep -q "InvalidVpcID.NotFound"; then
        log_warning "VPC가 이미 삭제되었거나 존재하지 않습니다."
    else
        log_warning "알 수 없는 오류입니다."
    fi
fi

log_info "=== VPC 진단 완료 ==="
