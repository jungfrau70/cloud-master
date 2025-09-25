#!/bin/bash
# Basic → Master 과정 연계 브리지 스크립트
# Cloud Basic 과정에서 생성된 리소스를 Cloud Master 과정에서 활용할 수 있도록 설정

set -e

echo "🔗 Cloud Basic → Cloud Master 연계 설정 시작..."

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

# 공유 리소스 디렉토리 확인
SHARED_DIR="../../shared_resources"
if [ ! -d "$SHARED_DIR" ]; then
    log_error "공유 리소스 디렉토리를 찾을 수 없습니다: $SHARED_DIR"
    exit 1
fi

# 1. Basic 과정에서 생성된 AWS 리소스 확인
log_info "AWS 리소스 상태 확인 중..."
if command -v aws &> /dev/null; then
    # VPC 정보 확인
    VPC_ID=$(aws ec2 describe-vpcs --query 'Vpcs[0].VpcId' --output text 2>/dev/null || echo "")
    if [ -n "$VPC_ID" ] && [ "$VPC_ID" != "None" ]; then
        log_success "VPC 발견: $VPC_ID"
        echo "VPC_ID=$VPC_ID" > "$SHARED_DIR/aws_resources.env"
        
        # 서브넷 정보 확인
        SUBNET_ID=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" --query 'Subnets[0].SubnetId' --output text 2>/dev/null || echo "")
        if [ -n "$SUBNET_ID" ] && [ "$SUBNET_ID" != "None" ]; then
            log_success "서브넷 발견: $SUBNET_ID"
            echo "SUBNET_ID=$SUBNET_ID" >> "$SHARED_DIR/aws_resources.env"
        fi
        
        # 보안 그룹 정보 확인
        SECURITY_GROUP_ID=$(aws ec2 describe-security-groups --filters "Name=vpc-id,Values=$VPC_ID" --query 'SecurityGroups[0].GroupId' --output text 2>/dev/null || echo "")
        if [ -n "$SECURITY_GROUP_ID" ] && [ "$SECURITY_GROUP_ID" != "None" ]; then
            log_success "보안 그룹 발견: $SECURITY_GROUP_ID"
            echo "SECURITY_GROUP_ID=$SECURITY_GROUP_ID" >> "$SHARED_DIR/aws_resources.env"
        fi
    else
        log_warning "AWS VPC를 찾을 수 없습니다. Master 과정에서 새로 생성합니다."
    fi
    
    # S3 버킷 정보 확인
    S3_BUCKET=$(aws s3 ls --query 'Buckets[0].Name' --output text 2>/dev/null || echo "")
    if [ -n "$S3_BUCKET" ] && [ "$S3_BUCKET" != "None" ]; then
        log_success "S3 버킷 발견: $S3_BUCKET"
        echo "S3_BUCKET=$S3_BUCKET" >> "$SHARED_DIR/aws_resources.env"
    fi
else
    log_warning "AWS CLI가 설치되지 않았습니다."
fi

# 2. Basic 과정에서 생성된 GCP 리소스 확인
log_info "GCP 리소스 상태 확인 중..."
if command -v gcloud &> /dev/null; then
    # 현재 프로젝트 확인
    GCP_PROJECT=$(gcloud config get-value project 2>/dev/null || echo "")
    if [ -n "$GCP_PROJECT" ]; then
        log_success "GCP 프로젝트 발견: $GCP_PROJECT"
        echo "GCP_PROJECT=$GCP_PROJECT" > "$SHARED_DIR/gcp_resources.env"
        
        # VPC 네트워크 확인
        GCP_NETWORK=$(gcloud compute networks list --filter="name~cloud-training" --format="value(name)" --limit=1 2>/dev/null || echo "")
        if [ -n "$GCP_NETWORK" ]; then
            log_success "GCP VPC 네트워크 발견: $GCP_NETWORK"
            echo "GCP_NETWORK=$GCP_NETWORK" >> "$SHARED_DIR/gcp_resources.env"
        fi
        
        # 서브넷 확인
        GCP_SUBNET=$(gcloud compute networks subnets list --filter="name~cloud-training" --format="value(name)" --limit=1 2>/dev/null || echo "")
        if [ -n "$GCP_SUBNET" ]; then
            log_success "GCP 서브넷 발견: $GCP_SUBNET"
            echo "GCP_SUBNET=$GCP_SUBNET" >> "$SHARED_DIR/gcp_resources.env"
        fi
    else
        log_warning "GCP 프로젝트가 설정되지 않았습니다."
    fi
else
    log_warning "GCP CLI가 설치되지 않았습니다."
fi

# 3. 환경 변수 설정
log_info "환경 변수 설정 중..."
if [ -f "$SHARED_DIR/aws_resources.env" ]; then
    source "$SHARED_DIR/aws_resources.env"
    log_success "AWS 환경 변수 로드 완료"
fi

if [ -f "$SHARED_DIR/gcp_resources.env" ]; then
    source "$SHARED_DIR/gcp_resources.env"
    log_success "GCP 환경 변수 로드 완료"
fi

# 4. Master 과정용 설정 파일 생성
log_info "Master 과정용 설정 파일 생성 중..."
cat > "$SHARED_DIR/master_course_config.env" << EOF
# Cloud Master 과정 설정
# Basic 과정에서 전달받은 리소스 정보

# AWS 리소스
export AWS_VPC_ID=${VPC_ID:-""}
export AWS_SUBNET_ID=${SUBNET_ID:-""}
export AWS_SECURITY_GROUP_ID=${SECURITY_GROUP_ID:-""}
export AWS_S3_BUCKET=${S3_BUCKET:-""}

# GCP 리소스
export GCP_PROJECT_ID=${GCP_PROJECT:-""}
export GCP_NETWORK_NAME=${GCP_NETWORK:-""}
export GCP_SUBNET_NAME=${GCP_SUBNET:-""}

# 공통 설정
export PROJECT_PREFIX="cloud-training"
export AWS_REGION="us-west-2"
export GCP_REGION="us-central1"
export DOCKER_REGISTRY="docker.io"
export GITHUB_ORG="cloud-training-org"

# Master 과정에서 사용할 추가 설정
export ENABLE_CI_CD=true
export ENABLE_MONITORING=true
export ENABLE_LOGGING=true
EOF

log_success "Master 과정 설정 파일 생성 완료: $SHARED_DIR/master_course_config.env"

# 5. Docker 환경 준비
log_info "Docker 환경 준비 중..."
if command -v docker &> /dev/null; then
    # Docker 서비스 상태 확인
    if docker info &> /dev/null; then
        log_success "Docker 서비스 실행 중"
        
        # 기본 이미지 풀
        log_info "기본 Docker 이미지 다운로드 중..."
        docker pull nginx:alpine || log_warning "nginx:alpine 이미지 다운로드 실패"
        docker pull node:18-alpine || log_warning "node:18-alpine 이미지 다운로드 실패"
        docker pull python:3.11-slim || log_warning "python:3.11-slim 이미지 다운로드 실패"
        
        log_success "Docker 환경 준비 완료"
    else
        log_warning "Docker 서비스가 실행되지 않았습니다."
    fi
else
    log_warning "Docker가 설치되지 않았습니다."
fi

# 6. Git 환경 준비
log_info "Git 환경 준비 중..."
if command -v git &> /dev/null; then
    # Git 사용자 정보 확인
    GIT_USER_NAME=$(git config --global user.name 2>/dev/null || echo "")
    GIT_USER_EMAIL=$(git config --global user.email 2>/dev/null || echo "")
    
    if [ -z "$GIT_USER_NAME" ] || [ -z "$GIT_USER_EMAIL" ]; then
        log_warning "Git 사용자 정보가 설정되지 않았습니다."
        log_info "다음 명령어로 Git 사용자 정보를 설정하세요:"
        echo "  git config --global user.name 'Your Name'"
        echo "  git config --global user.email 'your.email@example.com'"
    else
        log_success "Git 사용자 정보 확인: $GIT_USER_NAME <$GIT_USER_EMAIL>"
    fi
else
    log_warning "Git이 설치되지 않았습니다."
fi

# 7. 연계 상태 저장
log_info "연계 상태 저장 중..."
cat > "$SHARED_DIR/basic_to_master_bridge_status.json" << EOF
{
  "bridge_name": "basic_to_master",
  "completed_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "aws_resources": {
    "vpc_id": "${VPC_ID:-null}",
    "subnet_id": "${SUBNET_ID:-null}",
    "security_group_id": "${SECURITY_GROUP_ID:-null}",
    "s3_bucket": "${S3_BUCKET:-null}"
  },
  "gcp_resources": {
    "project_id": "${GCP_PROJECT:-null}",
    "network_name": "${GCP_NETWORK:-null}",
    "subnet_name": "${GCP_SUBNET:-null}"
  },
  "status": "completed"
}
EOF

log_success "연계 상태 저장 완료"

# 8. Master 과정 실행 준비
log_info "Master 과정 실행 준비 중..."
MASTER_SCRIPT="../../cloud_master/automation_tests/master_course_automation.py"
if [ -f "$MASTER_SCRIPT" ]; then
    log_success "Master 과정 스크립트 발견: $MASTER_SCRIPT"
    log_info "Master 과정을 실행하려면 다음 명령어를 사용하세요:"
    echo "  cd ../../cloud_master/automation_tests"
    echo "  source ../../integrated_automation/shared_resources/master_course_config.env"
    echo "  python master_course_automation.py"
else
    log_warning "Master 과정 스크립트를 찾을 수 없습니다: $MASTER_SCRIPT"
fi

log_success "🎉 Cloud Basic → Cloud Master 연계 설정 완료!"
log_info "다음 단계: Master 과정 실행"
