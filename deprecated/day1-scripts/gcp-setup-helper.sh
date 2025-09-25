#!/bin/bash

# GCP 설정 도우미 스크립트
# GCP 프로젝트, 리전, 존 설정을 도와주는 스크립트

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

echo "=== GCP 설정 도우미 ==="
echo ""

# 1. 인증 확인
log_info "GCP 인증 상태 확인 중..."
if ! gcloud auth list > /dev/null 2>&1; then
    log_error "GCP 인증이 설정되지 않았습니다."
    log_info "다음 명령어로 인증하세요:"
    echo "gcloud auth login"
    exit 1
fi

CURRENT_ACCOUNT=$(gcloud auth list --filter=status:ACTIVE --format="value(account)")
log_success "인증된 계정: $CURRENT_ACCOUNT"
echo ""

# 2. 프로젝트 목록 표시
log_info "사용 가능한 프로젝트 목록:"
echo ""
gcloud projects list --format="table(projectId,name,projectNumber)" || {
    log_error "프로젝트 목록을 가져올 수 없습니다."
    exit 1
}
echo ""

# 3. 현재 프로젝트 확인
CURRENT_PROJECT=$(gcloud config get-value project 2>/dev/null || echo "")
if [ -n "$CURRENT_PROJECT" ]; then
    log_info "현재 설정된 프로젝트: $CURRENT_PROJECT"
else
    log_warning "현재 프로젝트가 설정되지 않았습니다."
fi
echo ""

# 4. 프로젝트 선택 또는 생성
echo ""
log_info "프로젝트 옵션을 선택하세요:"
echo "1) 기존 프로젝트 사용"
echo "2) 새 프로젝트 생성"
echo "3) 현재 프로젝트 유지"
echo ""
read -p "선택하세요 (1/2/3) [기본값: 3]: " PROJECT_OPTION
PROJECT_OPTION=${PROJECT_OPTION:-3}

case $PROJECT_OPTION in
    1)
        # 기존 프로젝트 사용
        read -p "사용할 프로젝트 ID를 입력하세요: " SELECTED_PROJECT
        if [ -z "$SELECTED_PROJECT" ]; then
            log_error "프로젝트 ID를 입력해야 합니다."
            exit 1
        fi
        
    # 프로젝트 유효성 검사
        if ! gcloud projects describe "$SELECTED_PROJECT" &> /dev/null; then
        log_error "프로젝트 '$SELECTED_PROJECT'에 접근할 수 없습니다."
        exit 1
    fi
    
    # 프로젝트 설정
        gcloud config set project "$SELECTED_PROJECT"
    log_success "프로젝트가 '$SELECTED_PROJECT'로 설정되었습니다."
    CURRENT_PROJECT=$SELECTED_PROJECT
        ;;
    2)
        # 새 프로젝트 생성
        read -p "새 프로젝트 이름을 입력하세요: " NEW_PROJECT_NAME
        if [ -z "$NEW_PROJECT_NAME" ]; then
            log_error "프로젝트 이름을 입력해야 합니다."
            exit 1
        fi
        
        # 프로젝트 ID 생성 (이름 + 타임스탬프)
        NEW_PROJECT_ID="${NEW_PROJECT_NAME}-$(date +%s)"
        log_info "프로젝트 ID: $NEW_PROJECT_ID"
        
        # 프로젝트 생성
        log_info "프로젝트 생성 중..."
        if gcloud projects create "$NEW_PROJECT_ID" --name="$NEW_PROJECT_NAME"; then
            log_success "프로젝트가 생성되었습니다: $NEW_PROJECT_ID"
            
            # 프로젝트 설정
            gcloud config set project "$NEW_PROJECT_ID"
            log_success "프로젝트가 '$NEW_PROJECT_ID'로 설정되었습니다."
            CURRENT_PROJECT=$NEW_PROJECT_ID
            
            # 빌링 계정 연결 확인
            log_info "빌링 계정 연결을 확인합니다..."
            BILLING_ACCOUNTS=$(gcloud billing accounts list --format="get(name)" 2>/dev/null | head -1)
            if [ -n "$BILLING_ACCOUNTS" ]; then
                log_info "빌링 계정에 연결합니다: $BILLING_ACCOUNTS"
                gcloud billing projects link "$NEW_PROJECT_ID" --billing-account="$BILLING_ACCOUNTS" 2>/dev/null || {
                    log_warning "빌링 계정 연결에 실패했습니다. 수동으로 연결해주세요."
                    log_info "GCP 콘솔에서 빌링 계정을 연결해주세요: https://console.cloud.google.com/billing"
                }
            else
                log_warning "빌링 계정이 없습니다. 수동으로 설정해주세요."
                log_info "GCP 콘솔에서 빌링 계정을 설정해주세요: https://console.cloud.google.com/billing"
            fi
            
            # 필요한 API 활성화
            log_info "필요한 API를 활성화합니다..."
            gcloud services enable compute.googleapis.com
            gcloud services enable oslogin.googleapis.com
            log_success "API 활성화 완료"
        else
            log_error "프로젝트 생성에 실패했습니다."
            exit 1
        fi
        ;;
    3)
        # 현재 프로젝트 유지
    if [ -z "$CURRENT_PROJECT" ]; then
            log_error "현재 프로젝트가 설정되지 않았습니다. 프로젝트를 선택하거나 생성해주세요."
        exit 1
    fi
    log_info "현재 프로젝트 '$CURRENT_PROJECT'를 사용합니다."
        ;;
    *)
        log_error "잘못된 선택입니다."
        exit 1
        ;;
esac
echo ""

# 5. 리전 목록 표시
log_info "사용 가능한 리전 목록:"
echo ""
gcloud compute regions list --filter="name~asia-northeast" --format="table(name,status,description)" || {
    log_error "리전 목록을 가져올 수 없습니다."
    exit 1
}
echo ""

# 6. 리전 선택
read -p "사용할 리전을 입력하세요 (예: asia-northeast1, asia-northeast3) [기본값: asia-northeast3]: " SELECTED_REGION
SELECTED_REGION=${SELECTED_REGION:-asia-northeast3}

# 리전 유효성 검사
if ! gcloud compute regions describe "$SELECTED_REGION" &> /dev/null; then
    log_error "리전 '$SELECTED_REGION'이 유효하지 않습니다."
    exit 1
fi

gcloud config set compute/region "$SELECTED_REGION"
log_success "리전이 '$SELECTED_REGION'로 설정되었습니다."
echo ""

# 7. 존 목록 표시
log_info "사용 가능한 존 목록 ($SELECTED_REGION):"
echo ""
gcloud compute zones list --filter="region:$SELECTED_REGION" --format="table(name,status)" || {
    log_error "존 목록을 가져올 수 없습니다."
    exit 1
}
echo ""

# 8. 존 선택
read -p "사용할 존을 입력하세요 (예: asia-northeast3-a) [기본값: ${SELECTED_REGION}-a]: " SELECTED_ZONE
SELECTED_ZONE=${SELECTED_ZONE:-${SELECTED_REGION}-a}

# 존 유효성 검사
if ! gcloud compute zones describe "$SELECTED_ZONE" &> /dev/null; then
    log_error "존 '$SELECTED_ZONE'이 유효하지 않습니다."
    exit 1
fi

gcloud config set compute/zone "$SELECTED_ZONE"
log_success "존이 '$SELECTED_ZONE'로 설정되었습니다."
echo ""

# 9. 설정 확인
log_success "=== GCP 설정 완료 ==="
echo "계정: $CURRENT_ACCOUNT"
echo "프로젝트: $CURRENT_PROJECT"
echo "리전: $SELECTED_REGION"
echo "존: $SELECTED_ZONE"
echo ""

# 10. 스크립트 실행 안내
log_info "이제 다음 명령어로 가상머신을 생성할 수 있습니다:"
echo "./gcp-compute-create.sh"
echo ""

# 11. SSH 키 확인 및 생성
log_info "=== SSH 키 설정 확인 ==="

# SSH 키 파일 확인 (사용자 정의 가능)
PROJECT_NAME="cloud-deployment"
KEY_FILE="${PROJECT_NAME}-key"
PUBLIC_KEY_FILE="${KEY_FILE}.pub"

# SSH 사용자 이름 입력
echo ""
log_info "SSH 키에 사용할 사용자 이름을 입력하세요."
log_info "GCP 인스턴스에 SSH 접속할 때 사용할 사용자 이름입니다."
echo ""
# 이메일에서 @ 앞부분만 추출하여 기본 사용자 이름으로 사용
DEFAULT_USERNAME=$(echo "$CURRENT_ACCOUNT" | cut -d'@' -f1)
read -p "SSH 사용자 이름을 입력하세요 [기본값: $DEFAULT_USERNAME]: " SSH_USERNAME
SSH_USERNAME=${SSH_USERNAME:-$DEFAULT_USERNAME}
log_success "SSH 사용자 이름: $SSH_USERNAME"
echo ""

# GCP에서 기존 SSH 키 확인
log_info "GCP 프로젝트에 등록된 SSH 키 확인 중..."
EXISTING_SSH_KEYS=$(gcloud compute project-info describe --format="get(commonInstanceMetadata.items[].value)" 2>/dev/null | grep "ssh-rsa" || echo "")

if [ -n "$EXISTING_SSH_KEYS" ]; then
    log_success "GCP 프로젝트에 이미 SSH 키가 등록되어 있습니다."
    echo ""
    log_info "등록된 SSH 키 정보:"
    echo "$EXISTING_SSH_KEYS" | while IFS= read -r line; do
        if [[ $line == *"ssh-rsa"* ]]; then
            if [[ $line == *":"* ]]; then
                # 사용자 이름이 있는 경우
                username=$(echo "$line" | cut -d: -f1)
                fingerprint=$(echo "$line" | grep -o 'SHA256:[a-zA-Z0-9+/=]*' || echo "알 수 없음")
                echo "  사용자명: $username"
                echo "  지문: $fingerprint"
            else
                # 사용자 이름이 없는 경우
                fingerprint=$(echo "$line" | grep -o 'SHA256:[a-zA-Z0-9+/=]*' || echo "알 수 없음")
                echo "  사용자명: 없음 (수정 필요)"
                echo "  지문: $fingerprint"
            fi
            echo ""
        fi
    done
    
    read -p "기존 SSH 키를 사용하시겠습니까? (y/n) [기본값: y]: " USE_EXISTING_GCP_KEY
    USE_EXISTING_GCP_KEY=${USE_EXISTING_GCP_KEY:-y}
    
    if [[ $USE_EXISTING_GCP_KEY =~ ^[Yy]$ ]]; then
        # 기존 SSH 키에 사용자 이름이 있는지 확인
        if echo "$EXISTING_SSH_KEYS" | grep -q ":"; then
            log_success "기존 SSH 키를 사용합니다."
            log_info "GCP 프로젝트에 이미 등록된 SSH 키가 있으므로 추가 설정이 필요하지 않습니다."
        else
            log_warning "기존 SSH 키에 사용자 이름이 없습니다."
            read -p "사용자 이름을 추가하여 수정하시겠습니까? (y/n) [기본값: y]: " FIX_USERNAME
            FIX_USERNAME=${FIX_USERNAME:-y}
            
            if [[ $FIX_USERNAME =~ ^[Yy]$ ]]; then
                log_info "SSH 키에 사용자 이름 추가 중..."
                # 기존 키 제거
                gcloud compute project-info remove-metadata --keys=ssh-keys 2>/dev/null || true
                # 사용자 이름과 함께 다시 등록
                echo "${SSH_USERNAME}:${EXISTING_SSH_KEYS}" > temp_ssh_key.txt
                gcloud compute project-info add-metadata --metadata-from-file ssh-keys=temp_ssh_key.txt
                rm -f temp_ssh_key.txt
                log_success "SSH 키가 사용자 이름과 함께 수정되었습니다. (사용자명: $SSH_USERNAME)"
            else
                log_warning "사용자 이름 수정을 건너뛰었습니다. SSH 접속 시 문제가 발생할 수 있습니다."
            fi
        fi
        echo ""
        # 기존 키 사용 시 로컬 키 파일 확인 건너뛰기
        SKIP_LOCAL_KEY_CHECK=true
    else
        log_info "새로운 SSH 키를 생성하고 등록합니다."
        # 기존 키 제거 후 새 키 등록
        log_info "기존 SSH 키를 제거합니다..."
        gcloud compute project-info remove-metadata --keys=ssh-keys 2>/dev/null || true
        log_info "기존 OS Login SSH 키를 제거합니다..."
        gcloud compute os-login ssh-keys list --format="get(fingerprint)" | while read fingerprint; do
            gcloud compute os-login ssh-keys remove --key="$fingerprint" 2>/dev/null || true
        done
        SKIP_LOCAL_KEY_CHECK=false
    fi
else
    log_warning "GCP 프로젝트에 등록된 SSH 키가 없습니다."
    log_info "새로운 SSH 키를 생성하고 등록합니다."
    SKIP_LOCAL_KEY_CHECK=false
fi

# 로컬 키 파일 확인 (기존 GCP 키 사용 시 건너뛰기)
if [ "$SKIP_LOCAL_KEY_CHECK" != "true" ] && [ -f "$PUBLIC_KEY_FILE" ]; then
    log_success "로컬 SSH 키 파일이 존재합니다: $PUBLIC_KEY_FILE"
    
    # 기존 SSH 키 정보 표시
    log_info "기존 SSH 키 정보:"
    echo "파일: $PUBLIC_KEY_FILE"
    echo "사용자명: $(ssh-keygen -lf $PUBLIC_KEY_FILE | awk '{print $3}')"
    echo "지문: $(ssh-keygen -lf $PUBLIC_KEY_FILE | awk '{print $2}')"
    echo ""
    
    # 기존 키 사용 여부 확인
    read -p "기존 SSH 키를 사용하시겠습니까? (y/n) [기본값: y]: " USE_EXISTING_KEY
    USE_EXISTING_KEY=${USE_EXISTING_KEY:-y}
    
    if [[ $USE_EXISTING_KEY =~ ^[Yy]$ ]]; then
        log_info "기존 SSH 키를 사용합니다."
        
        # 프로젝트 메타데이터에 SSH 키가 등록되어 있는지 확인
        log_info "프로젝트 메타데이터에 SSH 키 등록 상태 확인 중..."
        if gcloud compute project-info describe --format="get(commonInstanceMetadata.items[].key)" | grep -q "ssh-keys"; then
            log_success "프로젝트 메타데이터에 SSH 키가 이미 등록되어 있습니다."
        else
            log_warning "프로젝트 메타데이터에 SSH 키가 등록되지 않았습니다."
            read -p "프로젝트 메타데이터에 SSH 키를 등록하시겠습니까? (y/n) [기본값: y]: " REGISTER_SSH
            REGISTER_SSH=${REGISTER_SSH:-y}
            
            if [[ $REGISTER_SSH =~ ^[Yy]$ ]]; then
                log_info "프로젝트 메타데이터에 SSH 키 등록 중..."
                # SSH 키에 사용자 이름 추가
                echo "${SSH_USERNAME}:$(cat "$PUBLIC_KEY_FILE")" > "${PUBLIC_KEY_FILE}.with_username"
                gcloud compute project-info add-metadata --metadata-from-file ssh-keys="${PUBLIC_KEY_FILE}.with_username"
                log_success "SSH 키가 프로젝트 메타데이터에 등록되었습니다. (사용자명: $SSH_USERNAME)"
            fi
        fi
        
        # OS Login에 SSH 키가 등록되어 있는지 확인
        log_info "OS Login SSH 키 등록 상태 확인 중..."
        if gcloud compute os-login ssh-keys list --format="get(fingerprint)" | grep -q "$(ssh-keygen -lf $PUBLIC_KEY_FILE | awk '{print $2}')" 2>/dev/null; then
            log_success "OS Login에 SSH 키가 이미 등록되어 있습니다."
        else
            log_warning "OS Login에 SSH 키가 등록되지 않았습니다."
            read -p "OS Login에 SSH 키를 등록하시겠습니까? (y/n) [기본값: y]: " REGISTER_OS_LOGIN
            REGISTER_OS_LOGIN=${REGISTER_OS_LOGIN:-y}
            
            if [[ $REGISTER_OS_LOGIN =~ ^[Yy]$ ]]; then
                log_info "OS Login에 SSH 키 등록 중..."
                gcloud compute os-login ssh-keys add --key-file="$PUBLIC_KEY_FILE"
                log_success "SSH 키가 OS Login에 등록되었습니다."
            fi
        fi
    else
        log_info "새로운 SSH 키를 생성합니다."
        
        # 기존 키 백업
        if [ -f "$KEY_FILE" ]; then
            log_info "기존 키 파일을 백업합니다: ${KEY_FILE}.backup"
            cp "$KEY_FILE" "${KEY_FILE}.backup"
            cp "$PUBLIC_KEY_FILE" "${PUBLIC_KEY_FILE}.backup"
        fi
        
        # 새 SSH 키 생성
        log_info "새 SSH 키 생성 중..."
        ssh-keygen -t rsa -b 4096 -f "$KEY_FILE" -N "" -C "$CURRENT_ACCOUNT"
        log_success "새 SSH 키가 생성되었습니다: $KEY_FILE"
        
        # 생성된 키를 프로젝트 메타데이터에 등록 (사용자 이름 포함)
        log_info "프로젝트 메타데이터에 SSH 키 등록 중..."
        # SSH 키에 사용자 이름 추가
        echo "${SSH_USERNAME}:$(cat "$PUBLIC_KEY_FILE")" > "${PUBLIC_KEY_FILE}.with_username"
        gcloud compute project-info add-metadata --metadata-from-file ssh-keys="${PUBLIC_KEY_FILE}.with_username"
        log_success "SSH 키가 프로젝트 메타데이터에 등록되었습니다. (사용자명: $SSH_USERNAME)"
        
        # OS Login에 등록 (선택사항)
        echo ""
        log_info "OS Login은 고급 보안 기능입니다. 대부분의 경우 프로젝트 메타데이터만으로도 충분합니다."
        read -p "OS Login에도 SSH 키를 등록하시겠습니까? (y/n) [기본값: n]: " REGISTER_OS_LOGIN
        REGISTER_OS_LOGIN=${REGISTER_OS_LOGIN:-n}
        
        if [[ $REGISTER_OS_LOGIN =~ ^[Yy]$ ]]; then
            log_info "OS Login에 SSH 키 등록 중..."
            gcloud compute os-login ssh-keys add --key-file="$PUBLIC_KEY_FILE"
            log_success "SSH 키가 OS Login에 등록되었습니다."
        else
            log_info "OS Login 등록을 건너뛰었습니다. 프로젝트 메타데이터만으로 SSH 접속이 가능합니다."
        fi
    fi
elif [ "$SKIP_LOCAL_KEY_CHECK" != "true" ]; then
    log_warning "로컬 SSH 키 파일이 없습니다: $PUBLIC_KEY_FILE"
    read -p "SSH 키를 생성하시겠습니까? (y/n) [기본값: y]: " CREATE_SSH
    CREATE_SSH=${CREATE_SSH:-y}
    
    if [[ $CREATE_SSH =~ ^[Yy]$ ]]; then
        log_info "SSH 키 생성 중..."
        ssh-keygen -t rsa -b 4096 -f "$KEY_FILE" -N "" -C "$CURRENT_ACCOUNT"
        log_success "SSH 키가 생성되었습니다: $KEY_FILE"
        
        # 생성된 키를 프로젝트 메타데이터에 등록 (사용자 이름 포함)
        log_info "프로젝트 메타데이터에 SSH 키 등록 중..."
        # SSH 키에 사용자 이름 추가
        echo "${SSH_USERNAME}:$(cat "$PUBLIC_KEY_FILE")" > "${PUBLIC_KEY_FILE}.with_username"
        gcloud compute project-info add-metadata --metadata-from-file ssh-keys="${PUBLIC_KEY_FILE}.with_username"
        log_success "SSH 키가 프로젝트 메타데이터에 등록되었습니다. (사용자명: $SSH_USERNAME)"
        
        # OS Login에 등록 (선택사항)
        echo ""
        log_info "OS Login은 고급 보안 기능입니다. 대부분의 경우 프로젝트 메타데이터만으로도 충분합니다."
        read -p "OS Login에도 SSH 키를 등록하시겠습니까? (y/n) [기본값: n]: " REGISTER_OS_LOGIN
        REGISTER_OS_LOGIN=${REGISTER_OS_LOGIN:-n}
        
        if [[ $REGISTER_OS_LOGIN =~ ^[Yy]$ ]]; then
            log_info "OS Login에 SSH 키 등록 중..."
            gcloud compute os-login ssh-keys add --key-file="$PUBLIC_KEY_FILE"
            log_success "SSH 키가 OS Login에 등록되었습니다."
        else
            log_info "OS Login 등록을 건너뛰었습니다. 프로젝트 메타데이터만으로 SSH 접속이 가능합니다."
        fi
    else
        log_warning "SSH 키가 없으면 인스턴스에 연결할 수 없습니다."
        log_info "나중에 다음 명령어로 SSH 키를 생성하고 등록할 수 있습니다:"
        echo "ssh-keygen -t rsa -b 4096 -f $KEY_FILE"
        echo "gcloud compute project-info add-metadata --metadata-from-file ssh-keys=$PUBLIC_KEY_FILE"
        echo "gcloud compute os-login ssh-keys add --key-file=$PUBLIC_KEY_FILE"
    fi
fi
# 임시 파일 정리
if [ -f "${PUBLIC_KEY_FILE}.with_username" ]; then
    rm -f "${PUBLIC_KEY_FILE}.with_username"
fi

echo ""

# 12. 환경 파일 생성
ENV_FILE="gcp-environment.env"
log_info "환경 파일 생성 중: $ENV_FILE"

cat > "$ENV_FILE" << EOF
# GCP 환경 설정 파일
# 이 파일은 gcp-setup-helper.sh에 의해 자동 생성되었습니다.
# 생성 시간: $(date)

# GCP 계정 정보
GCP_ACCOUNT="$CURRENT_ACCOUNT"
GCP_PROJECT_ID="$CURRENT_PROJECT"

# GCP 리전 및 존 설정
REGION="$SELECTED_REGION"
ZONE="$SELECTED_ZONE"

# 환경 변수 내보내기
export GOOGLE_CLOUD_PROJECT="\$GCP_PROJECT_ID"
export GCP_PROJECT="\$GCP_PROJECT_ID"
export GCP_REGION="\$REGION"
export GCP_ZONE="\$ZONE"
EOF

log_success "환경 파일이 생성되었습니다: $ENV_FILE"

# 13. 스크립트 변수 업데이트 안내
log_info "이제 다음 방법으로 환경을 로드할 수 있습니다:"
echo "source $ENV_FILE"
echo ""
log_info "또는 스크립트 상단의 변수를 다음과 같이 설정하세요:"
echo "PROJECT_ID=\"$CURRENT_PROJECT\""
echo "REGION=\"$SELECTED_REGION\""
echo "ZONE=\"$SELECTED_ZONE\""
echo ""
