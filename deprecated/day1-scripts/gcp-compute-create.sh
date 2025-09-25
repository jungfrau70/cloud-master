#!/bin/bash

# GCP Compute Engine 가상머신 생성 스크립트
# MCP Cloud 프로젝트용 GCE 인스턴스 생성 및 설정

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

# 환경 파일 자동 로드
ENV_FILE="gcp-environment.env"
if [ -f "$ENV_FILE" ]; then
    log_info "환경 파일 로드 중: $ENV_FILE"
    source "$ENV_FILE"
    log_success "환경 파일이 로드되었습니다."
    log_info "로드된 설정:"
    echo "  - 프로젝트: $GCP_PROJECT_ID"
    echo "  - 리전: $REGION"
    echo "  - 존: $ZONE"
    echo "  - 계정: $GCP_ACCOUNT"
else
    log_warning "환경 파일을 찾을 수 없습니다: $ENV_FILE"
    log_info "gcp-setup-helper.sh를 먼저 실행하세요."
    echo ""
    log_info "수동 설정을 계속하시겠습니까? (y/N)"
    read -r response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        log_info "스크립트를 종료합니다."
        exit 0
    fi
fi

# 변수 설정 (환경 파일에서 로드되지 않은 경우 기본값 사용)
PROJECT_NAME="cloud-deployment"
PROJECT_ID="${GCP_PROJECT_ID:-$(gcloud config get-value project 2>/dev/null)}"
REGION="${REGION:-$(gcloud config get-value compute/region 2>/dev/null)}"
ZONE="${ZONE:-$(gcloud config get-value compute/zone 2>/dev/null)}"
MACHINE_TYPE="e2-medium"
IMAGE_FAMILY="ubuntu-2204-lts"
IMAGE_PROJECT="ubuntu-os-cloud"
# 사용자 이름 설정 (프로젝트 메타데이터 SSH 키 사용)
CURRENT_USER=$(gcloud config get-value account 2>/dev/null)
if [ -n "$CURRENT_USER" ]; then
    # 이메일에서 @ 앞부분만 추출하여 사용자 이름으로 사용
    USER=$(echo "$CURRENT_USER" | cut -d'@' -f1)
else
    USER="ubuntu"  # 기본 Ubuntu 사용자
fi
INSTANCE_NAME="${PROJECT_NAME}-server"
NETWORK_NAME="${PROJECT_NAME}-vpc"
SUBNET_NAME="${PROJECT_NAME}-subnet"
FIREWALL_RULE_SSH="${PROJECT_NAME}-allow-ssh"
FIREWALL_RULE_HTTP="${PROJECT_NAME}-allow-http"
FIREWALL_RULE_HTTPS="${PROJECT_NAME}-allow-https"
FIREWALL_RULE_APP="${PROJECT_NAME}-allow-app"

log_info "=== GCP Compute Engine 가상머신 생성 시작 ==="
log_info "프로젝트명: $PROJECT_NAME"
log_info "리전: $REGION"
log_info "존: $ZONE"

# 체크포인트 파일 설정 (스크립트 중단 시 재시작 지원)
CHECKPOINT_FILE="${PROJECT_NAME}-checkpoint.txt"
log_info "체크포인트 파일: $CHECKPOINT_FILE"

# 체크포인트 함수
checkpoint() {
    echo "$1" > "$CHECKPOINT_FILE"
    log_info "체크포인트 저장: $1"
}

# 체크포인트 확인 함수
check_checkpoint() {
    if [ -f "$CHECKPOINT_FILE" ]; then
        local checkpoint=$(cat "$CHECKPOINT_FILE")
        log_info "이전 체크포인트 발견: $checkpoint"
        return 0
    fi
    return 1
}

# 체크포인트 삭제 함수
clear_checkpoint() {
    rm -f "$CHECKPOINT_FILE"
    log_info "체크포인트 삭제 완료"
}

# 체크포인트 기반 재시작 로직
if check_checkpoint; then
    checkpoint=$(cat "$CHECKPOINT_FILE")
    log_info "이전 실행에서 중단된 지점을 발견했습니다: $checkpoint"
    log_info "중단된 지점부터 재시작합니다..."
    
    case "$checkpoint" in
        "project_setup_complete"|"api_enabled"|"ssh_keys_ready")
            log_info "프로젝트 설정 및 SSH 키가 준비되었습니다. 네트워크 설정부터 재시작합니다."
            ;;
        "vpc_ready"|"subnet_ready"|"firewall_ready")
            log_info "네트워크 및 보안 설정이 완료되었습니다. 인스턴스 생성부터 재시작합니다."
            ;;
        "instance_created"|"instance_ready")
            log_info "인스턴스가 이미 생성되었습니다. 상태 확인부터 재시작합니다."
            ;;
        *)
            log_info "알 수 없는 체크포인트입니다. 처음부터 시작합니다."
            ;;
    esac
fi

# 1. GCP CLI 설정 확인
log_info "GCP CLI 설정 확인 중..."
if ! command -v gcloud &> /dev/null; then
    log_error "Google Cloud CLI가 설치되지 않았습니다. 먼저 gcloud CLI를 설치해주세요."
    exit 1
fi

# GCP 인증 확인 (간단한 방법)
if ! gcloud auth list > /dev/null 2>&1; then
    log_error "GCP 인증이 설정되지 않았습니다. 'gcloud auth login'을 실행해주세요."
    exit 1
fi

# 프로젝트 ID 확인 및 생성
if [ -z "$PROJECT_ID" ]; then
    PROJECT_ID=$(gcloud config get-value project 2>/dev/null)
    if [ -z "$PROJECT_ID" ]; then
        log_error "GCP 프로젝트가 설정되지 않았습니다."
        log_info "사용 가능한 프로젝트 목록:"
        gcloud projects list --format="table(projectId,name)" || true
        echo ""
        log_info "다음 명령어로 프로젝트를 설정하세요:"
        echo "gcloud config set project PROJECT_ID"
        echo "또는 스크립트 상단의 PROJECT_ID 변수를 직접 설정하세요."
        exit 1
    fi
fi

# 프로젝트 설정 확인 및 적용
log_info "프로젝트 설정 중..."
gcloud config set project $PROJECT_ID > /dev/null 2>&1
if [ $? -eq 0 ]; then
    log_success "프로젝트 설정 완료: $PROJECT_ID"
else
    log_error "프로젝트 설정 실패: $PROJECT_ID"
    exit 1
fi

# 프로젝트 존재 여부 확인 및 생성
if ! gcloud projects describe $PROJECT_ID &> /dev/null; then
    log_info "새 프로젝트 '$PROJECT_ID'를 생성합니다..."
    log_info "프로젝트 생성 중..."
    
    # 프로젝트 생성
    if gcloud projects create $PROJECT_ID --name="$PROJECT_NAME" &> /dev/null; then
        log_success "프로젝트 '$PROJECT_ID'가 생성되었습니다."
    else
        log_warning "프로젝트 생성에 실패했습니다. 기존 프로젝트를 사용합니다."
        log_info "사용 가능한 프로젝트 목록:"
        gcloud projects list --format="table(projectId,name)" || true
        
        # 기존 프로젝트가 있는지 확인
        EXISTING_PROJECT=$(gcloud projects list --format="value(projectId)" | head -1)
        if [ -n "$EXISTING_PROJECT" ]; then
            log_info "기존 프로젝트 '$EXISTING_PROJECT'를 사용합니다."
            PROJECT_ID="$EXISTING_PROJECT"
            gcloud config set project $PROJECT_ID
        else
            log_error "사용 가능한 프로젝트가 없습니다. GCP 콘솔에서 프로젝트를 생성하세요."
            exit 1
        fi
    fi
    
    # 프로젝트 활성화 대기
    log_info "프로젝트 활성화 대기 중..."
    sleep 10
    
    # 프로젝트 활성화 확인
    if ! gcloud projects describe $PROJECT_ID &> /dev/null; then
        log_error "프로젝트가 아직 활성화되지 않았습니다. 잠시 후 다시 시도하세요."
        exit 1
    fi
    
    # 필요한 API 활성화
    log_info "필요한 API 활성화 중..."
    gcloud services enable compute.googleapis.com --project=$PROJECT_ID
    gcloud services enable oslogin.googleapis.com --project=$PROJECT_ID
    log_success "API 활성화 완료"
fi

log_success "GCP CLI 설정 확인 완료"
log_success "프로젝트 ID: $PROJECT_ID"
checkpoint "project_setup_complete"

# 2. 프로젝트 설정 및 API 활성화 확인
log_info "프로젝트 설정 중..."
gcloud config set project $PROJECT_ID

# 필요한 API 활성화 확인
log_info "필요한 API 활성화 확인 중..."
if ! gcloud services list --enabled --filter="name:compute.googleapis.com" --format="value(name)" | grep -q "compute.googleapis.com"; then
    log_info "Compute Engine API 활성화 중..."
    gcloud services enable compute.googleapis.com --project=$PROJECT_ID
fi

if ! gcloud services list --enabled --filter="name:oslogin.googleapis.com" --format="value(name)" | grep -q "oslogin.googleapis.com"; then
    log_info "OS Login API 활성화 중..."
    gcloud services enable oslogin.googleapis.com --project=$PROJECT_ID
fi

log_success "API 활성화 확인 완료"
checkpoint "api_enabled"

# 2.5. SSH 키 생성 및 설정 (Prerequisite)
log_info "SSH 키 확인 중..."
KEY_FILE="${PROJECT_NAME}-key"
PRIVATE_KEY_FILE="${KEY_FILE}.pem"
PUBLIC_KEY_FILE="${KEY_FILE}.pub"

# GCP는 공개키만 사용하므로 .pub 파일 우선 확인
if [ -f "$PUBLIC_KEY_FILE" ]; then
    # 공개키 파일이 있는 경우
    log_success "기존 SSH 공개키 파일 발견: $PUBLIC_KEY_FILE"
    log_info "기존 공개키 파일을 사용합니다."
    
    # 공개키 파일 권한 확인 및 수정
    chmod 644 "$PUBLIC_KEY_FILE" 2>/dev/null || true
    
    # 공개키 파일 유효성 검사
    if ssh-keygen -l -f "$PUBLIC_KEY_FILE" > /dev/null 2>&1; then
        log_success "기존 SSH 공개키 파일이 유효합니다"
        
        # 개인키 파일도 확인 (SSH 연결용)
        if [ -f "$KEY_FILE" ]; then
            log_success "개인키 파일도 발견: $KEY_FILE"
            chmod 400 "$KEY_FILE" 2>/dev/null || true
        elif [ -f "$PRIVATE_KEY_FILE" ]; then
            log_success "개인키 파일 발견 (.pem 형식): $PRIVATE_KEY_FILE"
            # .pem 파일을 확장자 없는 파일로 복사 (다른 파일인 경우에만)
            if [ "$PRIVATE_KEY_FILE" != "$KEY_FILE" ]; then
                cp "$PRIVATE_KEY_FILE" "$KEY_FILE"
            fi
            chmod 400 "$KEY_FILE" 2>/dev/null || true
        else
            log_warning "개인키 파일이 없습니다. 새로 생성합니다."
            ssh-keygen -t rsa -b 4096 -f "$KEY_FILE" -N "" -C "${PROJECT_NAME}-key"
            chmod 400 "$KEY_FILE"
            # 공개키도 새로 생성 (다른 파일인 경우에만)
            if [ "${KEY_FILE}.pub" != "$PUBLIC_KEY_FILE" ]; then
                cp "${KEY_FILE}.pub" "$PUBLIC_KEY_FILE"
            fi
            chmod 644 "$PUBLIC_KEY_FILE"
        fi
    else
        log_warning "기존 SSH 공개키 파일이 손상되었습니다. 새로 생성합니다."
        rm -f "$KEY_FILE" "${KEY_FILE}.pub" "$PRIVATE_KEY_FILE" "$PUBLIC_KEY_FILE"
        log_info "SSH 키 생성 중..."
        ssh-keygen -t rsa -b 4096 -f "$KEY_FILE" -N "" -C "${PROJECT_NAME}-key"
        chmod 400 "$KEY_FILE"
        chmod 644 "${KEY_FILE}.pub"
        # 공개키 복사 (다른 파일인 경우에만)
        if [ "${KEY_FILE}.pub" != "$PUBLIC_KEY_FILE" ]; then
            cp "${KEY_FILE}.pub" "$PUBLIC_KEY_FILE"
        fi
        log_success "SSH 키 생성 완료: $KEY_FILE"
    fi
else
    log_info "SSH 키 파일이 없습니다. 새로 생성 중..."
    ssh-keygen -t rsa -b 4096 -f "$KEY_FILE" -N "" -C "${PROJECT_NAME}-key"
    chmod 400 "$KEY_FILE"
    chmod 644 "${KEY_FILE}.pub"
    # 공개키 복사 (다른 파일인 경우에만)
    if [ "${KEY_FILE}.pub" != "$PUBLIC_KEY_FILE" ]; then
        cp "${KEY_FILE}.pub" "$PUBLIC_KEY_FILE"
    fi
    log_success "SSH 키 생성 완료: $KEY_FILE"
fi

# GCP에 SSH 키 추가 (OS Login 방식)
log_info "GCP OS Login에 SSH 키 추가 중..."
if gcloud compute os-login ssh-keys add --key-file "$PUBLIC_KEY_FILE" --project $PROJECT_ID > /dev/null 2>&1; then
    log_success "SSH 키가 GCP OS Login에 추가되었습니다"
else
    log_warning "SSH 키 추가에 실패했거나 이미 존재합니다"
fi

# 프로젝트 메타데이터에 SSH 키 추가 (프로젝트 전체 VM에서 사용 가능)
log_info "프로젝트 메타데이터에 SSH 키 추가 중..."
SSH_KEY_CONTENT=$(cat "$PUBLIC_KEY_FILE")
if gcloud compute project-info add-metadata --metadata "ssh-keys=$USER:$SSH_KEY_CONTENT" > /dev/null 2>&1; then
    log_success "SSH 키가 프로젝트 메타데이터에 추가되었습니다"
else
    log_warning "프로젝트 메타데이터에 SSH 키 추가에 실패했습니다"
fi
checkpoint "ssh_keys_ready"

log_success "SSH 키 설정 완료 (Prerequisite)"
log_info "SSH 키 파일:"
echo "  - 개인키: $KEY_FILE"
echo "  - 공개키: $PUBLIC_KEY_FILE"
echo "  - 사용자: $USER"
echo ""

# 3. 리전 유효성 검사
log_info "리전 유효성 검사 중..."
if ! gcloud compute regions describe $REGION &> /dev/null; then
    log_error "리전 '$REGION'이 유효하지 않습니다."
    log_info "사용 가능한 리전 목록:"
    gcloud compute regions list --format="table(name,status)" || true
    echo ""
    log_info "스크립트 상단의 REGION 변수를 유효한 리전으로 변경하세요."
    exit 1
fi

# 존 유효성 검사
log_info "존 유효성 검사 중..."
if ! gcloud compute zones describe $ZONE &> /dev/null; then
    log_error "존 '$ZONE'이 유효하지 않습니다."
    log_info "사용 가능한 존 목록:"
    gcloud compute zones list --filter="region:$REGION" --format="table(name,status)" || true
    echo ""
    log_info "스크립트 상단의 ZONE 변수를 유효한 존으로 변경하세요."
    exit 1
fi

gcloud config set compute/region $REGION
gcloud config set compute/zone $ZONE

# 3. VPC 네트워크 생성 또는 확인
log_info "VPC 네트워크 확인 중..."
if ! gcloud compute networks describe $NETWORK_NAME &> /dev/null; then
    log_info "VPC 네트워크 생성 중..."
    gcloud compute networks create $NETWORK_NAME --subnet-mode custom
    log_success "VPC 네트워크 생성 완료: $NETWORK_NAME"
else
    log_success "기존 VPC 네트워크 사용: $NETWORK_NAME"
fi
checkpoint "vpc_ready"

# 4. 서브넷 생성 또는 확인
log_info "서브넷 확인 중..."
if ! gcloud compute networks subnets describe $SUBNET_NAME --region=$REGION &> /dev/null; then
    log_info "서브넷 생성 중..."
    gcloud compute networks subnets create $SUBNET_NAME \
        --network $NETWORK_NAME \
        --range 10.0.0.0/24 \
        --region $REGION
    log_success "서브넷 생성 완료: $SUBNET_NAME"
else
    log_success "기존 서브넷 사용: $SUBNET_NAME"
fi
checkpoint "subnet_ready"

# 5. 방화벽 규칙 생성 또는 확인
log_info "방화벽 규칙 확인 중..."

# SSH 규칙
if ! gcloud compute firewall-rules describe $FIREWALL_RULE_SSH &> /dev/null; then
    log_info "SSH 방화벽 규칙 생성 중..."
    gcloud compute firewall-rules create $FIREWALL_RULE_SSH \
        --network $NETWORK_NAME \
        --allow tcp:22 \
        --source-ranges 0.0.0.0/0 \
        --description "Allow SSH access"
    log_success "SSH 방화벽 규칙 생성 완료"
else
    log_success "SSH 방화벽 규칙이 이미 존재합니다"
fi

# HTTP 규칙
if ! gcloud compute firewall-rules describe $FIREWALL_RULE_HTTP &> /dev/null; then
    log_info "HTTP 방화벽 규칙 생성 중..."
    gcloud compute firewall-rules create $FIREWALL_RULE_HTTP \
        --network $NETWORK_NAME \
        --allow tcp:80 \
        --source-ranges 0.0.0.0/0 \
        --description "Allow HTTP access"
    log_success "HTTP 방화벽 규칙 생성 완료"
else
    log_success "HTTP 방화벽 규칙이 이미 존재합니다"
fi

# HTTPS 규칙
if ! gcloud compute firewall-rules describe $FIREWALL_RULE_HTTPS &> /dev/null; then
    log_info "HTTPS 방화벽 규칙 생성 중..."
    gcloud compute firewall-rules create $FIREWALL_RULE_HTTPS \
        --network $NETWORK_NAME \
        --allow tcp:443 \
        --source-ranges 0.0.0.0/0 \
        --description "Allow HTTPS access"
    log_success "HTTPS 방화벽 규칙 생성 완료"
else
    log_success "HTTPS 방화벽 규칙이 이미 존재합니다"
fi

# 애플리케이션 포트 규칙
if ! gcloud compute firewall-rules describe $FIREWALL_RULE_APP &> /dev/null; then
    log_info "애플리케이션 포트 방화벽 규칙 생성 중..."
    gcloud compute firewall-rules create $FIREWALL_RULE_APP \
        --network $NETWORK_NAME \
        --allow tcp:3000,tcp:7000 \
        --source-ranges 0.0.0.0/0 \
        --description "Allow application ports"
    log_success "애플리케이션 포트 방화벽 규칙 생성 완료"
else
    log_success "애플리케이션 포트 방화벽 규칙이 이미 존재합니다"
fi
checkpoint "firewall_ready"

# 6. startup-script 확인
STARTUP_SCRIPT_FILE="startup-script.sh"
if [ ! -f "$STARTUP_SCRIPT_FILE" ]; then
    log_warning "startup-script.sh 파일이 없습니다. 기본 설정으로 진행합니다."
    STARTUP_SCRIPT_FILE=""
fi

# 7. Compute Engine 인스턴스 생성 또는 확인
log_info "Compute Engine 인스턴스 확인 중..."
if ! gcloud compute instances describe $INSTANCE_NAME --zone=$ZONE &> /dev/null; then
    log_info "Compute Engine 인스턴스 생성 중..."
    
    # SSH 키를 인스턴스 메타데이터로 전달 (VM 생성 시 직접 설정)
    # SSH 키는 이미 prerequisite 단계에서 준비됨
    SSH_KEY_CONTENT=$(cat "$PUBLIC_KEY_FILE")
    
    INSTANCE_CMD="gcloud compute instances create $INSTANCE_NAME \
        --zone=$ZONE \
        --machine-type=$MACHINE_TYPE \
        --network-interface=network-tier=PREMIUM,subnet=$SUBNET_NAME \
        --maintenance-policy=MIGRATE \
        --provisioning-model=STANDARD \
        --scopes=https://www.googleapis.com/auth/cloud-platform \
        --create-disk=auto-delete=yes,boot=yes,device-name=$INSTANCE_NAME,image-family=$IMAGE_FAMILY,image-project=$IMAGE_PROJECT,mode=rw,size=20,type=projects/$PROJECT_ID/zones/$ZONE/diskTypes/pd-standard \
        --tags=$PROJECT_NAME \
        --metadata ssh-keys=\"$USER:$SSH_KEY_CONTENT\""

    if [ -n "$STARTUP_SCRIPT_FILE" ]; then
        INSTANCE_CMD="$INSTANCE_CMD --metadata-from-file startup-script=$STARTUP_SCRIPT_FILE"
    fi

    eval $INSTANCE_CMD
    log_success "Compute Engine 인스턴스 생성 완료: $INSTANCE_NAME"
    checkpoint "instance_created"
else
    log_success "기존 Compute Engine 인스턴스 사용: $INSTANCE_NAME"
    
    # 기존 인스턴스에 SSH 키 추가 (인스턴스 메타데이터)
    # SSH 키는 이미 prerequisite 단계에서 프로젝트 메타데이터에 등록됨
    log_info "기존 인스턴스에 SSH 키 추가 중..."
    SSH_KEY_CONTENT=$(cat "$PUBLIC_KEY_FILE")
    if gcloud compute instances add-metadata $INSTANCE_NAME --zone=$ZONE --metadata "ssh-keys=$USER:$SSH_KEY_CONTENT" > /dev/null 2>&1; then
        log_success "기존 인스턴스에 SSH 키가 추가되었습니다"
    else
        log_warning "기존 인스턴스에 SSH 키 추가에 실패했습니다 (프로젝트 메타데이터에서 자동으로 사용 가능)"
    fi
    
    # 인스턴스 상태 확인 및 복구
    INSTANCE_STATUS=$(gcloud compute instances describe $INSTANCE_NAME --zone=$ZONE --format="get(status)")
    log_info "인스턴스 상태: $INSTANCE_STATUS"
    
    # 인스턴스 상태에 따른 처리
    case "$INSTANCE_STATUS" in
        "TERMINATED")
            log_info "중지된 인스턴스를 시작 중..."
            gcloud compute instances start $INSTANCE_NAME --zone=$ZONE
            log_success "인스턴스 시작 완료"
            ;;
        "STOPPING")
            log_info "인스턴스가 중지 중입니다. 완료될 때까지 대기..."
            gcloud compute instances wait $INSTANCE_NAME --zone=$ZONE --for=STOPPED
            log_info "인스턴스 시작 중..."
            gcloud compute instances start $INSTANCE_NAME --zone=$ZONE
            log_success "인스턴스 시작 완료"
            ;;
        "SUSPENDED")
            log_info "일시정지된 인스턴스를 재개 중..."
            gcloud compute instances start $INSTANCE_NAME --zone=$ZONE
            log_success "인스턴스 재개 완료"
            ;;
        "RUNNING")
            log_success "인스턴스가 이미 실행 중입니다"
            ;;
        *)
            log_warning "알 수 없는 인스턴스 상태: $INSTANCE_STATUS"
            log_info "인스턴스를 시작 시도합니다..."
            gcloud compute instances start $INSTANCE_NAME --zone=$ZONE || true
            ;;
    esac
    checkpoint "instance_ready"
fi

# 9. 인스턴스 정보 조회
log_info "인스턴스 정보 조회 중..."
EXTERNAL_IP=$(gcloud compute instances describe $INSTANCE_NAME --zone=$ZONE --format="get(networkInterfaces[0].accessConfigs[0].natIP)")
INTERNAL_IP=$(gcloud compute instances describe $INSTANCE_NAME --zone=$ZONE --format="get(networkInterfaces[0].networkIP)")

# 10. 결과 출력
echo ""
log_success "=== Compute Engine 인스턴스 생성 완료 ==="
echo "인스턴스 이름: $INSTANCE_NAME"
echo "외부 IP: $EXTERNAL_IP"
echo "내부 IP: $INTERNAL_IP"
echo "네트워크: $NETWORK_NAME"
echo "서브넷: $SUBNET_NAME"
echo ""

# 11. 연결 명령어 출력
if [ -n "$EXTERNAL_IP" ]; then
    log_info "SSH 연결 명령어:"
    echo "1. gcloud 명령어 (권장 - OS Login 사용):"
    echo "   gcloud compute ssh $USER@$INSTANCE_NAME --zone=$ZONE"
    echo ""
    echo "2. 일반 SSH 명령어 (메타데이터 SSH 키 사용):"
    echo "   ssh -i $KEY_FILE $USER@$EXTERNAL_IP"
    echo ""
    echo "3. SSH 키 파일 확인:"
    echo "   개인키: $KEY_FILE"
    echo "   공개키: $PUBLIC_KEY_FILE"
    echo ""
    log_info "사용자 계정 정보:"
    echo "   사용자명: $USER"
    echo "   계정 타입: $(if [[ "$USER" == *"@"* ]]; then echo "GCP OS Login (Google 계정)"; else echo "Ubuntu 기본 사용자"; fi)"
    echo ""
    log_info "SSH 키가 인스턴스 메타데이터에 등록되었습니다."
    echo "   - OS Login 방식: Google 계정으로 자동 인증"
    echo "   - 인스턴스 메타데이터 방식: 개인키 파일로 직접 인증"
    echo ""
fi

# 12. 정적 IP 할당 옵션
read -p "정적 IP를 할당하시겠습니까? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    STATIC_IP_NAME="${PROJECT_NAME}-ip"
    
    # 기존 정적 IP 확인
    if gcloud compute addresses describe $STATIC_IP_NAME --region=$REGION &> /dev/null; then
        STATIC_IP=$(gcloud compute addresses describe $STATIC_IP_NAME --region=$REGION --format="get(address)")
        log_success "기존 정적 IP 사용: $STATIC_IP"
        
        # 인스턴스에 이미 할당되어 있는지 확인
        EXISTING_STATIC_IP=$(gcloud compute instances describe $INSTANCE_NAME --zone=$ZONE --format="get(networkInterfaces[0].accessConfigs[0].natIP)")
        if [ "$EXISTING_STATIC_IP" != "$STATIC_IP" ]; then
            # 기존 외부 IP 제거 후 정적 IP 할당
            log_info "기존 외부 IP 제거 중..."
            gcloud compute instances delete-access-config $INSTANCE_NAME \
                --zone=$ZONE \
                --access-config-name="External NAT" > /dev/null 2>&1 || true
            
            log_info "인스턴스에 정적 IP 할당 중..."
            gcloud compute instances add-access-config $INSTANCE_NAME \
                --zone=$ZONE \
                --address=$STATIC_IP > /dev/null
            log_success "정적 IP 할당 완료"
        else
            log_success "정적 IP가 이미 할당되어 있습니다"
        fi
    else
        log_info "정적 IP 할당 중..."
        gcloud compute addresses create $STATIC_IP_NAME --region=$REGION
        STATIC_IP=$(gcloud compute addresses describe $STATIC_IP_NAME --region=$REGION --format="get(address)")
        
        # 기존 외부 IP 제거 후 정적 IP 할당
        log_info "기존 외부 IP 제거 중..."
        gcloud compute instances delete-access-config $INSTANCE_NAME \
            --zone=$ZONE \
            --access-config-name="External NAT" > /dev/null 2>&1 || true
        
        log_info "정적 IP 할당 중..."
        gcloud compute instances add-access-config $INSTANCE_NAME \
            --zone=$ZONE \
            --address=$STATIC_IP > /dev/null
        
        log_success "정적 IP 할당 완료: $STATIC_IP"
    fi
    
    echo "정적 IP: $STATIC_IP"
    echo ""
    log_info "SSH 연결 명령어:"
    echo "1. gcloud 명령어 (권장 - OS Login 사용):"
    echo "   gcloud compute ssh $USER@$INSTANCE_NAME --zone=$ZONE"
    echo ""
    echo "2. 일반 SSH 명령어 (메타데이터 SSH 키 사용):"
    echo "   ssh -i $KEY_FILE $USER@$STATIC_IP"
    echo ""
    echo "3. SSH 키 파일 확인:"
    echo "   개인키: $KEY_FILE"
    echo "   공개키: $PUBLIC_KEY_FILE"
    echo ""
    log_info "사용자 계정 정보:"
    echo "   사용자명: $USER"
    echo "   계정 타입: $(if [[ "$USER" == *"@"* ]]; then echo "GCP OS Login (Google 계정)"; else echo "Ubuntu 기본 사용자"; fi)"
    echo ""
    log_info "SSH 키가 인스턴스 메타데이터에 등록되었습니다."
    echo "   - OS Login 방식: Google 계정으로 자동 인증"
    echo "   - 인스턴스 메타데이터 방식: 개인키 파일로 직접 인증"
fi

log_success "=== 스크립트 실행 완료 ==="
clear_checkpoint
echo ""
log_info "📋 현재 프로젝트 설정:"
echo "프로젝트 ID: $PROJECT_ID"
echo "리전: $REGION"
echo "존: $ZONE"
echo ""
log_info "🔧 터미널에서 프로젝트 설정 (다른 터미널에서 사용):"
echo "gcloud config set project $PROJECT_ID"
echo "gcloud config set compute/region $REGION"
echo "gcloud config set compute/zone $ZONE"
echo ""
log_info "📝 다음 단계:"
echo "1. SSH로 인스턴스에 연결"
echo "2. 애플리케이션 배포"
echo "3. 도메인 설정 (필요한 경우)"
echo ""
log_warning "💰 비용 절약을 위해 사용하지 않을 때는 인스턴스를 중지하세요:"
echo "gcloud compute instances stop $INSTANCE_NAME --zone=$ZONE"
echo ""
log_warning "🗑️ 인스턴스 삭제 시:"
echo "gcloud compute instances delete $INSTANCE_NAME --zone=$ZONE --quiet"
