#!/bin/bash

# Cloud Master Day3 - GCP 비용 최적화 실습 자동화 스크립트
# GCP 리소스 비용 분석 및 최적화 권장사항 제공

set -e

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

# 프로젝트 설정
PROJECT_NAME="cloud-master-day3-gcp-cost"
REPORT_DIR="cost-reports/gcp"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

# 타임아웃 함수
run_with_timeout() {
    local timeout=$1
    shift
    timeout $timeout "$@" 2>/dev/null || {
        log_warning "명령어가 타임아웃되었습니다 (${timeout}초)"
        return 1
    }
}

# 사전 요구사항 확인
check_prerequisites() {
    log_info "=== 사전 요구사항 확인 ==="
    
    # GCP CLI 확인
    if ! command -v gcloud &> /dev/null; then
        log_error "gcloud CLI가 설치되지 않았습니다."
        exit 1
    fi
    
    # jq 확인
    if ! command -v jq &> /dev/null; then
        log_warning "jq가 설치되지 않았습니다. JSON 파싱이 제한될 수 있습니다."
    fi
    
    log_success "모든 필수 도구가 설치되어 있습니다."
}

# 환경 설정
setup_environment() {
    log_info "=== 환경 설정 ==="
    
    # GCP 프로젝트 설정
    if ! gcloud config get-value project &> /dev/null; then
        log_error "GCP 프로젝트가 설정되지 않았습니다."
        log_info "다음 명령어로 프로젝트를 설정하세요:"
        log_info "gcloud config set project YOUR_PROJECT_ID"
        exit 1
    fi
    
    # GCP 인증 확인
    if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | head -1 &> /dev/null; then
        log_error "GCP 인증이 필요합니다."
        log_info "다음 명령어로 인증하세요:"
        log_info "gcloud auth login"
        exit 1
    fi
    
    # Billing API 활성화
    log_info "Billing API 활성화 확인 중..."
    gcloud services enable cloudbilling.googleapis.com --quiet
    
    # Compute Engine API 활성화
    gcloud services enable compute.googleapis.com --quiet
    
    log_success "환경 설정 완료"
}

# 리포트 디렉토리 생성
create_report_directories() {
    log_info "=== 리포트 디렉토리 생성 ==="
    
    mkdir -p "$REPORT_DIR"/{instances,disks,networking,recommendations}
    
    log_success "리포트 디렉토리 생성 완료"
}

# 인스턴스 비용 분석
analyze_instances() {
    log_info "=== 인스턴스 비용 분석 ==="
    
    # 실행 중인 인스턴스 분석
    log_info "실행 중인 인스턴스 분석 중..."
    gcloud compute instances list \
        --format="table(name,zone,machineType,status,creationTimestamp)" \
        --filter="status=RUNNING" > "$REPORT_DIR/instances/running-instances.txt"
    
    # 중지된 인스턴스 분석
    log_info "중지된 인스턴스 분석 중..."
    gcloud compute instances list \
        --format="table(name,zone,machineType,status,creationTimestamp)" \
        --filter="status=TERMINATED" > "$REPORT_DIR/instances/stopped-instances.txt"
    
    # 인스턴스별 상세 정보
    log_info "인스턴스별 상세 정보 수집 중..."
    gcloud compute instances list --format="json" > "$REPORT_DIR/instances/instances-detail.json"
    
    # 비용 절약 가능한 인스턴스 식별
    log_info "비용 절약 가능한 인스턴스 식별 중..."
    cat > "$REPORT_DIR/instances/cost-savings-analysis.txt" << 'EOF'
=== GCP 인스턴스 비용 절약 분석 ===

1. 중지된 인스턴스 (삭제 고려):
   - 중지된 인스턴스는 디스크 비용만 발생
   - 스냅샷 생성 후 삭제 권장

2. 과도한 리소스 할당:
   - CPU 사용률이 낮은 인스턴스
   - 메모리 사용률이 낮은 인스턴스
   - 더 작은 머신 타입으로 다운사이징 고려

3. 스팟 인스턴스 활용:
   - 개발/테스트 환경에서 스팟 인스턴스 사용
   - 최대 90% 비용 절약 가능

4. 커밋 사용 할인:
   - 1년 또는 3년 커밋 사용 할인
   - 안정적인 워크로드에 적용

5. Preemptible 인스턴스:
   - 단기 작업에 Preemptible 인스턴스 사용
   - 최대 80% 비용 절약 가능
EOF
    
    log_success "인스턴스 비용 분석 완료"
}

# 디스크 비용 분석
analyze_disks() {
    log_info "=== 디스크 비용 분석 ==="
    
    # 모든 디스크 목록
    log_info "디스크 목록 수집 중..."
    gcloud compute disks list \
        --format="table(name,zone,sizeGb,type,status,creationTimestamp)" > "$REPORT_DIR/disks/all-disks.txt"
    
    # 사용하지 않는 디스크
    log_info "사용하지 않는 디스크 분석 중..."
    gcloud compute disks list \
        --format="table(name,zone,sizeGb,type,status,creationTimestamp)" \
        --filter="status=UNATTACHED" > "$REPORT_DIR/disks/unattached-disks.txt"
    
    # 디스크별 상세 정보
    log_info "디스크별 상세 정보 수집 중..."
    gcloud compute disks list --format="json" > "$REPORT_DIR/disks/disks-detail.json"
    
    # 디스크 비용 절약 권장사항
    log_info "디스크 비용 절약 권장사항 생성 중..."
    cat > "$REPORT_DIR/disks/disk-cost-savings.txt" << 'EOF'
=== GCP 디스크 비용 절약 분석 ===

1. 사용하지 않는 디스크:
   - UNATTACHED 상태의 디스크는 즉시 삭제 권장
   - 스냅샷 생성 후 삭제 고려

2. 디스크 타입 최적화:
   - Standard Persistent Disk: 일반적인 워크로드
   - SSD Persistent Disk: 고성능이 필요한 워크로드
   - Balanced Persistent Disk: 성능과 비용의 균형

3. 디스크 크기 최적화:
   - 실제 사용량에 맞게 디스크 크기 조정
   - 디스크 스냅샷을 통한 크기 조정

4. 스냅샷 정책:
   - 불필요한 스냅샷 정리
   - 스냅샷 보존 정책 설정

5. 지역별 디스크 비용:
   - 비용이 낮은 지역으로 디스크 이동 고려
   - 데이터 위치 요구사항 확인
EOF
    
    log_success "디스크 비용 분석 완료"
}

# 네트워킹 비용 분석
analyze_networking() {
    log_info "=== 네트워킹 비용 분석 ==="
    
    # 외부 IP 주소
    log_info "외부 IP 주소 분석 중..."
    gcloud compute addresses list \
        --format="table(name,region,address,status,users)" > "$REPORT_DIR/networking/external-ips.txt"
    
    # 사용하지 않는 외부 IP
    log_info "사용하지 않는 외부 IP 분석 중..."
    gcloud compute addresses list \
        --format="table(name,region,address,status,users)" \
        --filter="status=RESERVED AND users=null" > "$REPORT_DIR/networking/unused-external-ips.txt"
    
    # 방화벽 규칙
    log_info "방화벽 규칙 분석 중..."
    gcloud compute firewall-rules list \
        --format="table(name,direction,priority,sourceRanges,allowed[].map().firewall_rule().list():label=ALLOW)" > "$REPORT_DIR/networking/firewall-rules.txt"
    
    # 네트워킹 비용 절약 권장사항
    log_info "네트워킹 비용 절약 권장사항 생성 중..."
    cat > "$REPORT_DIR/networking/networking-cost-savings.txt" << 'EOF'
=== GCP 네트워킹 비용 절약 분석 ===

1. 사용하지 않는 외부 IP:
   - RESERVED 상태이지만 사용되지 않는 IP는 삭제 권장
   - 외부 IP는 시간당 비용 발생

2. 네트워크 트래픽 최적화:
   - 동일 리전 내 통신은 무료
   - CDN 사용으로 트래픽 비용 절약

3. 방화벽 규칙 정리:
   - 사용하지 않는 방화벽 규칙 삭제
   - 과도하게 열린 포트 정리

4. VPC 피어링:
   - VPC 피어링을 통한 내부 통신
   - 외부 트래픽 최소화

5. Cloud NAT 사용:
   - 프라이빗 인스턴스에서 Cloud NAT 사용
   - 외부 IP 비용 절약
EOF
    
    log_success "네트워킹 비용 분석 완료"
}

# 비용 최적화 권장사항 생성
generate_recommendations() {
    log_info "=== 비용 최적화 권장사항 생성 ==="
    
    # 통합 비용 최적화 리포트 생성
    cat > "$REPORT_DIR/recommendations/cost-optimization-report.md" << EOF
# GCP 비용 최적화 분석 리포트

**생성일**: $(date)
**프로젝트**: $(gcloud config get-value project)
**분석자**: Cloud Master Day3 자동화 스크립트

## 📊 요약

### 현재 상태
- **실행 중인 인스턴스**: $(gcloud compute instances list --filter="status=RUNNING" --format="value(name)" | wc -l)개
- **중지된 인스턴스**: $(gcloud compute instances list --filter="status=TERMINATED" --format="value(name)" | wc -l)개
- **사용하지 않는 디스크**: $(gcloud compute disks list --filter="status=UNATTACHED" --format="value(name)" | wc -l)개
- **사용하지 않는 외부 IP**: $(gcloud compute addresses list --filter="status=RESERVED AND users=null" --format="value(name)" | wc -l)개

### 💰 비용 절약 기회

#### 1. 즉시 실행 가능한 절약
- **중지된 인스턴스 삭제**: 중지된 인스턴스는 디스크 비용만 발생
- **사용하지 않는 디스크 삭제**: UNATTACHED 디스크 즉시 삭제
- **사용하지 않는 외부 IP 해제**: RESERVED IP 주소 해제

#### 2. 단기 절약 (1주일 내)
- **인스턴스 크기 조정**: CPU/메모리 사용률 분석 후 다운사이징
- **디스크 타입 변경**: Standard → Balanced 또는 SSD → Standard
- **스냅샷 정리**: 불필요한 스냅샷 삭제

#### 3. 중기 절약 (1개월 내)
- **커밋 사용 할인**: 1년 또는 3년 커밋 구매
- **스팟 인스턴스 도입**: 개발/테스트 환경에 스팟 인스턴스 사용
- **Preemptible 인스턴스**: 단기 작업에 Preemptible 인스턴스 사용

#### 4. 장기 절약 (3개월 내)
- **아키텍처 최적화**: 마이크로서비스 아키텍처로 전환
- **자동 스케일링**: 수요에 따른 자동 리소스 조정
- **리전 최적화**: 비용이 낮은 리전으로 리소스 이동

## 🔧 실행 가능한 명령어

### 즉시 실행
\`\`\`bash
# 중지된 인스턴스 삭제
gcloud compute instances delete \$(gcloud compute instances list --filter="status=TERMINATED" --format="value(name)") --quiet

# 사용하지 않는 디스크 삭제
gcloud compute disks delete \$(gcloud compute disks list --filter="status=UNATTACHED" --format="value(name)") --quiet

# 사용하지 않는 외부 IP 해제
gcloud compute addresses delete \$(gcloud compute addresses list --filter="status=RESERVED AND users=null" --format="value(name)") --quiet
\`\`\`

### 비용 모니터링 설정
\`\`\`bash
# 예산 알림 설정
gcloud billing budgets create --billing-account=\$(gcloud billing accounts list --format="value(name)" | head -1) --display-name="Cloud Master Day3 Budget" --budget-amount=100USD
\`\`\`

## 📈 예상 절약 효과

- **즉시 절약**: 20-30% (사용하지 않는 리소스 정리)
- **단기 절약**: 30-50% (리소스 최적화)
- **중기 절약**: 50-70% (할인 옵션 활용)
- **장기 절약**: 70-90% (아키텍처 최적화)

## ⚠️ 주의사항

1. **데이터 백업**: 삭제 전 반드시 중요한 데이터 백업
2. **의존성 확인**: 다른 리소스와의 의존성 확인
3. **테스트 환경**: 프로덕션 환경 적용 전 테스트 환경에서 검증
4. **모니터링**: 변경 후 비용 및 성능 모니터링

---
*이 리포트는 Cloud Master Day3 자동화 스크립트에 의해 생성되었습니다.*
EOF
    
    log_success "비용 최적화 권장사항 생성 완료"
}

# 비용 모니터링 설정
setup_cost_monitoring() {
    log_info "=== 비용 모니터링 설정 ==="
    
    # 예산 알림 설정 (선택사항)
    log_info "예산 알림 설정 중..."
    if gcloud billing budgets list --billing-account=$(gcloud billing accounts list --format="value(name)" | head -1) &> /dev/null; then
        log_info "예산 알림이 이미 설정되어 있습니다."
    else
        log_warning "예산 알림 설정을 위해서는 Billing API 권한이 필요합니다."
        log_info "수동으로 설정하려면:"
        log_info "gcloud billing budgets create --billing-account=\$(gcloud billing accounts list --format='value(name)' | head -1) --display-name='Cloud Master Day3 Budget' --budget-amount=100USD"
    fi
    
    # 비용 알림 스크립트 생성
    cat > "$REPORT_DIR/cost-monitoring-script.sh" << 'EOF'
#!/bin/bash
# GCP 비용 모니터링 스크립트

echo "=== GCP 비용 모니터링 ==="
echo "날짜: $(date)"
echo "프로젝트: $(gcloud config get-value project)"
echo ""

echo "1. 실행 중인 인스턴스:"
gcloud compute instances list --filter="status=RUNNING" --format="table(name,zone,machineType,status)"

echo ""
echo "2. 사용하지 않는 디스크:"
gcloud compute disks list --filter="status=UNATTACHED" --format="table(name,zone,sizeGb,type)"

echo ""
echo "3. 사용하지 않는 외부 IP:"
gcloud compute addresses list --filter="status=RESERVED AND users=null" --format="table(name,region,address)"

echo ""
echo "4. 최근 생성된 리소스 (24시간 내):"
gcloud compute instances list --filter="creationTimestamp>$(date -d '1 day ago' -u +%Y-%m-%dT%H:%M:%S)" --format="table(name,zone,status,creationTimestamp)"
EOF
    
    chmod +x "$REPORT_DIR/cost-monitoring-script.sh"
    
    log_success "비용 모니터링 설정 완료"
}

# 시스템 테스트
test_system() {
    log_info "=== 시스템 테스트 ==="
    
    # 리포트 파일 확인
    log_info "리포트 파일 확인 중..."
    if [ -f "$REPORT_DIR/recommendations/cost-optimization-report.md" ]; then
        log_success "비용 최적화 리포트 생성 완료"
    else
        log_warning "비용 최적화 리포트가 생성되지 않았습니다."
    fi
    
    # 모니터링 스크립트 테스트
    if [ -f "$REPORT_DIR/cost-monitoring-script.sh" ]; then
        log_info "비용 모니터링 스크립트 테스트 중..."
        if bash "$REPORT_DIR/cost-monitoring-script.sh" &> /dev/null; then
            log_success "비용 모니터링 스크립트 정상 작동"
        else
            log_warning "비용 모니터링 스크립트 실행 실패"
        fi
    fi
    
    log_success "시스템 테스트 완료"
}

# 리소스 정리
cleanup() {
    log_info "=== 리소스 정리 ==="
    
    # 리포트 디렉토리 정리
    if [ -d "$REPORT_DIR" ]; then
        log_info "리포트 디렉토리 정리 중..."
        rm -rf "$REPORT_DIR"
    fi
    
    log_success "리소스 정리 완료"
}

# 메인 함수
main() {
    case "${1:-analyze}" in
        "analyze")
            check_prerequisites
            setup_environment
            create_report_directories
            analyze_instances
            analyze_disks
            analyze_networking
            generate_recommendations
            setup_cost_monitoring
            test_system
            
            log_success "GCP 비용 최적화 분석 완료!"
            log_info "리포트 위치: $REPORT_DIR"
            log_info "주요 리포트:"
            log_info "  - 비용 최적화 리포트: $REPORT_DIR/recommendations/cost-optimization-report.md"
            log_info "  - 모니터링 스크립트: $REPORT_DIR/cost-monitoring-script.sh"
            ;;
        "optimize")
            log_info "비용 최적화 실행 중..."
            # 실제 최적화 실행은 사용자가 수동으로 수행
            log_warning "자동 최적화는 위험할 수 있습니다. 리포트를 확인 후 수동으로 실행하세요."
            ;;
        "monitor")
            log_info "비용 모니터링 설정 중..."
            setup_cost_monitoring
            ;;
        "report")
            log_info "리포트 생성 중..."
            generate_recommendations
            ;;
        "cleanup")
            cleanup
            ;;
        *)
            echo "사용법: $0 [analyze|optimize|monitor|report|cleanup]"
            echo "  analyze  - 비용 분석 실행 (기본값)"
            echo "  optimize - 비용 최적화 실행"
            echo "  monitor  - 비용 모니터링 설정"
            echo "  report   - 리포트 생성"
            echo "  cleanup  - 리소스 정리"
            exit 1
            ;;
    esac
}

# 스크립트 실행
main "$@"
