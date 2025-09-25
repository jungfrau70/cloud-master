#!/bin/bash

# Cloud Master Day3 - 비용 최적화 실습 자동화 스크립트
# 작성일: 2024년 9월 22일
# 목적: AWS, GCP 비용 분석 및 최적화 자동 실행

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
log_header() { echo -e "${PURPLE}=== $1 ===${NC}"; }

# 설정 변수
PROJECT_NAME="cloud-master-day3"
REPORT_DIR="./cost-reports"
AWS_REGION="us-west-2"
GCP_REGION="us-central1"

# 함수 정의
check_prerequisites() {
    log_header "사전 요구사항 확인"
    
    # AWS CLI 확인
    if ! command -v aws &> /dev/null; then
        log_error "AWS CLI가 설치되지 않았습니다."
        exit 1
    fi
    
    # GCP CLI 확인
    if ! command -v gcloud &> /dev/null; then
        log_error "GCP CLI가 설치되지 않았습니다."
        exit 1
    fi
    
    # jq 확인
    if ! command -v jq &> /dev/null; then
        log_warning "jq가 설치되지 않았습니다. 설치합니다."
        if command -v apt-get &> /dev/null; then
            sudo apt-get update && sudo apt-get install -y jq
        elif command -v yum &> /dev/null; then
            sudo yum install -y jq
        else
            log_warning "jq를 수동으로 설치해주세요."
        fi
    fi
    
    log_success "모든 필수 도구가 설치되어 있습니다."
}

create_report_directory() {
    log_header "리포트 디렉토리 생성"
    
    mkdir -p "$REPORT_DIR"/{aws,gcp,analysis}
    
    log_success "리포트 디렉토리 생성 완료"
}

analyze_aws_costs() {
    log_header "AWS 비용 분석"
    
    # Cost Explorer API 활성화 확인
    log_info "Cost Explorer API 활성화 확인 중..."
    
    # 현재 월 비용 조회
    CURRENT_MONTH=$(date +%Y-%m-01)
    NEXT_MONTH=$(date -d "$CURRENT_MONTH +1 month" +%Y-%m-01)
    
    log_info "현재 월 비용 조회 중... ($CURRENT_MONTH ~ $NEXT_MONTH)"
    
    # 비용 및 사용량 조회
    aws ce get-cost-and-usage \
        --time-period Start="$CURRENT_MONTH",End="$NEXT_MONTH" \
        --granularity MONTHLY \
        --metrics BlendedCost UnblendedCost UsageQuantity \
        --group-by Type=DIMENSION,Key=SERVICE \
        --output json > "$REPORT_DIR/aws/cost-and-usage.json"
    
    # 서비스별 비용 분석
    log_info "서비스별 비용 분석 중..."
    jq '.ResultsByTime[0].Groups[] | {Service: .Keys[0], Cost: .Metrics.BlendedCost.Amount}' \
        "$REPORT_DIR/aws/cost-and-usage.json" > "$REPORT_DIR/aws/service-costs.json"
    
    # 예약 인스턴스 권장사항 조회
    log_info "예약 인스턴스 권장사항 조회 중..."
    aws ce get-reservation-coverage \
        --time-period Start="$CURRENT_MONTH",End="$NEXT_MONTH" \
        --granularity MONTHLY \
        --output json > "$REPORT_DIR/aws/reservation-coverage.json"
    
    # Right Sizing 권장사항 조회
    log_info "Right Sizing 권장사항 조회 중..."
    aws ce get-right-sizing-recommendation \
        --service AmazonEC2 \
        --output json > "$REPORT_DIR/aws/right-sizing-recommendations.json"
    
    # Trusted Advisor 비용 최적화 체크
    log_info "Trusted Advisor 비용 최적화 체크 중..."
    aws support describe-trusted-advisor-checks \
        --language en \
        --query 'checks[?category==`cost_optimizing`]' \
        --output json > "$REPORT_DIR/aws/trusted-advisor-cost-checks.json"
    
    log_success "AWS 비용 분석 완료"
}

analyze_gcp_costs() {
    log_header "GCP 비용 분석"
    
    # GCP 프로젝트 ID 가져오기
    GCP_PROJECT_ID=$(gcloud config get-value project)
    if [ -z "$GCP_PROJECT_ID" ]; then
        log_error "GCP 프로젝트가 설정되지 않았습니다."
        return 1
    fi
    
    log_info "GCP 프로젝트 ID: $GCP_PROJECT_ID"
    
    # Billing API 활성화
    log_info "Billing API 활성화 중..."
    gcloud services enable cloudbilling.googleapis.com
    
    # 청구서 계정 목록 조회
    log_info "청구서 계정 목록 조회 중..."
    gcloud billing accounts list --format=json > "$REPORT_DIR/gcp/billing-accounts.json"
    
    # 프로젝트별 비용 조회
    log_info "프로젝트별 비용 조회 중..."
    gcloud billing budgets list --billing-account=$(jq -r '.[0].name' "$REPORT_DIR/gcp/billing-accounts.json" | cut -d'/' -f2) \
        --format=json > "$REPORT_DIR/gcp/budgets.json"
    
    # Recommender 권장사항 조회
    log_info "Recommender 권장사항 조회 중..."
    
    # 인스턴스 타입 권장사항
    gcloud recommender recommendations list \
        --recommender=google.compute.instance.MachineTypeRecommender \
        --project="$GCP_PROJECT_ID" \
        --format=json > "$REPORT_DIR/gcp/machine-type-recommendations.json"
    
    # 커밋 사용 할인 권장사항
    gcloud recommender recommendations list \
        --recommender=google.compute.commitment.UsageCommitmentRecommender \
        --project="$GCP_PROJECT_ID" \
        --format=json > "$REPORT_DIR/gcp/commitment-recommendations.json"
    
    # 스토리지 권장사항
    gcloud recommender recommendations list \
        --recommender=google.compute.disk.IdleResourceRecommender \
        --project="$GCP_PROJECT_ID" \
        --format=json > "$REPORT_DIR/gcp/storage-recommendations.json"
    
    log_success "GCP 비용 분석 완료"
}

generate_cost_report() {
    log_header "비용 분석 리포트 생성"
    
    # AWS 비용 요약
    cat > "$REPORT_DIR/analysis/aws-cost-summary.md" << 'EOF'
# AWS 비용 분석 리포트

## 서비스별 비용 현황
EOF

    # 서비스별 비용 테이블 생성
    echo "| 서비스 | 비용 (USD) |" >> "$REPORT_DIR/analysis/aws-cost-summary.md"
    echo "|--------|------------|" >> "$REPORT_DIR/analysis/aws-cost-summary.md"
    
    jq -r '.ResultsByTime[0].Groups[] | "| \(.Keys[0]) | \(.Metrics.BlendedCost.Amount) |"' \
        "$REPORT_DIR/aws/cost-and-usage.json" >> "$REPORT_DIR/analysis/aws-cost-summary.md"
    
    # GCP 비용 요약
    cat > "$REPORT_DIR/analysis/gcp-cost-summary.md" << 'EOF'
# GCP 비용 분석 리포트

## 프로젝트별 비용 현황
EOF

    # 예산 정보 테이블 생성
    echo "| 예산 이름 | 예산 금액 | 사용 금액 |" >> "$REPORT_DIR/analysis/gcp-cost-summary.md"
    echo "|-----------|-----------|-----------|" >> "$REPORT_DIR/analysis/gcp-cost-summary.md"
    
    jq -r '.budgets[] | "| \(.displayName) | \(.budgetFilter.calendarPeriod) | \(.amount.specifiedAmount.units) |"' \
        "$REPORT_DIR/gcp/budgets.json" >> "$REPORT_DIR/analysis/gcp-cost-summary.md"
    
    # 통합 분석 리포트
    cat > "$REPORT_DIR/analysis/integrated-cost-analysis.md" << 'EOF'
# Cloud Master Day3 - 통합 비용 분석 리포트

## 분석 개요
- 분석 일시: $(date)
- AWS 리전: us-west-2
- GCP 리전: us-central1

## 주요 발견사항

### AWS 비용 최적화 기회
1. **예약 인스턴스 활용**: 현재 사용 중인 EC2 인스턴스에 대한 예약 인스턴스 권장사항 확인
2. **Right Sizing**: 과도하게 큰 인스턴스 타입 사용 시 다운사이징 권장
3. **미사용 리소스**: 사용하지 않는 EBS 볼륨, 스냅샷 등 정리 필요

### GCP 비용 최적화 기회
1. **커밋 사용 할인**: 장기 사용 예정 인스턴스에 대한 커밋 사용 할인 적용
2. **인스턴스 타입 최적화**: 현재 사용 중인 인스턴스 타입 최적화 권장
3. **스토리지 최적화**: 사용하지 않는 디스크 정리 및 스토리지 클래스 최적화

## 권장사항

### 즉시 실행 가능한 최적화
1. 미사용 리소스 정리
2. 과도한 인스턴스 크기 조정
3. 불필요한 스토리지 정리

### 중장기 최적화
1. 예약 인스턴스/커밋 사용 할인 적용
2. 자동 스케일링 정책 최적화
3. 스팟/프리엠티블 인스턴스 활용

## 비용 절감 예상 효과
- **단기 (1개월)**: 10-20% 비용 절감
- **중기 (3개월)**: 20-30% 비용 절감
- **장기 (6개월)**: 30-40% 비용 절감
EOF

    log_success "비용 분석 리포트 생성 완료"
}

implement_aws_optimizations() {
    log_header "AWS 비용 최적화 실행"
    
    # 미사용 EBS 볼륨 식별 및 삭제
    log_info "미사용 EBS 볼륨 식별 중..."
    UNUSED_VOLUMES=$(aws ec2 describe-volumes \
        --filters "Name=status,Values=available" \
        --query 'Volumes[?State==`available`].VolumeId' \
        --output text)
    
    if [ -n "$UNUSED_VOLUMES" ]; then
        log_warning "미사용 EBS 볼륨 발견: $UNUSED_VOLUMES"
        log_info "미사용 EBS 볼륨 삭제 중..."
        for volume in $UNUSED_VOLUMES; do
            aws ec2 delete-volume --volume-id "$volume"
            log_success "EBS 볼륨 삭제 완료: $volume"
        done
    else
        log_info "삭제할 미사용 EBS 볼륨이 없습니다."
    fi
    
    # 스팟 인스턴스 요청 (테스트용)
    log_info "스팟 인스턴스 가격 조회 중..."
    aws ec2 describe-spot-price-history \
        --instance-types t3.micro \
        --product-descriptions "Linux/UNIX" \
        --max-items 5 \
        --output table
    
    log_success "AWS 비용 최적화 실행 완료"
}

implement_gcp_optimizations() {
    log_header "GCP 비용 최적화 실행"
    
    # GCP 프로젝트 ID 가져오기
    GCP_PROJECT_ID=$(gcloud config get-value project)
    
    # 미사용 디스크 식별 및 삭제
    log_info "미사용 디스크 식별 중..."
    UNUSED_DISKS=$(gcloud compute disks list \
        --filter="status:UNATTACHED" \
        --format="value(name,zone)" \
        --project="$GCP_PROJECT_ID")
    
    if [ -n "$UNUSED_DISKS" ]; then
        log_warning "미사용 디스크 발견:"
        echo "$UNUSED_DISKS"
        log_info "미사용 디스크 삭제 중..."
        echo "$UNUSED_DISKS" | while read -r disk zone; do
            gcloud compute disks delete "$disk" --zone="$zone" --quiet
            log_success "디스크 삭제 완료: $disk"
        done
    else
        log_info "삭제할 미사용 디스크가 없습니다."
    fi
    
    # 프리엠티블 인스턴스 생성 (테스트용)
    log_info "프리엠티블 인스턴스 가격 조회 중..."
    gcloud compute instances create test-preemptible \
        --image-family=ubuntu-2004-lts \
        --image-project=ubuntu-os-cloud \
        --machine-type=e2-micro \
        --preemptible \
        --zone=us-central1-a \
        --quiet
    
    log_success "GCP 비용 최적화 실행 완료"
}

setup_cost_monitoring() {
    log_header "비용 모니터링 설정"
    
    # AWS 비용 알림 설정
    log_info "AWS 비용 알림 설정 중..."
    
    # CloudWatch 알림 설정
    aws cloudwatch put-metric-alarm \
        --alarm-name "High-Cost-Alert" \
        --alarm-description "Alert when daily cost exceeds $10" \
        --metric-name EstimatedCharges \
        --namespace AWS/Billing \
        --statistic Maximum \
        --period 86400 \
        --threshold 10 \
        --comparison-operator GreaterThanThreshold \
        --evaluation-periods 1
    
    # GCP 비용 알림 설정
    log_info "GCP 비용 알림 설정 중..."
    
    # 예산 알림 설정
    gcloud billing budgets create \
        --billing-account=$(jq -r '.[0].name' "$REPORT_DIR/gcp/billing-accounts.json" | cut -d'/' -f2) \
        --display-name="Cloud Master Day3 Budget" \
        --budget-amount=100USD \
        --threshold-rule=percent=80 \
        --threshold-rule=percent=100
    
    log_success "비용 모니터링 설정 완료"
}

generate_optimization_script() {
    log_header "비용 최적화 스크립트 생성"
    
    cat > "$REPORT_DIR/cost-optimization-daily.sh" << 'EOF'
#!/bin/bash

# 일일 비용 최적화 스크립트
# Cloud Master Day3 - 자동 비용 최적화

echo "=== 일일 비용 최적화 실행 ==="
echo "실행 시간: $(date)"

# AWS 미사용 리소스 정리
echo "AWS 미사용 리소스 정리 중..."
aws ec2 describe-volumes --filters "Name=status,Values=available" --query 'Volumes[?State==`available`].VolumeId' --output text | while read volume; do
    if [ -n "$volume" ]; then
        aws ec2 delete-volume --volume-id "$volume"
        echo "EBS 볼륨 삭제: $volume"
    fi
done

# GCP 미사용 리소스 정리
echo "GCP 미사용 리소스 정리 중..."
gcloud compute disks list --filter="status:UNATTACHED" --format="value(name,zone)" | while read disk zone; do
    if [ -n "$disk" ]; then
        gcloud compute disks delete "$disk" --zone="$zone" --quiet
        echo "디스크 삭제: $disk"
    fi
done

echo "일일 비용 최적화 완료"
EOF

    chmod +x "$REPORT_DIR/cost-optimization-daily.sh"
    
    log_success "비용 최적화 스크립트 생성 완료"
}

cleanup() {
    log_header "리소스 정리"
    
    # 테스트용 프리엠티블 인스턴스 삭제
    log_info "테스트용 프리엠티블 인스턴스 삭제 중..."
    gcloud compute instances delete test-preemptible --zone=us-central1-a --quiet 2>/dev/null || true
    
    # 리포트 디렉토리 정리
    if [ -d "$REPORT_DIR" ]; then
        log_info "리포트 디렉토리 정리 중..."
        # 중요한 리포트만 보존
        find "$REPORT_DIR" -name "*.json" -mtime +30 -delete
        log_success "리포트 디렉토리 정리 완료"
    fi
    
    log_success "모든 리소스 정리 완료"
}

show_help() {
    echo "Cloud Master Day3 - 비용 최적화 실습 자동화 스크립트"
    echo ""
    echo "사용법: $0 [옵션]"
    echo ""
    echo "옵션:"
    echo "  analyze    비용 분석 실행 (기본값)"
    echo "  optimize   비용 최적화 실행"
    echo "  monitor    비용 모니터링 설정"
    echo "  report     리포트 생성"
    echo "  cleanup    리소스 정리"
    echo "  help       도움말 표시"
    echo ""
    echo "예시:"
    echo "  $0 analyze   # 비용 분석 실행"
    echo "  $0 optimize  # 비용 최적화 실행"
    echo "  $0 monitor   # 비용 모니터링 설정"
    echo "  $0 report    # 리포트 생성"
    echo "  $0 cleanup   # 리소스 정리"
    echo ""
    echo "생성되는 파일:"
    echo "  $REPORT_DIR/aws/ - AWS 비용 분석 데이터"
    echo "  $REPORT_DIR/gcp/ - GCP 비용 분석 데이터"
    echo "  $REPORT_DIR/analysis/ - 통합 분석 리포트"
}

# 메인 실행
main() {
    case "${1:-analyze}" in
        "analyze")
            check_prerequisites
            create_report_directory
            analyze_aws_costs
            analyze_gcp_costs
            generate_cost_report
            log_success "비용 분석 완료!"
            ;;
        "optimize")
            implement_aws_optimizations
            implement_gcp_optimizations
            log_success "비용 최적화 실행 완료!"
            ;;
        "monitor")
            setup_cost_monitoring
            generate_optimization_script
            log_success "비용 모니터링 설정 완료!"
            ;;
        "report")
            generate_cost_report
            log_success "리포트 생성 완료!"
            ;;
        "cleanup")
            cleanup
            ;;
        "help"|"-h"|"--help")
            show_help
            ;;
        *)
            log_error "알 수 없는 옵션: $1"
            show_help
            exit 1
            ;;
    esac
}

# 스크립트 실행
main "$@"
