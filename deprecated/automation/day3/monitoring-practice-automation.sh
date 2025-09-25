#!/bin/bash

# Cloud Master Day3 - 모니터링 실습 자동화 스크립트
# 작성일: 2024년 9월 22일
# 목적: Prometheus, Grafana, Jaeger, ELK Stack 자동 설정 및 테스트

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
MONITORING_DIR="./monitoring-stack"

# 함수 정의
check_prerequisites() {
    log_header "사전 요구사항 확인"
    
    # Docker 확인
    if ! command -v docker &> /dev/null; then
        log_error "Docker가 설치되지 않았습니다."
        exit 1
    fi
    
    # Docker Compose 확인
    if ! command -v docker-compose &> /dev/null; then
        log_error "Docker Compose가 설치되지 않았습니다."
        exit 1
    fi
    
    log_success "모든 필수 도구가 설치되어 있습니다."
}

create_monitoring_directory() {
    log_header "모니터링 디렉토리 생성"
    
    mkdir -p "$MONITORING_DIR"/{prometheus,grafana,jaeger,elk}
    
    log_success "모니터링 디렉토리 생성 완료"
}

setup_prometheus() {
    log_header "Prometheus 설정"
    
    # Prometheus 설정 파일 생성
    cat > "$MONITORING_DIR/prometheus/prometheus.yml" << 'EOF'
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']
  
  - job_name: 'node-exporter'
    static_configs:
      - targets: ['node-exporter:9100']
  
  - job_name: 'application'
    static_configs:
      - targets: ['application:3000']
    metrics_path: /metrics
    scrape_interval: 5s
EOF

    log_success "Prometheus 설정 완료"
}

setup_grafana() {
    log_header "Grafana 설정"
    
    # Grafana 데이터 소스 설정
    cat > "$MONITORING_DIR/grafana/datasources.yml" << 'EOF'
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
    editable: true
EOF

    log_success "Grafana 설정 완료"
}

create_docker_compose() {
    log_header "Docker Compose 설정"
    
    cat > "$MONITORING_DIR/docker-compose.yml" << 'EOF'
version: '3.8'

services:
  # Prometheus
  prometheus:
    image: prom/prometheus:latest
    container_name: prometheus
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus/prometheus.yml:/etc/prometheus/prometheus.yml
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--web.enable-lifecycle'
    networks:
      - monitoring

  # Node Exporter
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
    networks:
      - monitoring

  # Grafana
  grafana:
    image: grafana/grafana:latest
    container_name: grafana
    ports:
      - "3001:3000"
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin
      - GF_USERS_ALLOW_SIGN_UP=false
    volumes:
      - grafana-storage:/var/lib/grafana
      - ./grafana/datasources.yml:/etc/grafana/provisioning/datasources/datasources.yml
    networks:
      - monitoring

  # Jaeger
  jaeger:
    image: jaegertracing/all-in-one:latest
    container_name: jaeger
    ports:
      - "16686:16686"
      - "14268:14268"
      - "9411:9411"
    environment:
      - COLLECTOR_ZIPKIN_HTTP_PORT=9411
    networks:
      - monitoring

  # Elasticsearch
  elasticsearch:
    image: docker.elastic.co/elasticsearch/elasticsearch:7.15.0
    container_name: elasticsearch
    ports:
      - "9200:9200"
    environment:
      - discovery.type=single-node
      - "ES_JAVA_OPTS=-Xms512m -Xmx512m"
    volumes:
      - elasticsearch-storage:/usr/share/elasticsearch/data
    networks:
      - monitoring

  # Kibana
  kibana:
    image: docker.elastic.co/kibana/kibana:7.15.0
    container_name: kibana
    ports:
      - "5601:5601"
    environment:
      - ELASTICSEARCH_HOSTS=http://elasticsearch:9200
    depends_on:
      - elasticsearch
    networks:
      - monitoring

  # Test Application
  application:
    image: nginx:alpine
    container_name: test-application
    ports:
      - "3000:80"
    volumes:
      - ./test-app:/usr/share/nginx/html
    networks:
      - monitoring

volumes:
  grafana-storage:
  elasticsearch-storage:

networks:
  monitoring:
    driver: bridge
EOF

    log_success "Docker Compose 설정 완료"
}

create_test_application() {
    log_header "테스트 애플리케이션 생성"
    
    mkdir -p "$MONITORING_DIR/test-app"
    
    # 메인 페이지 생성
    cat > "$MONITORING_DIR/test-app/index.html" << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Cloud Master Day3 - Monitoring Test</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; }
        .container { max-width: 800px; margin: 0 auto; }
        .metric { margin: 20px 0; padding: 20px; border: 1px solid #ddd; border-radius: 5px; }
        .value { font-size: 24px; font-weight: bold; color: #2c3e50; }
        .label { color: #7f8c8d; margin-bottom: 10px; }
    </style>
</head>
<body>
    <div class="container">
        <h1>Cloud Master Day3 - Monitoring Test Application</h1>
        
        <div class="metric">
            <div class="label">Request Count</div>
            <div class="value" id="request-count">0</div>
        </div>
        
        <div class="metric">
            <div class="label">Response Time (ms)</div>
            <div class="value" id="response-time">0</div>
        </div>
        
        <button onclick="generateLoad()">Generate Load</button>
        <button onclick="clearLoad()">Clear Load</button>
        
        <script>
            let requestCount = 0;
            let loadInterval = null;
            
            function updateMetrics() {
                document.getElementById('request-count').textContent = requestCount;
                document.getElementById('response-time').textContent = Math.random() * 100;
            }
            
            function generateLoad() {
                if (loadInterval) return;
                
                loadInterval = setInterval(() => {
                    fetch('/api/metrics')
                        .then(response => response.json())
                        .then(data => {
                            requestCount++;
                            updateMetrics();
                        })
                        .catch(error => console.error('Error:', error));
                }, 100);
            }
            
            function clearLoad() {
                if (loadInterval) {
                    clearInterval(loadInterval);
                    loadInterval = null;
                }
            }
            
            updateMetrics();
        </script>
    </div>
</body>
</html>
EOF

    # 메트릭 엔드포인트 생성
    cat > "$MONITORING_DIR/test-app/api/metrics" << 'EOF'
#!/bin/bash
echo "Content-Type: text/plain"
echo ""
echo "# HELP http_requests_total Total number of HTTP requests"
echo "# TYPE http_requests_total counter"
echo "http_requests_total{method=\"GET\",endpoint=\"/\"} $(($RANDOM % 1000))"
echo "http_requests_total{method=\"GET\",endpoint=\"/api/metrics\"} $(($RANDOM % 100))"
EOF

    chmod +x "$MONITORING_DIR/test-app/api/metrics"
    
    log_success "테스트 애플리케이션 생성 완료"
}

start_monitoring_stack() {
    log_header "모니터링 스택 시작"
    
    cd "$MONITORING_DIR"
    
    # Docker Compose로 스택 시작
    log_info "모니터링 스택 시작 중..."
    docker-compose up -d
    
    # 서비스 상태 확인
    log_info "서비스 상태 확인 중..."
    sleep 10
    
    # Prometheus 확인
    if curl -f -s "http://localhost:9090" > /dev/null; then
        log_success "Prometheus 시작 완료: http://localhost:9090"
    else
        log_warning "Prometheus 시작 실패"
    fi
    
    # Grafana 확인
    if curl -f -s "http://localhost:3001" > /dev/null; then
        log_success "Grafana 시작 완료: http://localhost:3001 (admin/admin)"
    else
        log_warning "Grafana 시작 실패"
    fi
    
    # Jaeger 확인
    if curl -f -s "http://localhost:16686" > /dev/null; then
        log_success "Jaeger 시작 완료: http://localhost:16686"
    else
        log_warning "Jaeger 시작 실패"
    fi
    
    # Elasticsearch 확인
    if curl -f -s "http://localhost:9200" > /dev/null; then
        log_success "Elasticsearch 시작 완료: http://localhost:9200"
    else
        log_warning "Elasticsearch 시작 실패"
    fi
    
    # Kibana 확인
    if curl -f -s "http://localhost:5601" > /dev/null; then
        log_success "Kibana 시작 완료: http://localhost:5601"
    else
        log_warning "Kibana 시작 실패"
    fi
    
    cd ..
    
    log_success "모니터링 스택 시작 완료"
}

test_monitoring() {
    log_header "모니터링 테스트"
    
    # 테스트 애플리케이션에 요청 보내기
    log_info "테스트 애플리케이션에 요청 보내기..."
    for i in {1..10}; do
        curl -s "http://localhost:3000/" > /dev/null
        curl -s "http://localhost:3000/api/metrics" > /dev/null
        sleep 1
    done
    
    log_success "모니터링 테스트 완료"
}

stop_monitoring_stack() {
    log_header "모니터링 스택 중지"
    
    cd "$MONITORING_DIR"
    
    # Docker Compose로 스택 중지
    log_info "모니터링 스택 중지 중..."
    docker-compose down
    
    cd ..
    
    log_success "모니터링 스택 중지 완료"
}

cleanup() {
    log_header "리소스 정리"
    
    # 모니터링 스택 중지
    stop_monitoring_stack
    
    # 모니터링 디렉토리 삭제
    if [ -d "$MONITORING_DIR" ]; then
        rm -rf "$MONITORING_DIR"
        log_success "모니터링 디렉토리 삭제 완료"
    fi
    
    # Docker 볼륨 정리
    docker volume prune -f
    
    log_success "모든 리소스 정리 완료"
}

show_help() {
    echo "Cloud Master Day3 - 모니터링 실습 자동화 스크립트"
    echo ""
    echo "사용법: $0 [옵션]"
    echo ""
    echo "옵션:"
    echo "  setup     모니터링 스택 설정 (기본값)"
    echo "  start     모니터링 스택 시작"
    echo "  test      모니터링 테스트"
    echo "  stop      모니터링 스택 중지"
    echo "  cleanup   리소스 정리"
    echo "  help      도움말 표시"
    echo ""
    echo "예시:"
    echo "  $0 setup    # 모니터링 스택 설정"
    echo "  $0 start    # 모니터링 스택 시작"
    echo "  $0 test     # 모니터링 테스트"
    echo "  $0 stop     # 모니터링 스택 중지"
    echo "  $0 cleanup  # 리소스 정리"
    echo ""
    echo "접속 URL:"
    echo "  Prometheus: http://localhost:9090"
    echo "  Grafana: http://localhost:3001 (admin/admin)"
    echo "  Jaeger: http://localhost:16686"
    echo "  Elasticsearch: http://localhost:9200"
    echo "  Kibana: http://localhost:5601"
    echo "  Test App: http://localhost:3000"
}

# 메인 실행
main() {
    case "${1:-setup}" in
        "setup")
            check_prerequisites
            create_monitoring_directory
            setup_prometheus
            setup_grafana
            create_docker_compose
            create_test_application
            log_success "모니터링 스택 설정 완료!"
            ;;
        "start")
            start_monitoring_stack
            ;;
        "test")
            test_monitoring
            ;;
        "stop")
            stop_monitoring_stack
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