ㅏㅕㅠㅠ#!/bin/bash

# VPC 정리 스크립트
# 디폴트 VPC를 제외한 모든 VPC를 삭제합니다.

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

# 현재 리전 확인
REGION=$(aws configure get region)
if [ -z "$REGION" ]; then
    REGION="ap-northeast-2"
    aws configure set region "$REGION"
fi

log_info "=== VPC 정리 스크립트 시작 ==="
log_info "리전: $REGION"

# AWS CLI 설치 확인
if ! command -v aws &> /dev/null; then
    log_error "AWS CLI가 설치되지 않았습니다."
    exit 1
fi

# AWS 자격 증명 확인
if ! aws sts get-caller-identity &> /dev/null; then
    log_error "AWS 자격 증명이 설정되지 않았습니다."
    log_error "aws configure를 실행하여 자격 증명을 설정하세요."
    exit 1
fi

# 모든 VPC 목록 조회 (디폴트 VPC 제외)
log_info "VPC 목록 조회 중..."

VPC_LIST=$(aws ec2 describe-vpcs \
    --filters "Name=is-default,Values=false" "Name=state,Values=available" \
    --query 'Vpcs[*].[VpcId,Tags[?Key==`Name`].Value|[0],CidrBlock]' \
    --output text 2>/dev/null)

if [ -z "$VPC_LIST" ]; then
    log_info "삭제할 VPC가 없습니다."
    exit 0
fi

echo ""
log_warning "다음 VPC들이 삭제됩니다:"
echo "----------------------------------------"
printf "%-20s %-30s %-20s\n" "VPC ID" "Name" "CIDR Block"
echo "----------------------------------------"
echo "$VPC_LIST" | while read -r vpc_id name cidr; do
    if [ -n "$vpc_id" ]; then
        printf "%-20s %-30s %-20s\n" "$vpc_id" "${name:-N/A}" "$cidr"
    fi
done
echo "----------------------------------------"

# 사용자 선택
echo ""
log_warning "⚠️  주의: 이 작업은 되돌릴 수 없습니다!"
echo ""
echo "삭제 옵션을 선택하세요:"
echo "1. 모든 VPC 삭제"
echo "2. 개별 VPC 선택 삭제"
echo "3. 취소"
echo -n "선택 (1-3): "
read -r choice

case $choice in
    1)
        log_info "모든 VPC를 삭제합니다."
        VPC_TO_DELETE="$VPC_LIST"
        ;;
    2)
        log_info "개별 VPC를 선택합니다."
        VPC_TO_DELETE=""
        
        # VPC 목록을 배열로 변환
        declare -a vpc_array
        while IFS= read -r line; do
            if [ -n "$line" ]; then
                vpc_array+=("$line")
            fi
        done <<< "$VPC_LIST"
        
        echo ""
        log_info "삭제할 VPC를 선택하세요 (번호 입력, 여러 개는 공백으로 구분, 예: 1 3 4):"
        for i in "${!vpc_array[@]}"; do
            vpc_id=$(echo "${vpc_array[$i]}" | cut -d' ' -f1)
            name=$(echo "${vpc_array[$i]}" | cut -d' ' -f2)
            cidr=$(echo "${vpc_array[$i]}" | cut -d' ' -f3)
            echo "$((i+1)). $vpc_id ($name) - $cidr"
        done
        
        echo -n "선택: "
        read -r selections
        
        if [ -z "$selections" ]; then
            log_info "선택이 없어 작업을 취소합니다."
            exit 0
        fi
        
        # 선택된 VPC들 추출
        for selection in $selections; do
            if [ "$selection" -ge 1 ] && [ "$selection" -le "${#vpc_array[@]}" ]; then
                index=$((selection-1))
                VPC_TO_DELETE="$VPC_TO_DELETE"$'\n'"${vpc_array[$index]}"
            else
                log_warning "잘못된 선택: $selection (무시됨)"
            fi
        done
        
        if [ -z "$VPC_TO_DELETE" ]; then
            log_info "유효한 선택이 없어 작업을 취소합니다."
            exit 0
        fi
        ;;
    3)
        log_info "작업이 취소되었습니다."
        exit 0
        ;;
    *)
        log_error "잘못된 선택입니다."
        exit 1
        ;;
esac

# VPC 삭제 함수
delete_vpc() {
    local vpc_id="$1"
    local vpc_name="$2"
    
    log_info "VPC 삭제 중: $vpc_id ($vpc_name)"
    
    # 1. 인터넷 게이트웨이 분리 및 삭제
    local igw_id=$(aws ec2 describe-internet-gateways \
        --filters "Name=attachment.vpc-id,Values=$vpc_id" \
        --query 'InternetGateways[0].InternetGatewayId' \
        --output text 2>/dev/null)
    
    if [ -n "$igw_id" ] && [ "$igw_id" != "None" ]; then
        log_info "인터넷 게이트웨이 분리 중: $igw_id"
        aws ec2 detach-internet-gateway \
            --internet-gateway-id "$igw_id" \
            --vpc-id "$vpc_id" 2>/dev/null
        
        log_info "인터넷 게이트웨이 삭제 중: $igw_id"
        aws ec2 delete-internet-gateway \
            --internet-gateway-id "$igw_id" 2>/dev/null
    fi
    
    # 2. 서브넷 삭제
    local subnets=$(aws ec2 describe-subnets \
        --filters "Name=vpc-id,Values=$vpc_id" \
        --query 'Subnets[*].SubnetId' \
        --output text 2>/dev/null)
    
    if [ -n "$subnets" ] && [ "$subnets" != "None" ]; then
        for subnet_id in $subnets; do
            log_info "서브넷 삭제 중: $subnet_id"
            aws ec2 delete-subnet --subnet-id "$subnet_id" 2>/dev/null
        done
    fi
    
    # 3. 라우트 테이블 삭제 (메인 라우트 테이블 제외)
    local route_tables=$(aws ec2 describe-route-tables \
        --filters "Name=vpc-id,Values=$vpc_id" "Name=association.main,Values=false" \
        --query 'RouteTables[*].RouteTableId' \
        --output text 2>/dev/null)
    
    if [ -n "$route_tables" ] && [ "$route_tables" != "None" ]; then
        for rt_id in $route_tables; do
            log_info "라우트 테이블 삭제 중: $rt_id"
            aws ec2 delete-route-table --route-table-id "$rt_id" 2>/dev/null
        done
    fi
    
    # 4. 보안 그룹 삭제 (디폴트 보안 그룹 제외)
    local security_groups=$(aws ec2 describe-security-groups \
        --filters "Name=vpc-id,Values=$vpc_id" "Name=group-name,Values=!default" \
        --query 'SecurityGroups[*].GroupId' \
        --output text 2>/dev/null)
    
    if [ -n "$security_groups" ] && [ "$security_groups" != "None" ]; then
        for sg_id in $security_groups; do
            log_info "보안 그룹 삭제 중: $sg_id"
            aws ec2 delete-security-group --group-id "$sg_id" 2>/dev/null
        done
    fi
    
    # 5. 네트워크 ACL 삭제 (디폴트 네트워크 ACL 제외)
    local network_acls=$(aws ec2 describe-network-acls \
        --filters "Name=vpc-id,Values=$vpc_id" "Name=default,Values=false" \
        --query 'NetworkAcls[*].NetworkAclId' \
        --output text 2>/dev/null)
    
    if [ -n "$network_acls" ] && [ "$network_acls" != "None" ]; then
        for nacl_id in $network_acls; do
            log_info "네트워크 ACL 삭제 중: $nacl_id"
            aws ec2 delete-network-acl --network-acl-id "$nacl_id" 2>/dev/null
        done
    fi
    
    # 6. VPC 삭제
    log_info "VPC 삭제 중: $vpc_id"
    
    # VPC 삭제 시도 및 오류 메시지 캡처
    local delete_output
    delete_output=$(aws ec2 delete-vpc --vpc-id "$vpc_id" 2>&1)
    local delete_result=$?
    
    if [ $delete_result -eq 0 ]; then
        log_success "VPC 삭제 완료: $vpc_id ($vpc_name)"
        return 0
    else
        log_error "VPC 삭제 실패: $vpc_id"
        log_error "오류 메시지: $delete_output"
        
        # 종속 리소스 확인
        log_info "종속 리소스 확인 중..."
        
        # ENI 확인
        local enis=$(aws ec2 describe-network-interfaces \
            --filters "Name=vpc-id,Values=$vpc_id" \
            --query 'NetworkInterfaces[*].NetworkInterfaceId' \
            --output text 2>/dev/null)
        
        if [ -n "$enis" ] && [ "$enis" != "None" ]; then
            log_warning "ENI가 남아있습니다: $enis"
            for eni in $enis; do
                log_info "ENI 삭제 시도: $eni"
                aws ec2 delete-network-interface --network-interface-id "$eni" 2>/dev/null
            done
        fi
        
        # NAT Gateway 확인
        local nat_gateways=$(aws ec2 describe-nat-gateways \
            --filter "Name=vpc-id,Values=$vpc_id" "Name=state,Values=available,pending" \
            --query 'NatGateways[*].NatGatewayId' \
            --output text 2>/dev/null)
        
        if [ -n "$nat_gateways" ] && [ "$nat_gateways" != "None" ]; then
            log_warning "NAT Gateway가 남아있습니다: $nat_gateways"
            for nat in $nat_gateways; do
                log_info "NAT Gateway 삭제 시도: $nat"
                aws ec2 delete-nat-gateway --nat-gateway-id "$nat" 2>/dev/null
            done
        fi
        
        # VPC Endpoint 확인
        local vpc_endpoints=$(aws ec2 describe-vpc-endpoints \
            --filters "Name=vpc-id,Values=$vpc_id" \
            --query 'VpcEndpoints[*].VpcEndpointId' \
            --output text 2>/dev/null)
        
        if [ -n "$vpc_endpoints" ] && [ "$vpc_endpoints" != "None" ]; then
            log_warning "VPC Endpoint가 남아있습니다: $vpc_endpoints"
            for endpoint in $vpc_endpoints; do
                log_info "VPC Endpoint 삭제 시도: $endpoint"
                aws ec2 delete-vpc-endpoint --vpc-endpoint-id "$endpoint" 2>/dev/null
            done
        fi
        
        # 다시 VPC 삭제 시도
        log_info "종속 리소스 정리 후 VPC 삭제 재시도..."
        if aws ec2 delete-vpc --vpc-id "$vpc_id" 2>/dev/null; then
            log_success "VPC 삭제 완료 (재시도): $vpc_id ($vpc_name)"
            return 0
        else
            log_error "VPC 삭제 최종 실패: $vpc_id"
            log_error "수동으로 AWS 콘솔에서 확인하세요."
            return 1
        fi
    fi
}

# 선택된 VPC 목록 표시
echo ""
log_info "삭제할 VPC 목록:"
echo "----------------------------------------"
printf "%-20s %-30s %-20s\n" "VPC ID" "Name" "CIDR Block"
echo "----------------------------------------"
echo "$VPC_TO_DELETE" | while read -r vpc_id name cidr; do
    if [ -n "$vpc_id" ]; then
        printf "%-20s %-30s %-20s\n" "$vpc_id" "${name:-N/A}" "$cidr"
    fi
done
echo "----------------------------------------"

# 최종 확인
echo ""
echo -n "정말로 이 VPC들을 삭제하시겠습니까? (yes/no): "
read -r final_confirmation

if [ "$final_confirmation" != "yes" ]; then
    log_info "작업이 취소되었습니다."
    exit 0
fi

# VPC 삭제 실행
deleted_count=0
failed_count=0

echo "$VPC_TO_DELETE" | while read -r vpc_id name cidr; do
    if [ -n "$vpc_id" ]; then
        if delete_vpc "$vpc_id" "$name"; then
            deleted_count=$((deleted_count + 1))
        else
            failed_count=$((failed_count + 1))
        fi
        echo "" # 빈 줄 추가
    fi
done

# 결과 요약
log_info "=== VPC 정리 완료 ==="
log_success "삭제된 VPC: $deleted_count개"
if [ $failed_count -gt 0 ]; then
    log_warning "삭제 실패: $failed_count개"
    log_warning "일부 VPC는 종속 리소스로 인해 삭제되지 않았을 수 있습니다."
    log_warning "AWS 콘솔에서 수동으로 확인하세요."
fi

log_info "VPC 정리 스크립트 완료"
