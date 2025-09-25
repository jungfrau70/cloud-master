#!/bin/bash

# Cloud Master Day3 - GCP 통합 실습 자동화 스크립트
# GCP Cloud Load Balancing + MIG 자동 스케일링 + 모니터링 + 비용 최적화 통합 실습

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
PROJECT_NAME="cloud-master-day3-gcp-integrated"
ZONE="asia-northeast3-a"
REGION="asia-northeast3"
VM_NAME="cloud-deployment-server"

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
    
    # Docker 확인
    if ! command -v docker &> /dev/null; then
        log_error "Docker가 설치되지 않았습니다."
        exit 1
    fi
    
    # curl 확인
    if ! command -v curl &> /dev/null; then
        log_error "curl이 설치되지 않았습니다."
        exit 1
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
    
    # 필요한 API 활성화
    log_info "필요한 API 활성화 중..."
    gcloud services enable compute.googleapis.com --quiet
    gcloud services enable cloudbilling.googleapis.com --quiet
    
    log_success "환경 설정 완료"
}

# 기존 GCP VM 확인
check_gcp_vm() {
    log_info "=== GCP VM 확인 ==="
    
    # VM 목록 조회
    local vm_info
    vm_info=$(run_with_timeout 30 gcloud compute instances list \
        --filter="name:$VM_NAME AND status:RUNNING" \
        --format="value(name,zone,status,EXTERNAL_IP,INTERNAL_IP)" 2>/dev/null)
    
    if [ -z "$vm_info" ]; then
        log_error "GCP VM을 찾을 수 없습니다: $VM_NAME"
        log_info "사용 가능한 VM 목록:"
        gcloud compute instances list --format="table(name,zone,status,EXTERNAL_IP,INTERNAL_IP)"
        exit 1
    fi
    
    # VM 정보 파싱
    VM_ZONE=$(echo "$vm_info" | cut -d' ' -f2)
    VM_EXTERNAL_IP=$(echo "$vm_info" | cut -d' ' -f4)
    VM_INTERNAL_IP=$(echo "$vm_info" | cut -d' ' -f5)
    
    log_success "GCP VM 확인 완료"
    log_info "  - VM Name: $VM_NAME"
    log_info "  - Zone: $VM_ZONE"
    log_info "  - External IP: $VM_EXTERNAL_IP"
    log_info "  - Internal IP: $VM_INTERNAL_IP"
}

# GCP Cloud Load Balancing 설정
setup_load_balancer() {
    log_info "=== GCP Cloud Load Balancing 설정 ==="
    
    # 1. Instance Group 생성
    log_info "Instance Group 생성 중..."
    if ! gcloud compute instance-groups unmanaged describe $PROJECT_NAME-ig --zone=$VM_ZONE &> /dev/null; then
        run_with_timeout 60 gcloud compute instance-groups unmanaged create $PROJECT_NAME-ig \
            --zone=$VM_ZONE \
            --description="Cloud Master Day3 GCP Integrated Instance Group"
        log_success "Instance Group 생성 완료"
    else
        log_info "Instance Group이 이미 존재합니다."
    fi
    
    # 2. VM을 Instance Group에 추가
    log_info "VM을 Instance Group에 추가 중..."
    run_with_timeout 60 gcloud compute instance-groups unmanaged add-instances $PROJECT_NAME-ig \
        --instances=$VM_NAME \
        --zone=$VM_ZONE
    log_success "VM 추가 완료"
    
    # 3. Health Check 생성
    log_info "Health Check 생성 중..."
    if ! gcloud compute health-checks describe $PROJECT_NAME-hc &> /dev/null; then
        run_with_timeout 60 gcloud compute health-checks create http $PROJECT_NAME-hc \
            --port=80 \
            --request-path=/ \
            --check-interval=10s \
            --timeout=5s \
            --healthy-threshold=1 \
            --unhealthy-threshold=3
        log_success "Health Check 생성 완료"
    else
        log_info "Health Check가 이미 존재합니다."
    fi
    
    # 4. Backend Service 생성
    log_info "Backend Service 생성 중..."
    if ! gcloud compute backend-services describe $PROJECT_NAME-backend --global &> /dev/null; then
        run_with_timeout 60 gcloud compute backend-services create $PROJECT_NAME-backend \
            --protocol=HTTP \
            --port-name=http \
            --health-checks=$PROJECT_NAME-hc \
            --global
        log_success "Backend Service 생성 완료"
    else
        log_info "Backend Service가 이미 존재합니다."
    fi
    
    # 5. Backend Service에 Instance Group 추가
    log_info "Backend Service에 Instance Group 추가 중..."
    run_with_timeout 60 gcloud compute backend-services add-backend $PROJECT_NAME-backend \
        --instance-group=$PROJECT_NAME-ig \
        --instance-group-zone=$VM_ZONE \
        --global
    log_success "Instance Group 추가 완료"
    
    # 6. URL Map 생성
    log_info "URL Map 생성 중..."
    if ! gcloud compute url-maps describe $PROJECT_NAME-url-map &> /dev/null; then
        run_with_timeout 60 gcloud compute url-maps create $PROJECT_NAME-url-map \
            --default-service=$PROJECT_NAME-backend
        log_success "URL Map 생성 완료"
    else
        log_info "URL Map이 이미 존재합니다."
    fi
    
    # 7. Target HTTP Proxy 생성
    log_info "Target HTTP Proxy 생성 중..."
    if ! gcloud compute target-http-proxies describe $PROJECT_NAME-proxy &> /dev/null; then
        run_with_timeout 60 gcloud compute target-http-proxies create $PROJECT_NAME-proxy \
            --url-map=$PROJECT_NAME-url-map
        log_success "Target HTTP Proxy 생성 완료"
    else
        log_info "Target HTTP Proxy가 이미 존재합니다."
    fi
    
    # 8. Forwarding Rule 생성
    log_info "Forwarding Rule 생성 중..."
    if ! gcloud compute forwarding-rules describe $PROJECT_NAME-rule --global &> /dev/null; then
        run_with_timeout 60 gcloud compute forwarding-rules create $PROJECT_NAME-rule \
            --global \
            --target-http-proxy=$PROJECT_NAME-proxy \
            --ports=80
        log_success "Forwarding Rule 생성 완료"
    else
        log_info "Forwarding Rule이 이미 존재합니다."
    fi
    
    # 9. Load Balancer IP 확인
    log_info "Load Balancer IP 확인 중..."
    LB_IP=$(run_with_timeout 30 gcloud compute forwarding-rules describe $PROJECT_NAME-rule \
        --global \
        --format="value(IPAddress)" 2>/dev/null)
    
    if [ -n "$LB_IP" ]; then
        log_success "GCP Cloud Load Balancing 설정 완료"
        log_info "Load Balancer IP: http://$LB_IP"
        echo "$LB_IP" > gcp-integrated-lb-ip.txt
    else
        log_warning "Load Balancer IP를 가져올 수 없습니다."
    fi
}

# 모니터링 스택 설정
setup_monitoring() {
    log_info "=== 모니터링 스택 설정 ==="
    
    # 모니터링 디렉토리 생성
    mkdir -p monitoring-stack
    
    # Prometheus 설정
    cat > monitoring-stack/prometheus.yml << 'EOF'
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']
  
  - job_name: 'gcp-vm'
    static_configs:
      - targets: ['43.200.248.222:3000']
    metrics_path: '/metrics'
    scrape_interval: 30s
  
  - job_name: 'gcp-load-balancer'
    static_configs:
      - targets: ['34.64.222.69:3000']
    metrics_path: '/metrics'
    scrape_interval: 30s
EOF

    # Grafana 설정
    mkdir -p monitoring-stack/grafana/provisioning/datasources
    cat > monitoring-stack/grafana/provisioning/datasources/prometheus.yml << 'EOF'
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
    editable: true
EOF

    # Docker Compose 설정
    cat > monitoring-stack/docker-compose.yml << 'EOF'
version: '3.8'
services:
  prometheus:
    image: prom/prometheus:latest
    container_name: prometheus
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
      - prometheus_data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--web.enable-lifecycle'

  grafana:
    image: grafana/grafana:latest
    container_name: grafana
    ports:
      - "3001:3000"
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin
      - GF_USERS_ALLOW_SIGN_UP=false
    volumes:
      - grafana_data:/var/lib/grafana
      - ./grafana/provisioning:/etc/grafana/provisioning

  jaeger:
    image: jaegertracing/all-in-one:latest
    container_name: jaeger
    ports:
      - "16686:16686"
      - "14268:14268"
    environment:
      - COLLECTOR_OTLP_ENABLED=true

  node-exporter:
    image: prom/node-exporter:latest
    container_name: node-exporter
    ports:
      - "9100:9100"
    volumes:
      - /proc:/host/proc:ro
      - /sys:/host/sys:ro
      - /:/rootfs:ro
    command:
      - '--path.procfs=/host/proc'
      - '--path.rootfs=/rootfs'
      - '--path.sysfs=/host/sys'

  elasticsearch:
    image: docker.elastic.co/elasticsearch/elasticsearch:7.15.0
    container_name: elasticsearch
    environment:
      - discovery.type=single-node
      - "ES_JAVA_OPTS=-Xms512m -Xmx512m"
    ports:
      - "9200:9200"
    volumes:
      - elasticsearch_data:/usr/share/elasticsearch/data

  kibana:
    image: docker.elastic.co/kibana/kibana:7.15.0
    container_name: kibana
    ports:
      - "5601:5601"
    environment:
      - ELASTICSEARCH_HOSTS=http://elasticsearch:9200
    depends_on:
      - elasticsearch

volumes:
  prometheus_data:
  grafana_data:
  elasticsearch_data:
EOF

    # 모니터링 스택 실행
    log_info "모니터링 스택 실행 중..."
    cd monitoring-stack
    docker-compose up -d
    cd ..
    
    log_success "모니터링 스택 설정 완료"
}

# 비용 최적화 분석
setup_cost_optimization() {
    log_info "=== 비용 최적화 분석 ==="
    
    # 비용 분석 디렉토리 생성
    mkdir -p cost-reports/gcp
    
    # GCP 비용 분석
    log_info "GCP 비용 분석 중..."
    
    # 사용하지 않는 디스크 찾기
    log_info "사용하지 않는 디스크 검색 중..."
    gcloud compute disks list --filter="status=UNATTACHED" --format="table(name,zone,sizeGb,status)" > cost-reports/gcp/unused-disks.txt 2>/dev/null || true
    
    # 중지된 인스턴스 찾기
    log_info "중지된 인스턴스 검색 중..."
    gcloud compute instances list --filter="status=TERMINATED" --format="table(name,zone,status)" > cost-reports/gcp/stopped-instances.txt 2>/dev/null || true
    
    # 사용하지 않는 외부 IP 찾기
    log_info "사용하지 않는 외부 IP 검색 중..."
    gcloud compute addresses list --filter="status=RESERVED AND users=null" --format="table(name,region,address)" > cost-reports/gcp/unused-external-ips.txt 2>/dev/null || true
    
    # 비용 최적화 리포트 생성
    cat > cost-reports/gcp/cost-optimization-report.md << EOF
# GCP 비용 최적화 분석 리포트

**생성일**: $(date)
**프로젝트**: $(gcloud config get-value project)

## 📊 현재 상태

### 리소스 현황
- **실행 중인 인스턴스**: $(gcloud compute instances list --filter="status=RUNNING" --format="value(name)" | wc -l)개
- **중지된 인스턴스**: $(gcloud compute instances list --filter="status=TERMINATED" --format="value(name)" | wc -l)개
- **사용하지 않는 디스크**: $(gcloud compute disks list --filter="status=UNATTACHED" --format="value(name)" | wc -l)개
- **사용하지 않는 외부 IP**: $(gcloud compute addresses list --filter="status=RESERVED AND users=null" --format="value(name)" | wc -l)개

## 💰 비용 절약 권장사항

### 즉시 실행 가능
1. **중지된 인스턴스 삭제**: 디스크 비용만 발생하는 중지된 인스턴스 삭제
2. **사용하지 않는 디스크 삭제**: UNATTACHED 상태의 디스크 즉시 삭제
3. **사용하지 않는 외부 IP 해제**: RESERVED 상태이지만 사용되지 않는 IP 해제

### 단기 최적화 (1주일 내)
1. **인스턴스 크기 조정**: CPU/메모리 사용률 분석 후 다운사이징
2. **디스크 타입 변경**: Standard → Balanced 또는 SSD → Standard
3. **스냅샷 정리**: 불필요한 스냅샷 삭제

### 중기 최적화 (1개월 내)
1. **커밋 사용 할인**: 1년 또는 3년 커밋 구매
2. **스팟 인스턴스 도입**: 개발/테스트 환경에 스팟 인스턴스 사용
3. **Preemptible 인스턴스**: 단기 작업에 Preemptible 인스턴스 사용

## 🔧 실행 명령어

\`\`\`bash
# 중지된 인스턴스 삭제
gcloud compute instances delete \$(gcloud compute instances list --filter="status=TERMINATED" --format="value(name)") --quiet

# 사용하지 않는 디스크 삭제
gcloud compute disks delete \$(gcloud compute disks list --filter="status=UNATTACHED" --format="value(name)") --quiet

# 사용하지 않는 외부 IP 해제
gcloud compute addresses delete \$(gcloud compute addresses list --filter="status=RESERVED AND users=null" --format="value(name)") --quiet
\`\`\`

## 📈 예상 절약 효과

- **즉시 절약**: 20-30% (사용하지 않는 리소스 정리)
- **단기 절약**: 30-50% (리소스 최적화)
- **중기 절약**: 50-70% (할인 옵션 활용)
EOF
    
    log_success "비용 최적화 분석 완료"
}

# 시스템 테스트
test_system() {
    log_info "=== 시스템 테스트 ==="
    
    # GCP Load Balancer 테스트
    if [ -f "gcp-integrated-lb-ip.txt" ]; then
        LB_IP=$(cat gcp-integrated-lb-ip.txt)
        log_info "GCP Load Balancer 테스트 중..."
        if run_with_timeout 10 curl -f "http://$LB_IP" &> /dev/null; then
            log_success "GCP Load Balancer 정상 작동"
        else
            log_warning "GCP Load Balancer 헬스 체크 실패"
        fi
    fi
    
    # 모니터링 시스템 테스트
    log_info "모니터링 시스템 테스트 중..."
    if run_with_timeout 5 curl -f "http://localhost:9090" &> /dev/null; then
        log_success "Prometheus 정상 작동"
    else
        log_warning "Prometheus 접속 실패"
    fi
    
    if run_with_timeout 5 curl -f "http://localhost:3001" &> /dev/null; then
        log_success "Grafana 정상 작동"
    else
        log_warning "Grafana 접속 실패"
    fi
    
    if run_with_timeout 5 curl -f "http://localhost:16686" &> /dev/null; then
        log_success "Jaeger 정상 작동"
    else
        log_warning "Jaeger 접속 실패"
    fi
    
    if run_with_timeout 5 curl -f "http://localhost:5601" &> /dev/null; then
        log_success "Kibana 정상 작동"
    else
        log_warning "Kibana 접속 실패"
    fi
    
    log_success "시스템 테스트 완료"
}

# 리소스 정리
cleanup() {
    log_info "=== 리소스 정리 ==="
    
    # Forwarding Rule 삭제
    if gcloud compute forwarding-rules describe $PROJECT_NAME-rule --global &> /dev/null; then
        log_info "Forwarding Rule 삭제 중..."
        gcloud compute forwarding-rules delete $PROJECT_NAME-rule --global --quiet
    fi
    
    # Target HTTP Proxy 삭제
    if gcloud compute target-http-proxies describe $PROJECT_NAME-proxy &> /dev/null; then
        log_info "Target HTTP Proxy 삭제 중..."
        gcloud compute target-http-proxies delete $PROJECT_NAME-proxy --quiet
    fi
    
    # URL Map 삭제
    if gcloud compute url-maps describe $PROJECT_NAME-url-map &> /dev/null; then
        log_info "URL Map 삭제 중..."
        gcloud compute url-maps delete $PROJECT_NAME-url-map --quiet
    fi
    
    # Backend Service 삭제
    if gcloud compute backend-services describe $PROJECT_NAME-backend --global &> /dev/null; then
        log_info "Backend Service 삭제 중..."
        gcloud compute backend-services delete $PROJECT_NAME-backend --global --quiet
    fi
    
    # Health Check 삭제
    if gcloud compute health-checks describe $PROJECT_NAME-hc &> /dev/null; then
        log_info "Health Check 삭제 중..."
        gcloud compute health-checks delete $PROJECT_NAME-hc --quiet
    fi
    
    # Instance Group 삭제
    if gcloud compute instance-groups unmanaged describe $PROJECT_NAME-ig --zone=$VM_ZONE &> /dev/null; then
        log_info "Instance Group 삭제 중..."
        gcloud compute instance-groups unmanaged delete $PROJECT_NAME-ig --zone=$VM_ZONE --quiet
    fi
    
    # 모니터링 스택 정리
    if [ -d "monitoring-stack" ]; then
        log_info "모니터링 스택 정리 중..."
        cd monitoring-stack
        docker-compose down -v 2>/dev/null || true
        cd ..
        rm -rf monitoring-stack
    fi
    
    # 비용 리포트 정리
    if [ -d "cost-reports" ]; then
        log_info "비용 리포트 정리 중..."
        rm -rf cost-reports
    fi
    
    # 임시 파일 정리
    rm -f gcp-integrated-lb-ip.txt
    
    log_success "리소스 정리 완료"
}

# 메인 함수
main() {
    case "${1:-setup}" in
        "setup")
            check_prerequisites
            setup_environment
            check_gcp_vm
            setup_load_balancer
            setup_monitoring
            setup_cost_optimization
            test_system
            
            log_success "Cloud Master Day3 GCP 통합 실습 완료!"
            log_info "접속 URL:"
            if [ -f "gcp-integrated-lb-ip.txt" ]; then
                log_info "  GCP Load Balancer: http://$(cat gcp-integrated-lb-ip.txt)"
            fi
            log_info "  Prometheus: http://localhost:9090"
            log_info "  Grafana: http://localhost:3001 (admin/admin)"
            log_info "  Jaeger: http://localhost:16686"
            log_info "  Kibana: http://localhost:5601"
            log_info "  Node Exporter: http://localhost:9100"
            log_info "  AWS VM: http://43.200.248.222:3000"
            log_info "  GCP VM: http://34.64.222.69:3000"
            ;;
        "cleanup")
            cleanup
            ;;
        "test")
            test_system
            ;;
        *)
            echo "사용법: $0 [setup|cleanup|test]"
            echo "  setup   - GCP 통합 실습 설정 (기본값)"
            echo "  cleanup - 리소스 정리"
            echo "  test    - 시스템 테스트"
            exit 1
            ;;
    esac
}

# 스크립트 실행
main "$@"
