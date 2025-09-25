#!/bin/bash

# AWS 설정 도우미 스크립트
# AWS 계정, 리전, VPC 설정을 도와주는 스크립트

set -e

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

echo "=== AWS 설정 도우미 ==="
echo ""

# 1. AWS CLI 설치 확인
if ! command -v aws &> /dev/null; then
    log_error "AWS CLI가 설치되지 않았습니다."
    log_info "다음 링크에서 AWS CLI를 설치하세요:"
    echo "https://aws.amazon.com/cli/"
    exit 1
fi

# 2. 인증 확인
log_info "AWS 인증 상태 확인 중..."
if ! aws sts get-caller-identity &> /dev/null; then
    log_error "AWS 인증이 설정되지 않았습니다."
    log_info "다음 명령어로 인증하세요:"
    echo "aws configure"
    echo "또는"
    echo "aws sso login"
    exit 1
fi

# 3. 계정 정보 표시
log_info "AWS 계정 정보:"
aws sts get-caller-identity --output table || {
    log_error "AWS 계정 정보를 가져올 수 없습니다."
    exit 1
}
echo ""

# 4. 리전 목록 표시
log_info "사용 가능한 리전 목록 (아시아 태평양):"
echo ""
aws ec2 describe-regions --region-names ap-northeast-1 ap-northeast-2 ap-northeast-3 ap-southeast-1 ap-southeast-2 \
    --query 'Regions[*].[RegionName,RegionName]' --output table || {
    log_error "리전 목록을 가져올 수 없습니다."
    exit 1
}
echo ""

# 5. 리전 선택
read -p "사용할 리전을 입력하세요 (예: ap-northeast-2) [기본값: ap-northeast-2]: " SELECTED_REGION
SELECTED_REGION=${SELECTED_REGION:-ap-northeast-2}

# 리전 유효성 검사
if ! aws ec2 describe-regions --region-names $SELECTED_REGION &> /dev/null; then
    log_error "리전 '$SELECTED_REGION'이 유효하지 않습니다."
    exit 1
fi

aws configure set region $SELECTED_REGION
log_success "리전이 '$SELECTED_REGION'로 설정되었습니다."
echo ""

# 6. VPC 확인
log_info "VPC 확인 중..."
VPC_LIST=$(aws ec2 describe-vpcs --region $SELECTED_REGION --query 'Vpcs[*].[VpcId,IsDefault,State]' --output table)
echo "$VPC_LIST"
echo ""

# 기본 VPC 확인
DEFAULT_VPC=$(aws ec2 describe-vpcs --region $SELECTED_REGION --filters "Name=is-default,Values=true" --query 'Vpcs[0].VpcId' --output text 2>/dev/null)

if [ -n "$DEFAULT_VPC" ] && [ "$DEFAULT_VPC" != "None" ]; then
    log_success "기본 VPC 발견: $DEFAULT_VPC"
    read -p "기본 VPC를 사용하시겠습니까? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        SELECTED_VPC=$DEFAULT_VPC
        log_success "기본 VPC '$DEFAULT_VPC'를 사용합니다."
    else
        read -p "사용할 VPC ID를 입력하세요: " SELECTED_VPC
    fi
else
    log_warning "기본 VPC가 없습니다."
    read -p "사용할 VPC ID를 입력하세요: " SELECTED_VPC
fi

# VPC 유효성 검사
if ! aws ec2 describe-vpcs --region $SELECTED_REGION --vpc-ids $SELECTED_VPC &> /dev/null; then
    log_error "VPC '$SELECTED_VPC'가 유효하지 않습니다."
    exit 1
fi

log_success "VPC '$SELECTED_VPC'가 선택되었습니다."
echo ""

# 7. 서브넷 확인
log_info "서브넷 확인 중..."
SUBNET_LIST=$(aws ec2 describe-subnets --region $SELECTED_REGION --filters "Name=vpc-id,Values=$SELECTED_VPC" --query 'Subnets[*].[SubnetId,AvailabilityZone,CidrBlock]' --output table)
echo "$SUBNET_LIST"
echo ""

# 8. 서브넷 선택
read -p "사용할 서브넷 ID를 입력하세요: " SELECTED_SUBNET

# 서브넷 유효성 검사
if ! aws ec2 describe-subnets --region $SELECTED_REGION --subnet-ids $SELECTED_SUBNET &> /dev/null; then
    log_error "서브넷 '$SELECTED_SUBNET'가 유효하지 않습니다."
    exit 1
fi

log_success "서브넷 '$SELECTED_SUBNET'가 선택되었습니다."
echo ""

# 9. 설정 확인
log_success "=== AWS 설정 완료 ==="
echo "리전: $SELECTED_REGION"
echo "VPC: $SELECTED_VPC"
echo "서브넷: $SELECTED_SUBNET"
echo ""

# 10. 스크립트 실행 안내
log_info "이제 다음 명령어로 가상머신을 생성할 수 있습니다:"
echo "./aws-ec2-create.sh"
echo ""

# 11. 환경 파일 생성
ENV_FILE="aws-environment.env"
log_info "환경 파일 생성 중: $ENV_FILE"

cat > "$ENV_FILE" << EOF
# AWS 환경 설정 파일
# 이 파일은 aws-setup-helper.sh에 의해 자동 생성되었습니다.
# 생성 시간: $(date)

# AWS 계정 정보
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
AWS_USER_ARN=$(aws sts get-caller-identity --query Arn --output text)

# AWS 리전 및 네트워크 설정
REGION="$SELECTED_REGION"
VPC_ID="$SELECTED_VPC"
SUBNET_ID="$SELECTED_SUBNET"

# 환경 변수 내보내기
export AWS_DEFAULT_REGION="\$REGION"
export AWS_REGION="\$REGION"
export AWS_VPC_ID="\$VPC_ID"
export AWS_SUBNET_ID="\$SUBNET_ID"
EOF

log_success "환경 파일이 생성되었습니다: $ENV_FILE"

# 12. 스크립트 변수 업데이트 안내
log_info "이제 다음 방법으로 환경을 로드할 수 있습니다:"
echo "source $ENV_FILE"
echo ""
log_info "또는 스크립트 상단의 변수를 다음과 같이 설정하세요:"
echo "REGION=\"$SELECTED_REGION\""
echo "VPC_ID=\"$SELECTED_VPC\""
echo "SUBNET_ID=\"$SELECTED_SUBNET\""
echo ""
