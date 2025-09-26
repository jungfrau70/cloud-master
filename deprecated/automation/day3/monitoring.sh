#!/bin/bash
# Cloud Master Day3 - 모니터링 스택 자동화 스크립트
# 강의안 기반 업데이트: 2024년 9월 22일

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

log_info "🚀 Cloud Master Day3 - 모니터링 스택 자동화 시작"

# Prometheus 설정
log_info "📋 Prometheus 설정 파일 생성 중..."
cat > prometheus.yml << 'EOF'
global:
  scrape_interval: 15s
  evaluation_interval: 15s

rule_files:
  - "alert_rules.yml"

alerting:
  alertmanagers:
    - static_configs:
        - targets:
          - alertmanager:9093

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'node-exporter'
    static_configs:
      - targets: ['node-exporter:9100']

  - job_name: 'cadvisor'
    static_configs:
      - targets: ['cadvisor:8080']

  - job_name: 'application'
    static_configs:
      - targets: ['application:3000']
    metrics_path: /metrics
    scrape_interval: 5s

  - job_name: 'jaeger'
    static_configs:
      - targets: ['jaeger:14269']
    metrics_path: /metrics

  - job_name: 'elasticsearch'
    static_configs:
      - targets: ['elasticsearch:9200']
    metrics_path: /_prometheus/metrics
EOF

log_success "Prometheus 설정 파일 생성 완료"

# Grafana 대시보드 설정
log_info "📋 Grafana 대시보드 설정 파일 생성 중..."
cat > grafana-dashboard.json << 'EOF'
{
  "dashboard": {
    "id": null,
    "title": "Cloud Master Day3 - 모니터링 대시보드",
    "tags": ["cloud-master", "monitoring", "day3"],
    "style": "dark",
    "timezone": "browser",
    "panels": [
      {
        "id": 1,
        "title": "CPU 사용률",
        "type": "graph",
        "gridPos": {"h": 8, "w": 12, "x": 0, "y": 0},
        "targets": [
          {
            "expr": "100 - (avg by (instance) (irate(node_cpu_seconds_total{mode=\"idle\"}[5m])) * 100)",
            "legendFormat": "CPU 사용률 %",
            "refId": "A"
          }
        ],
        "yAxes": [
          {
            "label": "백분율",
            "min": 0,
            "max": 100
          }
        ],
        "thresholds": [
          {
            "value": 80,
            "colorMode": "critical",
            "op": "gt"
          }
        ]
      },
      {
        "id": 2,
        "title": "메모리 사용률",
        "type": "graph",
        "gridPos": {"h": 8, "w": 12, "x": 12, "y": 0},
        "targets": [
          {
            "expr": "100 - ((node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) * 100)",
            "legendFormat": "메모리 사용률 %",
            "refId": "A"
          }
        ],
        "yAxes": [
          {
            "label": "백분율",
            "min": 0,
            "max": 100
          }
        ],
        "thresholds": [
          {
            "value": 90,
            "colorMode": "critical",
            "op": "gt"
          }
        ]
      },
      {
        "id": 3,
        "title": "HTTP 요청 수",
        "type": "graph",
        "gridPos": {"h": 8, "w": 12, "x": 0, "y": 8},
        "targets": [
          {
            "expr": "rate(http_requests_total[5m])",
            "legendFormat": "요청/초",
            "refId": "A"
          }
        ]
      },
      {
        "id": 4,
        "title": "디스크 사용률",
        "type": "graph",
        "gridPos": {"h": 8, "w": 12, "x": 12, "y": 8},
        "targets": [
          {
            "expr": "100 - ((node_filesystem_avail_bytes / node_filesystem_size_bytes) * 100)",
            "legendFormat": "디스크 사용률 %",
            "refId": "A"
          }
        ],
        "yAxes": [
          {
            "label": "백분율",
            "min": 0,
            "max": 100
          }
        ]
      },
      {
        "id": 5,
        "title": "네트워크 트래픽",
        "type": "graph",
        "gridPos": {"h": 8, "w": 24, "x": 0, "y": 16},
        "targets": [
          {
            "expr": "rate(node_network_receive_bytes_total[5m])",
            "legendFormat": "수신 {{device}}",
            "refId": "A"
          },
          {
            "expr": "rate(node_network_transmit_bytes_total[5m])",
            "legendFormat": "송신 {{device}}",
            "refId": "B"
          }
        ]
      }
    ],
    "time": {
      "from": "now-1h",
      "to": "now"
    },
    "refresh": "5s",
    "annotations": {
      "list": [
        {
          "name": "알림",
          "enable": true,
          "iconColor": "rgba(0, 211, 255, 1)",
          "type": "dashboard"
        }
      ]
    }
  }
}
EOF

log_success "Grafana 대시보드 설정 파일 생성 완료"

# Docker Compose 모니터링 스택 설정
log_info "📋 Docker Compose 모니터링 스택 설정 파일 생성 중..."
cat > docker-compose.monitoring.yml << 'EOF'
version: '3.8'
services:
  prometheus:
    image: prom/prometheus:latest
    container_name: prometheus
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
      - ./alert_rules.yml:/etc/prometheus/alert_rules.yml
      - prometheus_data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--web.console.libraries=/etc/prometheus/console_libraries'
      - '--web.console.templates=/etc/prometheus/consoles'
      - '--storage.tsdb.retention.time=200h'
      - '--web.enable-lifecycle'
      - '--web.enable-admin-api'
    networks:
      - monitoring

  grafana:
    image: grafana/grafana:latest
    container_name: grafana
    ports:
      - "3001:3000"
    volumes:
      - grafana_data:/var/lib/grafana
      - ./grafana-dashboard.json:/var/lib/grafana/dashboards/cloud-master-dashboard.json
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin
      - GF_USERS_ALLOW_SIGN_UP=false
      - GF_INSTALL_PLUGINS=grafana-piechart-panel
    networks:
      - monitoring
    depends_on:
      - prometheus

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
      - '--collector.filesystem.mount-points-exclude=^/(sys|proc|dev|host|etc)($$|/)'
    networks:
      - monitoring

  cadvisor:
    image: gcr.io/cadvisor/cadvisor:latest
    container_name: cadvisor
    ports:
      - "8080:8080"
    volumes:
      - /:/rootfs:ro
      - /var/run:/var/run:ro
      - /sys:/sys:ro
      - /var/lib/docker/:/var/lib/docker:ro
      - /dev/disk/:/dev/disk:ro
    privileged: true
    devices:
      - /dev/kmsg
    networks:
      - monitoring

  jaeger:
    image: jaegertracing/all-in-one:latest
    container_name: jaeger
    ports:
      - "16686:16686"
      - "14268:14268"
    environment:
      - COLLECTOR_OTLP_ENABLED=true
    networks:
      - monitoring

  alertmanager:
    image: prom/alertmanager:latest
    container_name: alertmanager
    ports:
      - "9093:9093"
    volumes:
      - ./alertmanager.yml:/etc/alertmanager/alertmanager.yml
      - alertmanager_data:/alertmanager
    networks:
      - monitoring

  elasticsearch:
    image: docker.elastic.co/elasticsearch/elasticsearch:7.15.0
    container_name: elasticsearch
    environment:
      - discovery.type=single-node
      - "ES_JAVA_OPTS=-Xms512m -Xmx512m"
      - xpack.security.enabled=false
    ports:
      - "9200:9200"
    volumes:
      - elasticsearch_data:/usr/share/elasticsearch/data
    networks:
      - monitoring

  logstash:
    image: docker.elastic.co/logstash/logstash:7.15.0
    container_name: logstash
    ports:
      - "5044:5044"
    volumes:
      - ./logstash.conf:/usr/share/logstash/pipeline/logstash.conf
    networks:
      - monitoring
    depends_on:
      - elasticsearch

  kibana:
    image: docker.elastic.co/kibana/kibana:7.15.0
    container_name: kibana
    ports:
      - "5601:5601"
    environment:
      - ELASTICSEARCH_HOSTS=http://elasticsearch:9200
    networks:
      - monitoring
    depends_on:
      - elasticsearch

volumes:
  prometheus_data:
  grafana_data:
  alertmanager_data:
  elasticsearch_data:

networks:
  monitoring:
    driver: bridge
EOF

log_success "Docker Compose 모니터링 스택 설정 파일 생성 완료"

# Alert Manager 설정
log_info "📋 Alert Manager 설정 파일 생성 중..."
cat > alertmanager.yml << 'EOF'
global:
  smtp_smarthost: 'localhost:587'
  smtp_from: 'alerts@cloud-master.local'
  smtp_auth_username: 'alerts@cloud-master.local'
  smtp_auth_password: 'password'

route:
  group_by: ['alertname', 'cluster', 'service']
  group_wait: 10s
  group_interval: 10s
  repeat_interval: 1h
  receiver: 'web.hook'
  routes:
  - match:
      severity: critical
    receiver: 'critical-alerts'
  - match:
      severity: warning
    receiver: 'warning-alerts'

receivers:
- name: 'web.hook'
  webhook_configs:
  - url: 'http://127.0.0.1:5001/'
    send_resolved: true

- name: 'critical-alerts'
  webhook_configs:
  - url: 'http://127.0.0.1:5001/critical'
    send_resolved: true

- name: 'warning-alerts'
  webhook_configs:
  - url: 'http://127.0.0.1:5001/warning'
    send_resolved: true

inhibit_rules:
  - source_match:
      severity: 'critical'
    target_match:
      severity: 'warning'
    equal: ['alertname', 'cluster', 'service']
EOF

log_success "Alert Manager 설정 파일 생성 완료"

# Alert Rules 설정
log_info "📋 Alert Rules 설정 파일 생성 중..."
cat > alert_rules.yml << 'EOF'
groups:
- name: cloud-master-app
  rules:
  - alert: HighErrorRate
    expr: rate(http_requests_total{status=~"5.."}[5m]) > 0.1
    for: 5m
    labels:
      severity: critical
      service: web
    annotations:
      summary: "높은 에러율 감지"
      description: "에러율이 {{ $value }} errors/sec로 높습니다"

  - alert: HighCPUUsage
    expr: 100 - (avg by (instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 80
    for: 5m
    labels:
      severity: warning
      service: system
    annotations:
      summary: "높은 CPU 사용률 감지"
      description: "CPU 사용률이 {{ $value }}%입니다"

  - alert: HighMemoryUsage
    expr: 100 - ((node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) * 100) > 90
    for: 5m
    labels:
      severity: warning
      service: system
    annotations:
      summary: "높은 메모리 사용률 감지"
      description: "메모리 사용률이 {{ $value }}%입니다"

  - alert: DiskSpaceLow
    expr: 100 - ((node_filesystem_avail_bytes / node_filesystem_size_bytes) * 100) > 85
    for: 5m
    labels:
      severity: critical
      service: system
    annotations:
      summary: "디스크 공간 부족"
      description: "디스크 사용률이 {{ $value }}%입니다"

  - alert: ServiceDown
    expr: up == 0
    for: 1m
    labels:
      severity: critical
      service: application
    annotations:
      summary: "서비스 다운"
      description: "{{ $labels.job }} 서비스가 다운되었습니다"

  - alert: HighResponseTime
    expr: histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m])) > 1
    for: 5m
    labels:
      severity: warning
      service: web
    annotations:
      summary: "높은 응답 시간"
      description: "95% 응답 시간이 {{ $value }}초입니다"
EOF

log_success "Alert Rules 설정 파일 생성 완료"

# ELK Stack 설정
log_info "📋 ELK Stack 설정 파일 생성 중..."
cat > docker-compose.logging.yml << 'EOF'
version: '3.8'
services:
  elasticsearch:
    image: docker.elastic.co/elasticsearch/elasticsearch:8.8.0
    container_name: elasticsearch
    environment:
      - discovery.type=single-node
      - xpack.security.enabled=false
      - "ES_JAVA_OPTS=-Xms512m -Xmx512m"
    ports:
      - "9200:9200"
    volumes:
      - elasticsearch_data:/usr/share/elasticsearch/data
    networks:
      - logging
    healthcheck:
      test: ["CMD-SHELL", "curl -f http://localhost:9200/_cluster/health || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 3

  logstash:
    image: docker.elastic.co/logstash/logstash:8.8.0
    container_name: logstash
    ports:
      - "5044:5044"
      - "5000:5000"
    volumes:
      - ./logstash.conf:/usr/share/logstash/pipeline/logstash.conf
      - logstash_data:/usr/share/logstash/data
    networks:
      - logging
    depends_on:
      elasticsearch:
        condition: service_healthy
    environment:
      - ELASTICSEARCH_HOSTS=http://elasticsearch:9200

  kibana:
    image: docker.elastic.co/kibana/kibana:8.8.0
    container_name: kibana
    ports:
      - "5601:5601"
    environment:
      - ELASTICSEARCH_HOSTS=http://elasticsearch:9200
      - SERVER_NAME=kibana
    networks:
      - logging
    depends_on:
      elasticsearch:
        condition: service_healthy

volumes:
  elasticsearch_data:
  logstash_data:

networks:
  logging:
    driver: bridge
EOF

log_success "ELK Stack 설정 파일 생성 완료"

# Logstash 설정
log_info "📋 Logstash 설정 파일 생성 중..."
cat > logstash.conf << 'EOF'
input {
  beats {
    port => 5044
  }
  
  tcp {
    port => 5000
    codec => json_lines
  }
  
  http {
    port => 8080
    codec => json
  }
}

filter {
  if [fields][service] == "web" {
    grok {
      match => { "message" => "%{COMBINEDAPACHELOG}" }
    }
    
    date {
      match => [ "timestamp", "dd/MMM/yyyy:HH:mm:ss Z" ]
    }
  }
  
  if [fields][service] == "application" {
    grok {
      match => { "message" => "%{TIMESTAMP_ISO8601:timestamp} %{LOGLEVEL:level} %{GREEDYDATA:message}" }
    }
    
    date {
      match => [ "timestamp", "ISO8601" ]
    }
  }
  
  mutate {
    add_field => { "environment" => "cloud-master" }
    add_field => { "course" => "day3" }
  }
}

output {
  elasticsearch {
    hosts => ["elasticsearch:9200"]
    index => "cloud-master-logs-%{+YYYY.MM.dd}"
    template_name => "cloud-master-logs"
    template => {
      "index_patterns" => ["cloud-master-logs-*"]
      "settings" => {
        "number_of_shards" => 1
        "number_of_replicas" => 0
      }
      "mappings" => {
        "properties" => {
          "@timestamp" => { "type" => "date" }
          "level" => { "type" => "keyword" }
          "message" => { "type" => "text" }
          "service" => { "type" => "keyword" }
          "environment" => { "type" => "keyword" }
          "course" => { "type" => "keyword" }
        }
      }
    }
  }
  
  stdout {
    codec => rubydebug
  }
}
EOF

log_success "Logstash 설정 파일 생성 완료"

# 모니터링 시작 스크립트
log_info "📋 모니터링 시작 스크립트 생성 중..."
cat > start-monitoring.sh << 'EOF'
#!/bin/bash
# Cloud Master Day3 - 모니터링 스택 시작 스크립트

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

log_info "🚀 Cloud Master Day3 모니터링 스택 시작 중..."

# Docker 설치 확인
if ! command -v docker &> /dev/null; then
    log_error "Docker가 설치되지 않았습니다. 먼저 Docker를 설치하세요."
    exit 1
fi

if ! command -v docker-compose &> /dev/null; then
    log_error "Docker Compose가 설치되지 않았습니다. 먼저 Docker Compose를 설치하세요."
    exit 1
fi

# 모니터링 스택 시작
log_info "📊 모니터링 스택 시작 중..."
docker-compose -f docker-compose.monitoring.yml up -d

# 로깅 스택 시작
log_info "📝 로깅 스택 시작 중..."
docker-compose -f docker-compose.logging.yml up -d

# 서비스 상태 확인
log_info "🔍 서비스 상태 확인 중..."
sleep 10

# Prometheus 상태 확인
if curl -f -s http://localhost:9090/-/healthy > /dev/null; then
    log_success "✅ Prometheus 정상 작동"
else
    log_warning "⚠️ Prometheus 상태 확인 실패"
fi

# Grafana 상태 확인
if curl -f -s http://localhost:3001/api/health > /dev/null; then
    log_success "✅ Grafana 정상 작동"
else
    log_warning "⚠️ Grafana 상태 확인 실패"
fi

# Jaeger 상태 확인
if curl -f -s http://localhost:16686/api/services > /dev/null; then
    log_success "✅ Jaeger 정상 작동"
else
    log_warning "⚠️ Jaeger 상태 확인 실패"
fi

# Kibana 상태 확인
if curl -f -s http://localhost:5601/api/status > /dev/null; then
    log_success "✅ Kibana 정상 작동"
else
    log_warning "⚠️ Kibana 상태 확인 실패"
fi

log_success "🎉 모니터링 스택 시작 완료!"
echo ""
echo "📊 모니터링 도구 접속 정보:"
echo "  • Prometheus: http://localhost:9090"
echo "  • Grafana: http://localhost:3001 (admin/admin)"
echo "  • Jaeger: http://localhost:16686"
echo "  • Kibana: http://localhost:5601"
echo "  • Alertmanager: http://localhost:9093"
echo ""
echo "📝 로깅 도구 접속 정보:"
echo "  • Elasticsearch: http://localhost:9200"
echo "  • Logstash: http://localhost:5044 (Beats), http://localhost:5000 (TCP), http://localhost:8080 (HTTP)"
echo ""
echo "🔧 유용한 명령어:"
echo "  • 로그 확인: docker-compose -f docker-compose.monitoring.yml logs -f"
echo "  • 서비스 중지: docker-compose -f docker-compose.monitoring.yml down"
echo "  • 데이터 정리: docker-compose -f docker-compose.monitoring.yml down -v"
EOF

chmod +x start-monitoring.sh

log_success "모니터링 시작 스크립트 생성 완료"

# 최종 요약
log_success "🎉 Cloud Master Day3 모니터링 스택 설정 완료!"
echo ""
echo "📋 생성된 파일들:"
echo "  • prometheus.yml - Prometheus 설정"
echo "  • grafana-dashboard.json - Grafana 대시보드"
echo "  • docker-compose.monitoring.yml - 모니터링 스택"
echo "  • alertmanager.yml - Alert Manager 설정"
echo "  • alert_rules.yml - 알림 규칙"
echo "  • docker-compose.logging.yml - ELK 스택"
echo "  • logstash.conf - Logstash 설정"
echo "  • start-monitoring.sh - 시작 스크립트"
echo ""
echo "🚀 사용법:"
echo "  ./start-monitoring.sh"
echo ""
echo "📊 접속 정보:"
echo "  • Prometheus: http://localhost:9090"
echo "  • Grafana: http://localhost:3001 (admin/admin)"
echo "  • Jaeger: http://localhost:16686"
echo "  • Kibana: http://localhost:5601"
echo "  • Alertmanager: http://localhost:9093"
