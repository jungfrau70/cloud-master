#!/bin/bash

# GCP 프로젝트 정리 스크립트
# 사용법: ./gcp-project-cleanup.sh [PROJECT_ID]

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

# 프로젝트 ID 확인
if [ -z "$1" ]; then
    log_error "프로젝트 ID를 입력해주세요."
    echo "사용법: $0 PROJECT_ID"
    echo ""
    log_info "사용 가능한 프로젝트 목록:"
    gcloud projects list --format="table(projectId,name,lifecycleState)" || true
    exit 1
fi

PROJECT_ID="$1"

log_info "=== GCP 프로젝트 정리 시작 ==="
log_info "대상 프로젝트: $PROJECT_ID"

# GCP 인증 확인
if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q .; then
    log_error "GCP 인증이 설정되지 않았습니다. 'gcloud auth login'을 실행해주세요."
    exit 1
fi

# 프로젝트 존재 여부 확인
if ! gcloud projects describe $PROJECT_ID &> /dev/null; then
    log_error "프로젝트 '$PROJECT_ID'를 찾을 수 없습니다."
    log_info "사용 가능한 프로젝트 목록:"
    gcloud projects list --format="table(projectId,name,lifecycleState)" || true
    exit 1
fi

# 프로젝트 정보 확인
log_info "프로젝트 정보 확인 중..."
PROJECT_INFO=$(gcloud projects describe $PROJECT_ID --format="value(projectId,name,lifecycleState)")
log_info "프로젝트 정보: $PROJECT_INFO"

# 프로젝트 내 리소스 확인
log_info "프로젝트 내 리소스 확인 중..."

# Compute Engine 인스턴스 확인
INSTANCES=$(gcloud compute instances list --project=$PROJECT_ID --format="value(name)" 2>/dev/null | wc -l)
if [ "$INSTANCES" -gt 0 ]; then
    log_warning "Compute Engine 인스턴스가 $INSTANCES개 있습니다."
    gcloud compute instances list --project=$PROJECT_ID --format="table(name,zone,status)" || true
fi

# Cloud Storage 버킷 확인
BUCKETS=$(gcloud storage buckets list --project=$PROJECT_ID --format="value(name)" 2>/dev/null | wc -l)
if [ "$BUCKETS" -gt 0 ]; then
    log_warning "Cloud Storage 버킷이 $BUCKETS개 있습니다."
    gcloud storage buckets list --project=$PROJECT_ID --format="table(name,location,storageClass)" || true
fi

# 삭제 확인
echo ""
log_warning "⚠️  주의: 이 작업은 되돌릴 수 없습니다!"
log_warning "프로젝트 '$PROJECT_ID'와 모든 리소스가 삭제됩니다."
echo ""
read -p "정말로 삭제하시겠습니까? (yes/no): " -r
if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    log_info "삭제가 취소되었습니다."
    exit 0
fi

# 리소스 정리
log_info "리소스 정리 중..."

# Compute Engine 인스턴스 삭제
if [ "$INSTANCES" -gt 0 ]; then
    log_info "Compute Engine 인스턴스 삭제 중..."
    gcloud compute instances list --project=$PROJECT_ID --format="value(name,zone)" | while read name zone; do
        if [ -n "$name" ] && [ -n "$zone" ]; then
            log_info "인스턴스 삭제: $name (zone: $zone)"
            gcloud compute instances delete $name --zone=$zone --project=$PROJECT_ID --quiet || true
        fi
    done
fi

# Cloud Storage 버킷 삭제
if [ "$BUCKETS" -gt 0 ]; then
    log_info "Cloud Storage 버킷 삭제 중..."
    gcloud storage buckets list --project=$PROJECT_ID --format="value(name)" | while read bucket; do
        if [ -n "$bucket" ]; then
            log_info "버킷 삭제: $bucket"
            gcloud storage rm -r gs://$bucket --quiet || true
        fi
    done
fi

# 프로젝트 삭제
log_info "프로젝트 삭제 중..."
if gcloud projects delete $PROJECT_ID --quiet; then
    log_success "프로젝트 '$PROJECT_ID'가 삭제되었습니다."
    log_info "삭제된 프로젝트는 30일 후 완전히 삭제됩니다."
    log_info "30일 내에 복구하려면 다음 명령어를 사용하세요:"
    echo "gcloud projects undelete $PROJECT_ID"
else
    log_error "프로젝트 삭제에 실패했습니다."
    exit 1
fi

log_success "=== 프로젝트 정리 완료 ==="
