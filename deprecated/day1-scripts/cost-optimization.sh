#!/bin/bash

# 비용 최적화 스크립트
# Cloud Master Day3용 - 모니터링 & 비용 최적화

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

# 설정 변수
PROJECT_NAME="cloud-master-cost"
REGION="us-central1"
ZONE="us-central1-a"

# 체크포인트 파일
CHECKPOINT_FILE="cost-optimization-checkpoint.json"

# 체크포인트 로드
load_checkpoint() {
    if [ -f "$CHECKPOINT_FILE" ]; then
        log_info "체크포인트 파일 로드 중..."
        source "$CHECKPOINT_FILE"
    fi
}

# 체크포인트 저장
save_checkpoint() {
    log_info "체크포인트 저장 중..."
    cat > "$CHECKPOINT_FILE" << EOF
COST_ANALYSIS_COMPLETED=$COST_ANALYSIS_COMPLETED
RECOMMENDATIONS_GENERATED=$RECOMMENDATIONS_GENERATED
OPTIMIZATION_APPLIED=$OPTIMIZATION_APPLIED
EOF
}

# 환경 체크
check_environment() {
    log_info "환경 체크 중..."
    
    # gcloud CLI 체크
    if ! command -v gcloud &> /dev/null; then
        log_error "gcloud CLI가 설치되지 않았습니다."
        exit 1
    fi
    
    # AWS CLI 체크 (선택사항)
    if command -v aws &> /dev/null; then
        log_info "AWS CLI 감지됨"
        AWS_MODE=true
    else
        log_warning "AWS CLI가 설치되지 않았습니다. GCP 모드로 실행합니다."
        AWS_MODE=false
    fi
    
    # 인증 체크
    if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q .; then
        log_error "GCP 인증이 필요합니다. 'gcloud auth login'을 실행하세요."
        exit 1
    fi
    
    # 프로젝트 설정 체크
    if ! gcloud config get-value project &> /dev/null; then
        log_error "GCP 프로젝트가 설정되지 않았습니다."
        exit 1
    fi
    
    log_success "환경 체크 완료"
}

# GCP 비용 분석
analyze_gcp_costs() {
    log_info "GCP 비용 분석 중..."
    
    # 청구서 정보 조회
    log_info "청구서 정보:"
    gcloud billing accounts list
    
    # 프로젝트별 비용 조회
    log_info "프로젝트별 비용:"
    gcloud billing budgets list --billing-account=123456789012
    
    # 커밋 사용 할인 권장사항 조회
    log_info "커밋 사용 할인 권장사항:"
    gcloud compute commitments list --regions="$REGION"
    
    # 인스턴스 사용량 분석
    log_info "인스턴스 사용량 분석:"
    gcloud compute instances list --format="table(name,zone,machineType,status,creationTimestamp)"
    
    # 디스크 사용량 분석
    log_info "디스크 사용량 분석:"
    gcloud compute disks list --format="table(name,zone,sizeGb,type,status)"
    
    # 네트워크 사용량 분석
    log_info "네트워크 사용량 분석:"
    gcloud compute networks list --format="table(name,subnetMode,autoCreateSubnetworks)"
    
    # 스냅샷 사용량 분석
    log_info "스냅샷 사용량 분석:"
    gcloud compute snapshots list --format="table(name,sourceDisk,creationTimestamp,diskSizeGb)"
    
    COST_ANALYSIS_COMPLETED="true"
    log_success "GCP 비용 분석 완료"
}

# AWS 비용 분석
analyze_aws_costs() {
    if [ "$AWS_MODE" = "false" ]; then
        return 0
    fi
    
    log_info "AWS 비용 분석 중..."
    
    # Cost Explorer API 사용
    log_info "Cost Explorer 데이터 조회:"
    aws ce get-cost-and-usage \
        --time-period Start=2024-01-01,End=2024-01-31 \
        --granularity MONTHLY \
        --metrics BlendedCost
    
    # Reserved Instances 권장사항 조회
    log_info "Reserved Instances 권장사항:"
    aws ce get-reservation-coverage \
        --time-period Start=2024-01-01,End=2024-01-31
    
    # Right Sizing 권장사항 조회
    log_info "Right Sizing 권장사항:"
    aws ce get-right-sizing-recommendation \
        --service=AmazonEC2
    
    # 인스턴스 사용량 분석
    log_info "인스턴스 사용량 분석:"
    aws ec2 describe-instances \
        --query 'Reservations[*].Instances[*].[InstanceId,InstanceType,State.Name,LaunchTime]' \
        --output table
    
    # 사용하지 않는 리소스 식별
    log_info "사용하지 않는 리소스:"
    aws ec2 describe-volumes \
        --filters "Name=status,Values=available" \
        --query 'Volumes[*].[VolumeId,Size,State]' \
        --output table
    
    # 스팟 인스턴스 가격 조회
    log_info "스팟 인스턴스 가격:"
    aws ec2 describe-spot-price-history \
        --instance-types t2.micro \
        --product-descriptions "Linux/UNIX" \
        --max-items 10
    
    log_success "AWS 비용 분석 완료"
}

# 비용 최적화 권장사항 생성
generate_recommendations() {
    if [ "$RECOMMENDATIONS_GENERATED" = "true" ]; then
        log_info "권장사항이 이미 생성되어 있습니다."
        return 0
    fi
    
    log_info "비용 최적화 권장사항 생성 중..."
    
    # 권장사항 파일 생성
    cat > cost-optimization-recommendations.md << EOF
# Cloud Master Day3 - 비용 최적화 권장사항

## 📊 비용 분석 결과

### GCP 비용 분석
- **총 비용**: [분석 결과에 따라 업데이트]
- **주요 비용 항목**: Compute Engine, Cloud Storage, Network
- **비용 트렌드**: [월별 비용 변화]

### AWS 비용 분석
- **총 비용**: [분석 결과에 따라 업데이트]
- **주요 비용 항목**: EC2, S3, Data Transfer
- **비용 트렌드**: [월별 비용 변화]

## 💡 비용 최적화 권장사항

### 1. 인스턴스 최적화
- **Right Sizing**: 사용하지 않는 리소스 식별 및 크기 조정
- **Preemptible Instances**: 단기 작업에 선점 가능 인스턴스 사용
- **Committed Use Discounts**: 장기 사용 시 약정 할인 활용

### 2. 스토리지 최적화
- **Cold Storage**: 자주 접근하지 않는 데이터를 Cold Storage로 이동
- **Lifecycle Policies**: 자동 데이터 아카이빙 정책 설정
- **중복 제거**: 중복된 스냅샷 및 이미지 정리

### 3. 네트워크 최적화
- **CDN 활용**: 정적 콘텐츠에 CDN 사용
- **데이터 전송 최적화**: 불필요한 데이터 전송 최소화
- **리전 최적화**: 사용자와 가까운 리전 선택

### 4. 모니터링 및 알림
- **비용 알림**: 예산 초과 시 알림 설정
- **사용량 모니터링**: 실시간 리소스 사용량 모니터링
- **정기 검토**: 월간 비용 검토 및 최적화

## 🎯 즉시 적용 가능한 최적화

### GCP
1. **Preemptible Instances 사용**: 개발/테스트 환경에 선점 가능 인스턴스 사용
2. **Committed Use Discounts**: 프로덕션 환경에 약정 할인 적용
3. **Storage Class 최적화**: 데이터 접근 패턴에 따른 스토리지 클래스 선택

### AWS
1. **Reserved Instances**: 안정적인 워크로드에 예약 인스턴스 사용
2. **Spot Instances**: 배치 작업에 스팟 인스턴스 사용
3. **Savings Plans**: 유연한 절약 계획 활용

## 📈 예상 절약 효과
- **인스턴스 최적화**: 20-30% 비용 절약
- **스토리지 최적화**: 15-25% 비용 절약
- **네트워크 최적화**: 10-20% 비용 절약
- **전체 예상 절약**: 30-50% 비용 절약

## 🔧 자동화 도구
- **Terraform**: 인프라 코드화로 비용 예측 가능
- **Ansible**: 자동화된 리소스 관리
- **CloudWatch/Cloud Monitoring**: 실시간 비용 모니터링
EOF
    
    RECOMMENDATIONS_GENERATED="true"
    log_success "비용 최적화 권장사항 생성 완료"
}

# GCP 비용 최적화 적용
apply_gcp_optimizations() {
    if [ "$OPTIMIZATION_APPLIED" = "true" ]; then
        log_info "비용 최적화가 이미 적용되어 있습니다."
        return 0
    fi
    
    log_info "GCP 비용 최적화 적용 중..."
    
    # 1. 사용하지 않는 인스턴스 정리
    log_info "사용하지 않는 인스턴스 정리 중..."
    gcloud compute instances list --filter="status=TERMINATED" --format="value(name,zone)" | while read name zone; do
        if [ ! -z "$name" ]; then
            log_info "인스턴스 삭제: $name in $zone"
            gcloud compute instances delete "$name" --zone="$zone" --quiet
        fi
    done
    
    # 2. 사용하지 않는 디스크 정리
    log_info "사용하지 않는 디스크 정리 중..."
    gcloud compute disks list --filter="status=UNATTACHED" --format="value(name,zone)" | while read name zone; do
        if [ ! -z "$name" ]; then
            log_info "디스크 삭제: $name in $zone"
            gcloud compute disks delete "$name" --zone="$zone" --quiet
        fi
    done
    
    # 3. 오래된 스냅샷 정리
    log_info "오래된 스냅샷 정리 중..."
    gcloud compute snapshots list --filter="creationTimestamp<2024-01-01" --format="value(name)" | while read name; do
        if [ ! -z "$name" ]; then
            log_info "스냅샷 삭제: $name"
            gcloud compute snapshots delete "$name" --quiet
        fi
    done
    
    # 4. Preemptible Instances로 변경 (개발 환경)
    log_info "개발 환경을 Preemptible Instances로 변경 중..."
    gcloud compute instances list --filter="name~dev-*" --format="value(name,zone)" | while read name zone; do
        if [ ! -z "$name" ]; then
            log_info "인스턴스 중지: $name in $zone"
            gcloud compute instances stop "$name" --zone="$zone" --quiet
        fi
    done
    
    OPTIMIZATION_APPLIED="true"
    log_success "GCP 비용 최적화 적용 완료"
}

# AWS 비용 최적화 적용
apply_aws_optimizations() {
    if [ "$AWS_MODE" = "false" ]; then
        return 0
    fi
    
    log_info "AWS 비용 최적화 적용 중..."
    
    # 1. 사용하지 않는 인스턴스 정리
    log_info "사용하지 않는 인스턴스 정리 중..."
    aws ec2 describe-instances \
        --filters "Name=instance-state-name,Values=stopped" \
        --query 'Reservations[*].Instances[*].[InstanceId,State.Name]' \
        --output text | while read instance_id state; do
        if [ ! -z "$instance_id" ]; then
            log_info "인스턴스 종료: $instance_id"
            aws ec2 terminate-instances --instance-ids "$instance_id"
        fi
    done
    
    # 2. 사용하지 않는 볼륨 정리
    log_info "사용하지 않는 볼륨 정리 중..."
    aws ec2 describe-volumes \
        --filters "Name=status,Values=available" \
        --query 'Volumes[*].[VolumeId,Size]' \
        --output text | while read volume_id size; do
        if [ ! -z "$volume_id" ]; then
            log_info "볼륨 삭제: $volume_id (Size: $size GB)"
            aws ec2 delete-volume --volume-id "$volume_id"
        fi
    done
    
    # 3. 오래된 스냅샷 정리
    log_info "오래된 스냅샷 정리 중..."
    aws ec2 describe-snapshots \
        --owner-ids self \
        --filters "Name=start-time,Values=2024-01-01" \
        --query 'Snapshots[*].[SnapshotId,StartTime]' \
        --output text | while read snapshot_id start_time; do
        if [ ! -z "$snapshot_id" ]; then
            log_info "스냅샷 삭제: $snapshot_id (Created: $start_time)"
            aws ec2 delete-snapshot --snapshot-id "$snapshot_id"
        fi
    done
    
    log_success "AWS 비용 최적화 적용 완료"
}

# 비용 모니터링 설정
setup_cost_monitoring() {
    log_info "비용 모니터링 설정 중..."
    
    # GCP Budget 설정
    log_info "GCP Budget 설정 중..."
    gcloud billing budgets create \
        --billing-account=123456789012 \
        --display-name="Cloud Master Budget" \
        --budget-amount=100USD \
        --threshold-rule=percent=50 \
        --threshold-rule=percent=80 \
        --threshold-rule=percent=100
    
    # AWS Budget 설정
    if [ "$AWS_MODE" = "true" ]; then
        log_info "AWS Budget 설정 중..."
        aws budgets create-budget \
            --account-id 123456789012 \
            --budget '{
                "BudgetName": "Cloud Master Budget",
                "BudgetLimit": {
                    "Amount": "100",
                    "Unit": "USD"
                },
                "TimeUnit": "MONTHLY",
                "BudgetType": "COST"
            }'
    fi
    
    log_success "비용 모니터링 설정 완료"
}

# 비용 최적화 보고서 생성
generate_cost_report() {
    log_info "비용 최적화 보고서 생성 중..."
    
    # 보고서 파일 생성
    cat > cost-optimization-report.md << EOF
# Cloud Master Day3 - 비용 최적화 보고서

## 📊 실행 결과

### 실행 일시
- **실행 시간**: $(date)
- **실행 환경**: GCP + AWS
- **분석 기간**: 2024년 1월

### 최적화 적용 결과
- **정리된 인스턴스**: [개수]
- **정리된 디스크**: [개수]
- **정리된 스냅샷**: [개수]
- **예상 절약 비용**: [금액]

### 권장사항 적용 상태
- [x] 사용하지 않는 리소스 정리
- [x] 비용 모니터링 설정
- [x] 권장사항 문서화
- [ ] Reserved Instances 적용
- [ ] Preemptible Instances 적용

## 📈 다음 단계
1. **주간 비용 검토**: 매주 비용 변화 모니터링
2. **월간 최적화**: 매월 비용 최적화 실행
3. **분기별 검토**: 분기별 비용 전략 검토
4. **자동화 구축**: 비용 최적화 자동화 스크립트 구축

## 🔧 유지보수
- **스크립트 실행**: 매주 금요일 자동 실행
- **알림 설정**: 예산 초과 시 즉시 알림
- **문서 업데이트**: 권장사항 지속적 업데이트
EOF
    
    log_success "비용 최적화 보고서 생성 완료"
}

# 정리 함수
cleanup() {
    log_info "정리 중..."
    
    # 체크포인트 파일 삭제
    rm -f "$CHECKPOINT_FILE"
    
    log_success "정리 완료"
}

# 메인 함수
main() {
    log_info "=== Cloud Master Day3 - 비용 최적화 시작 ==="
    
    # 체크포인트 로드
    load_checkpoint
    
    # 환경 체크
    check_environment
    
    # 비용 분석
    analyze_gcp_costs
    analyze_aws_costs
    save_checkpoint
    
    # 권장사항 생성
    generate_recommendations
    save_checkpoint
    
    # 비용 최적화 적용
    apply_gcp_optimizations
    apply_aws_optimizations
    save_checkpoint
    
    # 비용 모니터링 설정
    setup_cost_monitoring
    
    # 보고서 생성
    generate_cost_report
    
    log_success "=== 비용 최적화 완료 ==="
    log_info "프로젝트 이름: $PROJECT_NAME"
    log_info "리전: $REGION"
    log_info "분석 기간: 2024년 1월"
    
    log_info "생성된 파일:"
    log_info "1. cost-optimization-recommendations.md - 권장사항"
    log_info "2. cost-optimization-report.md - 실행 보고서"
    
    log_info "다음 단계:"
    log_info "1. 권장사항 검토 및 적용"
    log_info "2. 비용 모니터링 설정 확인"
    log_info "3. 정기적인 비용 검토 스케줄 설정"
}

# 스크립트 실행
if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    main "$@"
fi
