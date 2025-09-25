#!/bin/bash

# AWS 리소스 정리 스크립트
# MCP Cloud 프로젝트용 AWS 리소스 삭제 및 정리

set -e  # 오류 발생 시 스크립트 종료

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 로그 함수
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 변수 설정 (aws-ec2-create.sh와 동일하게 설정)
PROJECT_NAME="cloud-deployment"
REGION="ap-northeast-2"
AZ="ap-northeast-2a"
KEY_NAME="${PROJECT_NAME}-key"
SECURITY_GROUP_NAME="${PROJECT_NAME}-sg"

log_info "=== AWS 리소스 정리 시작 ==="
log_info "프로젝트명: $PROJECT_NAME"
log_info "리전: $REGION"
log_info "가용영역: $AZ"

# 1. AWS CLI 설정 확인
log_info "AWS CLI 설정 확인 중..."
if ! command -v aws &> /dev/null; then
    log_error "AWS CLI가 설치되지 않았습니다. 먼저 AWS CLI를 설치해주세요."
    exit 1
fi

if ! aws sts get-caller-identity &> /dev/null; then
    log_error "AWS 인증이 설정되지 않았습니다. 'aws configure'를 실행해주세요."
    exit 1
fi

log_success "AWS CLI 설정 확인 완료"

# 2. 현재 리소스 상태 확인
log_info "현재 AWS 리소스 상태 확인 중..."

# EC2 인스턴스 확인
INSTANCES=$(aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=${PROJECT_NAME}-server" "Name=instance-state-name,Values=running,pending,stopping,stopped" \
    --query 'Reservations[*].Instances[*].[InstanceId,State.Name,Tags[?Key==`Name`].Value|[0]]' \
    --output table 2>/dev/null || echo "No instances found")

if [ "$INSTANCES" != "No instances found" ] && [ -n "$INSTANCES" ]; then
    log_warning "EC2 인스턴스가 발견되었습니다:"
    echo "$INSTANCES"
else
    log_info "EC2 인스턴스가 없습니다."
fi

# 보안 그룹 확인
SECURITY_GROUPS=$(aws ec2 describe-security-groups \
    --filters "Name=group-name,Values=${SECURITY_GROUP_NAME}" \
    --query 'SecurityGroups[*].[GroupId,GroupName,Description]' \
    --output table 2>/dev/null || echo "No security groups found")

if [ "$SECURITY_GROUPS" != "No security groups found" ] && [ -n "$SECURITY_GROUPS" ]; then
    log_warning "보안 그룹이 발견되었습니다:"
    echo "$SECURITY_GROUPS"
else
    log_info "보안 그룹이 없습니다."
fi

# 키 페어 확인
KEY_PAIRS=$(aws ec2 describe-key-pairs \
    --key-names $KEY_NAME \
    --query 'KeyPairs[*].[KeyName,KeyPairId]' \
    --output table 2>/dev/null || echo "No key pairs found")

if [ "$KEY_PAIRS" != "No key pairs found" ] && [ -n "$KEY_PAIRS" ]; then
    log_warning "키 페어가 발견되었습니다:"
    echo "$KEY_PAIRS"
else
    log_info "키 페어가 없습니다."
fi

# Elastic IP 확인
EIPS=$(aws ec2 describe-addresses \
    --filters "Name=tag:Name,Values=${PROJECT_NAME}-eip" \
    --query 'Addresses[*].[AllocationId,PublicIp,InstanceId]' \
    --output table 2>/dev/null || echo "No Elastic IPs found")

if [ "$EIPS" != "No Elastic IPs found" ] && [ -n "$EIPS" ]; then
    log_warning "Elastic IP가 발견되었습니다:"
    echo "$EIPS"
else
    log_info "Elastic IP가 없습니다."
fi

# 3. 삭제 확인
echo ""
log_warning "⚠️  주의: 이 작업은 되돌릴 수 없습니다!"
log_warning "프로젝트 '$PROJECT_NAME'의 모든 AWS 리소스가 삭제됩니다."
echo ""
read -p "정말로 삭제하시겠습니까? (yes/no): " -r
if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    log_info "삭제가 취소되었습니다."
    exit 0
fi

# 4. 리소스 정리
log_info "리소스 정리 중..."

# 4.1. EC2 인스턴스 삭제
log_info "EC2 인스턴스 삭제 중..."
INSTANCE_IDS=$(aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=${PROJECT_NAME}-server" "Name=instance-state-name,Values=running,pending,stopping,stopped" \
    --query 'Reservations[*].Instances[*].InstanceId' \
    --output text 2>/dev/null)

if [ -n "$INSTANCE_IDS" ] && [ "$INSTANCE_IDS" != "None" ]; then
    for INSTANCE_ID in $INSTANCE_IDS; do
        if [ -n "$INSTANCE_ID" ]; then
            log_info "인스턴스 삭제: $INSTANCE_ID"
            aws ec2 terminate-instances --instance-ids $INSTANCE_ID > /dev/null
            log_success "인스턴스 $INSTANCE_ID 삭제 요청 완료"
        fi
    done
    
    # 인스턴스 삭제 완료 대기
    log_info "인스턴스 삭제 완료 대기 중..."
    for INSTANCE_ID in $INSTANCE_IDS; do
        if [ -n "$INSTANCE_ID" ]; then
            aws ec2 wait instance-terminated --instance-ids $INSTANCE_ID
            log_success "인스턴스 $INSTANCE_ID 삭제 완료"
        fi
    done
else
    log_info "삭제할 EC2 인스턴스가 없습니다."
fi

# 4.2. Elastic IP 해제
log_info "Elastic IP 해제 중..."
ALLOCATION_IDS=$(aws ec2 describe-addresses \
    --filters "Name=tag:Name,Values=${PROJECT_NAME}-eip" \
    --query 'Addresses[*].AllocationId' \
    --output text 2>/dev/null)

if [ -n "$ALLOCATION_IDS" ] && [ "$ALLOCATION_IDS" != "None" ]; then
    for ALLOCATION_ID in $ALLOCATION_IDS; do
        if [ -n "$ALLOCATION_ID" ]; then
            log_info "Elastic IP 해제: $ALLOCATION_ID"
            aws ec2 release-address --allocation-id $ALLOCATION_ID > /dev/null
            log_success "Elastic IP $ALLOCATION_ID 해제 완료"
        fi
    done
else
    log_info "해제할 Elastic IP가 없습니다."
fi

# 4.3. 보안 그룹 삭제
log_info "보안 그룹 삭제 중..."
SECURITY_GROUP_IDS=$(aws ec2 describe-security-groups \
    --filters "Name=group-name,Values=${SECURITY_GROUP_NAME}" \
    --query 'SecurityGroups[*].GroupId' \
    --output text 2>/dev/null)

if [ -n "$SECURITY_GROUP_IDS" ] && [ "$SECURITY_GROUP_IDS" != "None" ]; then
    for SECURITY_GROUP_ID in $SECURITY_GROUP_IDS; do
        if [ -n "$SECURITY_GROUP_ID" ]; then
            log_info "보안 그룹 삭제: $SECURITY_GROUP_ID"
            aws ec2 delete-security-group --group-id $SECURITY_GROUP_ID > /dev/null
            log_success "보안 그룹 $SECURITY_GROUP_ID 삭제 완료"
        fi
    done
else
    log_info "삭제할 보안 그룹이 없습니다."
fi

# 4.4. 키 페어 삭제
log_info "키 페어 삭제 중..."
if aws ec2 describe-key-pairs --key-names $KEY_NAME &> /dev/null; then
    log_info "키 페어 삭제: $KEY_NAME"
    aws ec2 delete-key-pair --key-name $KEY_NAME > /dev/null
    log_success "키 페어 $KEY_NAME 삭제 완료"
    
    # 로컬 키 파일도 삭제
    KEY_FILE="${KEY_NAME}.pem"
    if [ -f "$KEY_FILE" ]; then
        rm -f "$KEY_FILE"
        log_success "로컬 키 파일 삭제: $KEY_FILE"
    fi
else
    log_info "삭제할 키 페어가 없습니다."
fi

# 4.5. 체크포인트 파일 삭제
CHECKPOINT_FILE="${PROJECT_NAME}-checkpoint.txt"
if [ -f "$CHECKPOINT_FILE" ]; then
    rm -f "$CHECKPOINT_FILE"
    log_success "체크포인트 파일 삭제: $CHECKPOINT_FILE"
fi

# 5. 정리 완료
log_success "=== AWS 리소스 정리 완료 ==="
echo ""
log_info "📋 정리된 리소스:"
echo "  - EC2 인스턴스: $PROJECT_NAME-server"
echo "  - 보안 그룹: $SECURITY_GROUP_NAME"
echo "  - 키 페어: $KEY_NAME"
echo "  - Elastic IP: $PROJECT_NAME-eip (있는 경우)"
echo "  - 로컬 키 파일: ${KEY_NAME}.pem"
echo "  - 체크포인트 파일: $CHECKPOINT_FILE"
echo ""
log_info "💰 비용 절약:"
echo "  - 모든 AWS 리소스가 삭제되어 비용이 발생하지 않습니다."
echo ""
log_info "🔄 재생성:"
echo "  - 필요시 './aws-ec2-create.sh' 스크립트로 리소스를 다시 생성할 수 있습니다."
echo ""
log_warning "📝 참고사항:"
echo "  - 기본 VPC와 서브넷은 삭제되지 않습니다 (AWS 기본 리소스)"
echo "  - 다른 프로젝트에서 사용 중인 리소스는 삭제되지 않습니다"
