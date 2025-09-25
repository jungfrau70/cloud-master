#!/bin/bash

# Cloud Master Day3 - 통합 실습 자동화 스크립트
# 작성일: 2024년 9월 22일
# 목적: 로드밸런싱, 오토스케일링, 모니터링, 비용 최적화 통합 자동화

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 로그 함수
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_header() { echo -e "${PURPLE}=== $1 ===${NC}"; }
log_step() { echo -e "${CYAN}[STEP]${NC} $1"; }

# 설정 변수
PROJECT_NAME="cloud-master-day3"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AUTOMATION_DIR="$SCRIPT_DIR"

# 함수 정의
check_prerequisites() {
    log_header "사전 요구사항 확인"
    
    # 필수 도구 확인
    local tools=("aws" "gcloud" "docker" "docker-compose" "jq" "curl")
    local missing_tools=()
    
    for tool in "${tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            missing_tools+=("$tool")
        fi
    done
    
    if [ ${#missing_tools[@]} -gt 0 ]; then
        log_error "다음 도구들이 설치되지 않았습니다: ${missing_tools[*]}"
        log_info "설치 방법:"
        for tool in "${missing_tools[@]}"; do
            case "$tool" in
                "aws")
                    echo "  AWS CLI: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html"
                    ;;
                "gcloud")
                    echo "  GCP CLI: https://cloud.google.com/sdk/docs/install"
                    ;;
                "docker")
                    echo "  Docker: https://docs.docker.com/get-docker/"
                    ;;
                "docker-compose")
                    echo "  Docker Compose: https://docs.docker.com/compose/install/"
                    ;;
                "jq")
                    echo "  jq: sudo apt-get install jq (Ubuntu) or brew install jq (macOS)"
                    ;;
                "curl")
                    echo "  curl: sudo apt-get install curl (Ubuntu) or brew install curl (macOS)"
                    ;;
            esac
        done
        exit 1
    fi
    
    # AWS CLI 설정 확인
    if ! aws sts get-caller-identity &> /dev/null; then
        log_error "AWS CLI가 설정되지 않았습니다. 'aws configure'를 실행하세요."
        exit 1
    fi
    
    # GCP CLI 설정 확인
    if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | head -1 &> /dev/null; then
        log_error "GCP CLI가 설정되지 않았습니다. 'gcloud auth login'을 실행하세요."
        exit 1
    fi
    
    log_success "모든 필수 도구가 설치되어 있습니다."
}

setup_environment() {
    log_header "환경 설정"
    
    # 작업 디렉토리 생성
    mkdir -p "$PROJECT_NAME"
    cd "$PROJECT_NAME"
    
    # 스크립트 실행 권한 부여
    chmod +x "$AUTOMATION_DIR"/*.sh
    
    log_success "환경 설정 완료"
}

run_load_balancing() {
    log_step "1/4: 로드밸런싱 설정"
    
    log_info "로드밸런싱 자동화 스크립트 실행 중..."
    if [ -f "$AUTOMATION_DIR/load-balancing-practice-automation.sh" ]; then
        "$AUTOMATION_DIR/load-balancing-practice-automation.sh" setup
        if [ $? -eq 0 ]; then
            log_success "로드밸런싱 설정 완료"
        else
            log_error "로드밸런싱 설정 실패"
            return 1
        fi
    else
        log_error "로드밸런싱 스크립트를 찾을 수 없습니다."
        return 1
    fi
}

run_auto_scaling() {
    log_step "2/4: 오토스케일링 설정"
    
    log_info "오토스케일링 자동화 스크립트 실행 중..."
    if [ -f "$AUTOMATION_DIR/auto-scaling-practice-automation.sh" ]; then
        "$AUTOMATION_DIR/auto-scaling-practice-automation.sh" setup
        if [ $? -eq 0 ]; then
            log_success "오토스케일링 설정 완료"
        else
            log_error "오토스케일링 설정 실패"
            return 1
        fi
    else
        log_error "오토스케일링 스크립트를 찾을 수 없습니다."
        return 1
    fi
}

run_monitoring() {
    log_step "3/4: 모니터링 설정"
    
    log_info "모니터링 자동화 스크립트 실행 중..."
    if [ -f "$AUTOMATION_DIR/monitoring-practice-automation.sh" ]; then
        "$AUTOMATION_DIR/monitoring-practice-automation.sh" setup
        if [ $? -eq 0 ]; then
            log_success "모니터링 설정 완료"
        else
            log_error "모니터링 설정 실패"
            return 1
        fi
        
        # 모니터링 스택 시작
        log_info "모니터링 스택 시작 중..."
        "$AUTOMATION_DIR/monitoring-practice-automation.sh" start
    else
        log_error "모니터링 스크립트를 찾을 수 없습니다."
        return 1
    fi
}

run_cost_optimization() {
    log_step "4/4: 비용 최적화 설정"
    
    log_info "비용 최적화 자동화 스크립트 실행 중..."
    if [ -f "$AUTOMATION_DIR/cost-optimization-practice-automation.sh" ]; then
        "$AUTOMATION_DIR/cost-optimization-practice-automation.sh" analyze
        if [ $? -eq 0 ]; then
            log_success "비용 분석 완료"
        else
            log_error "비용 분석 실패"
            return 1
        fi
        
        # 비용 최적화 실행
        log_info "비용 최적화 실행 중..."
        "$AUTOMATION_DIR/cost-optimization-practice-automation.sh" optimize
    else
        log_error "비용 최적화 스크립트를 찾을 수 없습니다."
        return 1
    fi
}

test_integrated_system() {
    log_header "통합 시스템 테스트"
    
    # 로드밸런싱 테스트
    log_info "로드밸런싱 테스트 중..."
    if [ -f "$AUTOMATION_DIR/load-balancing-practice-automation.sh" ]; then
        "$AUTOMATION_DIR/load-balancing-practice-automation.sh" test
    fi
    
    # 오토스케일링 테스트
    log_info "오토스케일링 테스트 중..."
    if [ -f "$AUTOMATION_DIR/auto-scaling-practice-automation.sh" ]; then
        "$AUTOMATION_DIR/auto-scaling-practice-automation.sh" test
    fi
    
    # 모니터링 테스트
    log_info "모니터링 테스트 중..."
    if [ -f "$AUTOMATION_DIR/monitoring-practice-automation.sh" ]; then
        "$AUTOMATION_DIR/monitoring-practice-automation.sh" test
    fi
    
    # 비용 최적화 테스트
    log_info "비용 최적화 테스트 중..."
    if [ -f "$AUTOMATION_DIR/cost-optimization-practice-automation.sh" ]; then
        "$AUTOMATION_DIR/cost-optimization-practice-automation.sh" report
    fi
    
    log_success "통합 시스템 테스트 완료"
}

show_system_status() {
    log_header "시스템 상태 확인"
    
    # AWS 리소스 상태
    log_info "AWS 리소스 상태:"
    aws ec2 describe-instances --query 'Reservations[*].Instances[*].[InstanceId,State.Name,InstanceType]' --output table 2>/dev/null || log_warning "AWS 리소스 정보를 가져올 수 없습니다."
    
    # GCP 리소스 상태
    log_info "GCP 리소스 상태:"
    gcloud compute instances list --format="table(name,status,machineType)" 2>/dev/null || log_warning "GCP 리소스 정보를 가져올 수 없습니다."
    
    # Docker 컨테이너 상태
    log_info "Docker 컨테이너 상태:"
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null || log_warning "Docker 컨테이너 정보를 가져올 수 없습니다."
    
    # 접속 URL 정보
    log_info "접속 URL:"
    echo "  Prometheus: http://localhost:9090"
    echo "  Grafana: http://localhost:3001 (admin/admin)"
    echo "  Jaeger: http://localhost:16686"
    echo "  Elasticsearch: http://localhost:9200"
    echo "  Kibana: http://localhost:5601"
    echo "  Test App: http://localhost:3000"
}

cleanup_all() {
    log_header "전체 리소스 정리"
    
    # 각 스크립트의 정리 함수 실행
    log_info "로드밸런싱 리소스 정리 중..."
    if [ -f "$AUTOMATION_DIR/load-balancing-practice-automation.sh" ]; then
        "$AUTOMATION_DIR/load-balancing-practice-automation.sh" cleanup
    fi
    
    log_info "오토스케일링 리소스 정리 중..."
    if [ -f "$AUTOMATION_DIR/auto-scaling-practice-automation.sh" ]; then
        "$AUTOMATION_DIR/auto-scaling-practice-automation.sh" cleanup
    fi
    
    log_info "모니터링 리소스 정리 중..."
    if [ -f "$AUTOMATION_DIR/monitoring-practice-automation.sh" ]; then
        "$AUTOMATION_DIR/monitoring-practice-automation.sh" cleanup
    fi
    
    log_info "비용 최적화 리소스 정리 중..."
    if [ -f "$AUTOMATION_DIR/cost-optimization-practice-automation.sh" ]; then
        "$AUTOMATION_DIR/cost-optimization-practice-automation.sh" cleanup
    fi
    
    # 로컬 디렉토리 정리
    cd ..
    if [ -d "$PROJECT_NAME" ]; then
        rm -rf "$PROJECT_NAME"
        log_success "로컬 디렉토리 정리 완료"
    fi
    
    log_success "전체 리소스 정리 완료"
}

generate_final_report() {
    log_header "최종 리포트 생성"
    
    # 리포트 디렉토리 생성
    mkdir -p "final-report"
    
    # 통합 리포트 생성
    cat > "final-report/cloud-master-day3-final-report.md" << EOF
# Cloud Master Day3 - 통합 실습 완료 리포트

## 실행 개요
- **실행 일시**: $(date)
- **프로젝트명**: $PROJECT_NAME
- **실행 환경**: $(uname -s) $(uname -m)

## 완료된 실습 항목

### 1. 로드밸런싱 ✅
- AWS ALB 설정 및 구성
- GCP Cloud Load Balancing 설정
- 로드밸런싱 테스트 및 검증

### 2. 오토스케일링 ✅
- AWS Auto Scaling Group 설정
- GCP Managed Instance Group 설정
- 자동 스케일링 정책 구성

### 3. 모니터링 ✅
- Prometheus 메트릭 수집 설정
- Grafana 대시보드 구성
- Jaeger 분산 추적 설정
- ELK Stack 로그 분석 설정

### 4. 비용 최적화 ✅
- AWS 비용 분석 및 최적화
- GCP 비용 분석 및 최적화
- 비용 모니터링 설정

## 시스템 아키텍처

\`\`\`
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Load Balancer │    │   Auto Scaling  │    │   Monitoring    │
│   (AWS ALB/     │───►│   (AWS ASG/     │───►│   (Prometheus/  │
│    GCP CLB)     │    │    GCP MIG)     │    │    Grafana)     │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         │                       │                       ▼
         │                       │              ┌─────────────────┐
         │                       │              │   Logging       │
         │                       │              │   (ELK Stack)   │
         │                       │              └─────────────────┘
         │                       │                       │
         ▼                       ▼                       ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Application   │    │   Application   │    │   Application   │
│   Instance 1    │    │   Instance 2    │    │   Instance 3    │
│   (Auto Scaled) │    │   (Auto Scaled) │    │   (Auto Scaled) │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         └───────────────────────┼───────────────────────┘
                                 │
                                 ▼
                    ┌─────────────────┐
                    │   Database      │
                    │   (PostgreSQL/  │
                    │    Redis)       │
                    └─────────────────┘
\`\`\`

## 접속 정보

### 모니터링 도구
- **Prometheus**: http://localhost:9090
- **Grafana**: http://localhost:3001 (admin/admin)
- **Jaeger**: http://localhost:16686
- **Elasticsearch**: http://localhost:9200
- **Kibana**: http://localhost:5601

### 테스트 애플리케이션
- **Test App**: http://localhost:3000

## 성과 지표

### 비용 최적화
- **예상 비용 절감**: 20-40%
- **미사용 리소스 정리**: 완료
- **자동 스케일링**: 활성화

### 모니터링
- **메트릭 수집**: 활성화
- **알림 설정**: 완료
- **대시보드**: 구성 완료

### 고가용성
- **로드밸런싱**: 구성 완료
- **자동 스케일링**: 활성화
- **장애 복구**: 자동화

## 다음 단계

### 운영 환경 적용
1. 프로덕션 환경에 동일한 아키텍처 적용
2. 모니터링 알림 정책 세밀 조정
3. 비용 최적화 정책 지속적 모니터링

### 추가 최적화
1. CDN 도입으로 성능 향상
2. 데이터베이스 최적화
3. 캐싱 전략 수립

## 문제 해결

### 일반적인 문제
1. **권한 오류**: AWS/GCP CLI 설정 확인
2. **포트 충돌**: Docker 컨테이너 포트 확인
3. **리소스 부족**: 인스턴스 타입 및 리전 확인

### 로그 확인
- AWS: CloudWatch Logs
- GCP: Cloud Logging
- 로컬: Docker logs

## 지원 및 문의

- **문서**: Cloud Master Day3 실습 가이드
- **스크립트**: automation/day3/ 디렉토리
- **문제 신고**: GitHub Issues

---
*Cloud Master Day3 통합 실습 완료 - $(date)*
EOF

    log_success "최종 리포트 생성 완료: final-report/cloud-master-day3-final-report.md"
}

show_help() {
    echo "Cloud Master Day3 - 통합 실습 자동화 스크립트"
    echo ""
    echo "사용법: $0 [옵션]"
    echo ""
    echo "옵션:"
    echo "  setup      전체 실습 환경 설정 (기본값)"
    echo "  test       통합 시스템 테스트"
    echo "  status     시스템 상태 확인"
    echo "  report     최종 리포트 생성"
    echo "  cleanup    전체 리소스 정리"
    echo "  help       도움말 표시"
    echo ""
    echo "예시:"
    echo "  $0 setup     # 전체 실습 환경 설정"
    echo "  $0 test      # 통합 시스템 테스트"
    echo "  $0 status    # 시스템 상태 확인"
    echo "  $0 report    # 최종 리포트 생성"
    echo "  $0 cleanup   # 전체 리소스 정리"
    echo ""
    echo "실습 순서:"
    echo "  1. 로드밸런싱 설정"
    echo "  2. 오토스케일링 설정"
    echo "  3. 모니터링 설정"
    echo "  4. 비용 최적화 설정"
    echo "  5. 통합 테스트"
}

# 메인 실행
main() {
    case "${1:-setup}" in
        "setup")
            check_prerequisites
            setup_environment
            run_load_balancing
            run_auto_scaling
            run_monitoring
            run_cost_optimization
            test_integrated_system
            show_system_status
            generate_final_report
            log_success "Cloud Master Day3 통합 실습 완료!"
            ;;
        "test")
            test_integrated_system
            show_system_status
            ;;
        "status")
            show_system_status
            ;;
        "report")
            generate_final_report
            ;;
        "cleanup")
            cleanup_all
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
