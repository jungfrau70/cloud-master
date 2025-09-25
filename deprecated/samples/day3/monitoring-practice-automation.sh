#!/bin/bash

# Cloud Master Day 3 - Monitoring Practice Automation Script
# 작성자: Cloud Master Team
# 목적: 모니터링 및 로깅 시스템 실습 자동화

set -e  # 오류 발생 시 스크립트 중단

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

# 실습 환경 확인
check_prerequisites() {
    log_info "실습 환경 확인 중..."
    
    # Docker 설치 확인
    if ! command -v docker &> /dev/null; then
        log_error "Docker가 설치되지 않았습니다. 먼저 Docker를 설치해주세요."
        exit 1
    fi
    
    # Docker Compose 설치 확인
    if ! command -v docker-compose &> /dev/null; then
        log_warning "Docker Compose가 설치되지 않았습니다. 자동으로 설치를 시도합니다."
        install_docker_compose
    fi
    
    # AWS CLI 설치 확인
    if ! command -v aws &> /dev/null; then
        log_warning "AWS CLI가 설치되지 않았습니다. 자동으로 설치를 시도합니다."
        install_aws_cli
    fi
    
    log_success "실습 환경 확인 완료"
}

# Docker Compose 설치
install_docker_compose() {
    log_info "Docker Compose 설치 중..."
    
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        # Linux
        sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        sudo chmod +x /usr/local/bin/docker-compose
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        if command -v brew &> /dev/null; then
            brew install docker-compose
        else
            log_error "Homebrew가 설치되지 않았습니다. Docker Compose를 수동으로 설치해주세요."
            exit 1
        fi
    else
        log_error "지원되지 않는 운영체제입니다. Docker Compose를 수동으로 설치해주세요."
        exit 1
    fi
    
    log_success "Docker Compose 설치 완료"
}

# AWS CLI 설치
install_aws_cli() {
    log_info "AWS CLI 설치 중..."
    
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        # Linux
        curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
        unzip awscliv2.zip
        sudo ./aws/install
        rm -rf aws awscliv2.zip
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        if command -v brew &> /dev/null; then
            brew install awscli
        else
            curl "https://awscli.amazonaws.com/AWSCLIV2.pkg" -o "AWSCLIV2.pkg"
            sudo installer -pkg AWSCLIV2.pkg -target /
            rm AWSCLIV2.pkg
        fi
    else
        log_error "지원되지 않는 운영체제입니다. AWS CLI를 수동으로 설치해주세요."
        exit 1
    fi
    
    log_success "AWS CLI 설치 완료"
}

# 1단계: Prometheus & Grafana 모니터링 스택 설정
step1_prometheus_grafana_setup() {
    log_info "=== 1단계: Prometheus & Grafana 모니터링 스택 설정 ==="
    
    # 실습용 디렉토리 생성
    log_info "실습용 디렉토리 생성:"
    mkdir -p ~/monitoring-practice
    cd ~/monitoring-practice
    
    # 기존 컨테이너 정리
    log_info "기존 모니터링 컨테이너 정리:"
    docker-compose down 2>/dev/null || true
    
    # Docker Compose 파일 생성
    log_info "Docker Compose 파일 생성:"
    cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  # Prometheus - 메트릭 수집 및 저장
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
      - '--web.console.libraries=/etc/prometheus/console_libraries'
      - '--web.console.templates=/etc/prometheus/consoles'
      - '--storage.tsdb.retention.time=200h'
      - '--web.enable-lifecycle'
    networks:
      - monitoring

  # Grafana - 시각화 및 대시보드
  grafana:
    image: grafana/grafana:latest
    container_name: grafana
    ports:
      - "3000:3000"
    volumes:
      - grafana_data:/var/lib/grafana
      - ./grafana/provisioning:/etc/grafana/provisioning
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin123
      - GF_USERS_ALLOW_SIGN_UP=false
    networks:
      - monitoring

  # Node Exporter - 시스템 메트릭 수집
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

  # cAdvisor - 컨테이너 메트릭 수집
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

  # AlertManager - 알림 관리
  alertmanager:
    image: prom/alertmanager:latest
    container_name: alertmanager
    ports:
      - "9093:9093"
    volumes:
      - ./alertmanager.yml:/etc/alertmanager/alertmanager.yml
      - alertmanager_data:/alertmanager
    command:
      - '--config.file=/etc/alertmanager/alertmanager.yml'
      - '--storage.path=/alertmanager'
      - '--web.external-url=http://localhost:9093'
    networks:
      - monitoring

  # 테스트용 웹 애플리케이션
  web-app:
    image: nginx:alpine
    container_name: web-app
    ports:
      - "80:80"
    networks:
      - monitoring

volumes:
  prometheus_data:
  grafana_data:
  alertmanager_data:

networks:
  monitoring:
    driver: bridge
EOF
    
    # Prometheus 설정 파일 생성
    log_info "Prometheus 설정 파일 생성:"
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

  - job_name: 'web-app'
    static_configs:
      - targets: ['web-app:80']
EOF
    
    # AlertManager 설정 파일 생성
    log_info "AlertManager 설정 파일 생성:"
    cat > alertmanager.yml << 'EOF'
global:
  smtp_smarthost: 'localhost:587'
  smtp_from: 'alertmanager@example.com'

route:
  group_by: ['alertname']
  group_wait: 10s
  group_interval: 10s
  repeat_interval: 1h
  receiver: 'web.hook'

receivers:
  - name: 'web.hook'
    webhook_configs:
      - url: 'http://127.0.0.1:5001/'

inhibit_rules:
  - source_match:
      severity: 'critical'
    target_match:
      severity: 'warning'
    equal: ['alertname', 'dev', 'instance']
EOF
    
    # Grafana 프로비저닝 디렉토리 생성
    log_info "Grafana 프로비저닝 설정 생성:"
    mkdir -p grafana/provisioning/datasources
    mkdir -p grafana/provisioning/dashboards
    
    # Prometheus 데이터소스 설정
    cat > grafana/provisioning/datasources/prometheus.yml << 'EOF'
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
EOF
    
    # 모니터링 스택 시작
    log_info "모니터링 스택 시작:"
    docker-compose up -d
    
    # 서비스 상태 확인
    log_info "서비스 상태 확인:"
    docker-compose ps
    
    # 서비스 시작 대기
    log_info "서비스 시작 대기 (60초)..."
    sleep 60
    
    # 서비스 상태 재확인
    log_info "서비스 상태 재확인:"
    docker-compose ps
    
    log_success "1단계 완료: Prometheus & Grafana 모니터링 스택 설정"
}

# 2단계: CloudWatch 모니터링 설정
step2_cloudwatch_setup() {
    log_info "=== 2단계: CloudWatch 모니터링 설정 ==="
    
    # AWS CLI 설정 확인
    log_info "AWS CLI 설정 확인:"
    if ! aws sts get-caller-identity &> /dev/null; then
        log_warning "AWS CLI가 설정되지 않았습니다. AWS 자격 증명을 설정해주세요."
        log_info "다음 명령어로 AWS 자격 증명을 설정하세요:"
        echo "  aws configure"
        echo "  AWS Access Key ID: YOUR_ACCESS_KEY"
        echo "  AWS Secret Access Key: YOUR_SECRET_KEY"
        echo "  Default region name: ap-northeast-2"
        echo "  Default output format: json"
        log_warning "AWS 설정을 완료한 후 스크립트를 다시 실행하세요."
        return
    fi
    
    # AWS 계정 정보 확인
    log_info "AWS 계정 정보 확인:"
    aws sts get-caller-identity
    
    # CloudWatch 대시보드 생성
    log_info "CloudWatch 대시보드 생성:"
    cat > cloudwatch-dashboard.json << 'EOF'
{
  "widgets": [
    {
      "type": "metric",
      "x": 0,
      "y": 0,
      "width": 12,
      "height": 6,
      "properties": {
        "metrics": [
          [ "AWS/EC2", "CPUUtilization" ],
          [ ".", "NetworkIn" ],
          [ ".", "NetworkOut" ]
        ],
        "view": "timeSeries",
        "stacked": false,
        "region": "ap-northeast-2",
        "title": "EC2 Metrics",
        "period": 300
      }
    },
    {
      "type": "metric",
      "x": 12,
      "y": 0,
      "width": 12,
      "height": 6,
      "properties": {
        "metrics": [
          [ "AWS/EC2", "DiskReadOps" ],
          [ ".", "DiskWriteOps" ]
        ],
        "view": "timeSeries",
        "stacked": false,
        "region": "ap-northeast-2",
        "title": "Disk Operations",
        "period": 300
      }
    }
  ]
}
EOF
    
    # CloudWatch 대시보드 확인 및 생성
    log_info "CloudWatch 대시보드 확인:"
    if aws cloudwatch get-dashboard --dashboard-name "CloudMaster-Practice" &> /dev/null; then
        log_info "CloudMaster-Practice 대시보드가 이미 존재합니다."
    else
        log_info "CloudWatch 대시보드 생성:"
        aws cloudwatch put-dashboard \
            --dashboard-name "CloudMaster-Practice" \
            --dashboard-body file://cloudwatch-dashboard.json
    fi
    
    # 커스텀 메트릭 전송
    log_info "커스텀 메트릭 전송:"
    aws cloudwatch put-metric-data \
        --namespace "CloudMaster/Practice" \
        --metric-data MetricName=CustomMetric,Value=1.0,Unit=Count
    
    # 메트릭 확인
    log_info "메트릭 확인:"
    aws cloudwatch list-metrics --namespace "CloudMaster/Practice"
    
    # CloudWatch 로그 그룹 확인 및 생성
    log_info "CloudWatch 로그 그룹 확인:"
    if aws logs describe-log-groups --log-group-name-prefix "/cloudmaster/practice" --query 'logGroups[0].logGroupName' --output text | grep -q "/cloudmaster/practice"; then
        log_info "로그 그룹 /cloudmaster/practice가 이미 존재합니다."
    else
        log_info "CloudWatch 로그 그룹 생성:"
        aws logs create-log-group --log-group-name "/cloudmaster/practice"
    fi
    
    # 로그 스트림 확인 및 생성
    log_info "로그 스트림 확인:"
    if aws logs describe-log-streams --log-group-name "/cloudmaster/practice" --log-stream-name-prefix "application-logs" --query 'logStreams[0].logStreamName' --output text | grep -q "application-logs"; then
        log_info "로그 스트림 application-logs가 이미 존재합니다."
    else
        log_info "로그 스트림 생성:"
        aws logs create-log-stream \
            --log-group-name "/cloudmaster/practice" \
            --log-stream-name "application-logs"
    fi
    
    # 로그 이벤트 전송
    log_info "로그 이벤트 전송:"
    aws logs put-log-events \
        --log-group-name "/cloudmaster/practice" \
        --log-stream-name "application-logs" \
        --log-events timestamp=$(date +%s)000,message="CloudMaster Practice Log Entry"
    
    log_success "2단계 완료: CloudWatch 모니터링 설정"
}

# 3단계: 로그 수집 및 분석 (ELK Stack)
step3_elk_stack_setup() {
    log_info "=== 3단계: 로그 수집 및 분석 (ELK Stack) ==="
    
    # ELK Stack Docker Compose 파일 생성
    log_info "ELK Stack Docker Compose 파일 생성:"
    cat > elk-compose.yml << 'EOF'
version: '3.8'

services:
  # Elasticsearch - 로그 저장 및 검색
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
      - elk

  # Kibana - 로그 시각화
  kibana:
    image: docker.elastic.co/kibana/kibana:8.8.0
    container_name: kibana
    environment:
      - ELASTICSEARCH_HOSTS=http://elasticsearch:9200
    ports:
      - "5601:5601"
    depends_on:
      - elasticsearch
    networks:
      - elk

  # Logstash - 로그 처리
  logstash:
    image: docker.elastic.co/logstash/logstash:8.8.0
    container_name: logstash
    ports:
      - "5044:5044"
    volumes:
      - ./logstash.conf:/usr/share/logstash/pipeline/logstash.conf
    depends_on:
      - elasticsearch
    networks:
      - elk

  # Filebeat - 로그 수집
  filebeat:
    image: docker.elastic.co/beats/filebeat:8.8.0
    container_name: filebeat
    user: root
    volumes:
      - ./filebeat.yml:/usr/share/filebeat/filebeat.yml:ro
      - /var/lib/docker/containers:/var/lib/docker/containers:ro
      - /var/run/docker.sock:/var/run/docker.sock:ro
    depends_on:
      - logstash
    networks:
      - elk

volumes:
  elasticsearch_data:

networks:
  elk:
    driver: bridge
EOF
    
    # Logstash 설정 파일 생성
    log_info "Logstash 설정 파일 생성:"
    cat > logstash.conf << 'EOF'
input {
  beats {
    port => 5044
  }
}

filter {
  if [fields][service] == "nginx" {
    grok {
      match => { "message" => "%{COMBINEDAPACHELOG}" }
    }
  }
  
  if [fields][service] == "application" {
    json {
      source => "message"
    }
  }
}

output {
  elasticsearch {
    hosts => ["elasticsearch:9200"]
    index => "logstash-%{+YYYY.MM.dd}"
  }
}
EOF
    
    # Filebeat 설정 파일 생성
    log_info "Filebeat 설정 파일 생성:"
    cat > filebeat.yml << 'EOF'
filebeat.inputs:
- type: container
  paths:
    - '/var/lib/docker/containers/*/*.log'
  processors:
  - add_docker_metadata:
      host: "unix:///var/run/docker.sock"
  - add_fields:
      fields:
        service: "docker"

output.logstash:
  hosts: ["logstash:5044"]

logging.level: info
EOF
    
    # ELK Stack 시작
    log_info "ELK Stack 시작:"
    docker-compose -f elk-compose.yml up -d
    
    # 서비스 상태 확인
    log_info "ELK Stack 서비스 상태 확인:"
    docker-compose -f elk-compose.yml ps
    
    # 서비스 시작 대기
    log_info "ELK Stack 서비스 시작 대기 (60초)..."
    sleep 60
    
    # Elasticsearch 상태 확인
    log_info "Elasticsearch 상태 확인:"
    curl -s http://localhost:9200 | head -5
    
    log_success "3단계 완료: 로그 수집 및 분석 (ELK Stack)"
}

# 4단계: 애플리케이션 모니터링
step4_application_monitoring() {
    log_info "=== 4단계: 애플리케이션 모니터링 ==="
    
    # 모니터링 가능한 웹 애플리케이션 생성
    log_info "모니터링 가능한 웹 애플리케이션 생성:"
    cat > app-compose.yml << 'EOF'
version: '3.8'

services:
  # 웹 애플리케이션
  web-app:
    build: .
    container_name: monitored-web-app
    ports:
      - "8080:3000"
    environment:
      - NODE_ENV=production
      - METRICS_PORT=9090
    networks:
      - monitoring
      - elk

  # Prometheus Node Exporter
  node-exporter:
    image: prom/node-exporter:latest
    container_name: app-node-exporter
    ports:
      - "9101:9100"
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

networks:
  monitoring:
    external: true
  elk:
    external: true
EOF
    
    # Dockerfile 생성
    log_info "모니터링 가능한 애플리케이션 Dockerfile 생성:"
    cat > Dockerfile << 'EOF'
FROM node:18-alpine

WORKDIR /app

# 의존성 설치
COPY package*.json ./
RUN npm ci --only=production

# 애플리케이션 코드 복사
COPY . .

# 포트 노출
EXPOSE 3000 9090

# 애플리케이션 실행
CMD ["npm", "start"]
EOF
    
    # package.json 생성
    log_info "package.json 생성:"
    cat > package.json << 'EOF'
{
  "name": "monitored-web-app",
  "version": "1.0.0",
  "description": "Web application with monitoring capabilities",
  "main": "server.js",
  "scripts": {
    "start": "node server.js"
  },
  "dependencies": {
    "express": "^4.18.0",
    "prom-client": "^14.0.0"
  }
}
EOF
    
    # 모니터링 가능한 서버 코드 생성
    log_info "모니터링 가능한 서버 코드 생성:"
    cat > server.js << 'EOF'
const express = require('express');
const client = require('prom-client');

const app = express();
const port = process.env.PORT || 3000;
const metricsPort = process.env.METRICS_PORT || 9090;

// Prometheus 메트릭 설정
const register = new client.Registry();

// 기본 메트릭 수집
client.collectDefaultMetrics({ register });

// 커스텀 메트릭
const httpRequestDuration = new client.Histogram({
  name: 'http_request_duration_seconds',
  help: 'Duration of HTTP requests in seconds',
  labelNames: ['method', 'route', 'status_code'],
  buckets: [0.1, 0.3, 0.5, 0.7, 1, 3, 5, 7, 10]
});

const httpRequestTotal = new client.Counter({
  name: 'http_requests_total',
  help: 'Total number of HTTP requests',
  labelNames: ['method', 'route', 'status_code']
});

const activeConnections = new client.Gauge({
  name: 'active_connections',
  help: 'Number of active connections'
});

register.registerMetric(httpRequestDuration);
register.registerMetric(httpRequestTotal);
register.registerMetric(activeConnections);

// 미들웨어
app.use(express.json());

// 요청 로깅 미들웨어
app.use((req, res, next) => {
  const start = Date.now();
  
  res.on('finish', () => {
    const duration = (Date.now() - start) / 1000;
    const labels = {
      method: req.method,
      route: req.route ? req.route.path : req.path,
      status_code: res.statusCode
    };
    
    httpRequestDuration.observe(labels, duration);
    httpRequestTotal.inc(labels);
  });
  
  next();
});

// 라우트
app.get('/', (req, res) => {
  res.json({
    message: 'Monitored Web Application',
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    version: '1.0.0'
  });
});

app.get('/health', (req, res) => {
  res.json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    uptime: process.uptime()
  });
});

app.get('/metrics', (req, res) => {
  res.set('Content-Type', register.contentType);
  res.end(register.metrics());
});

app.get('/api/data', (req, res) => {
  // 시뮬레이션된 데이터 처리
  const data = {
    id: Math.floor(Math.random() * 1000),
    value: Math.random() * 100,
    timestamp: new Date().toISOString()
  };
  
  res.json(data);
});

app.get('/api/error', (req, res) => {
  res.status(500).json({
    error: 'Simulated error for testing',
    timestamp: new Date().toISOString()
  });
});

// 서버 시작
app.listen(port, () => {
  console.log(`Web application running on port ${port}`);
  console.log(`Metrics available at http://localhost:${port}/metrics`);
});

// Graceful shutdown
process.on('SIGTERM', () => {
  console.log('SIGTERM received, shutting down gracefully');
  process.exit(0);
});

process.on('SIGINT', () => {
  console.log('SIGINT received, shutting down gracefully');
  process.exit(0);
});
EOF
    
    # 애플리케이션 빌드 및 실행
    log_info "애플리케이션 빌드 및 실행:"
    docker-compose -f app-compose.yml up -d --build
    
    # 애플리케이션 상태 확인
    log_info "애플리케이션 상태 확인:"
    sleep 10
    curl -s http://localhost:8080 | head -5
    curl -s http://localhost:8080/health
    curl -s http://localhost:8080/metrics | head -10
    
    log_success "4단계 완료: 애플리케이션 모니터링"
}

# 5단계: 알림 설정 및 테스트
step5_alerting_setup() {
    log_info "=== 5단계: 알림 설정 및 테스트 ==="
    
    # Prometheus 알림 규칙 생성
    log_info "Prometheus 알림 규칙 생성:"
    cat > alert_rules.yml << 'EOF'
groups:
- name: cloudmaster.rules
  rules:
  - alert: HighCPUUsage
    expr: 100 - (avg by(instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 80
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "High CPU usage detected"
      description: "CPU usage is above 80% for more than 5 minutes"

  - alert: HighMemoryUsage
    expr: (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100 > 85
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "High memory usage detected"
      description: "Memory usage is above 85% for more than 5 minutes"

  - alert: ServiceDown
    expr: up == 0
    for: 1m
    labels:
      severity: critical
    annotations:
      summary: "Service is down"
      description: "Service {{ $labels.instance }} has been down for more than 1 minute"

  - alert: HighErrorRate
    expr: rate(http_requests_total{status_code=~"5.."}[5m]) / rate(http_requests_total[5m]) * 100 > 5
    for: 5m
    labels:
      severity: critical
    annotations:
      summary: "High error rate detected"
      description: "Error rate is above 5% for more than 5 minutes"
EOF
    
    # Prometheus 설정 업데이트
    log_info "Prometheus 설정 업데이트:"
    docker-compose restart prometheus
    
    # 알림 규칙 확인
    log_info "알림 규칙 확인:"
    sleep 10
    curl -s http://localhost:9090/api/v1/rules | head -5
    
    # AlertManager 상태 확인
    log_info "AlertManager 상태 확인:"
    curl -s http://localhost:9093/api/v1/status | head -5
    
    log_success "5단계 완료: 알림 설정 및 테스트"
}

# 6단계: 대시보드 생성 및 설정
step6_dashboard_setup() {
    log_info "=== 6단계: 대시보드 생성 및 설정 ==="
    
    # Grafana 대시보드 JSON 생성
    log_info "Grafana 대시보드 JSON 생성:"
    cat > grafana-dashboard.json << 'EOF'
{
  "dashboard": {
    "id": null,
    "title": "CloudMaster Practice Dashboard",
    "tags": ["cloudmaster", "practice"],
    "style": "dark",
    "timezone": "browser",
    "panels": [
      {
        "id": 1,
        "title": "CPU Usage",
        "type": "stat",
        "targets": [
          {
            "expr": "100 - (avg by(instance) (irate(node_cpu_seconds_total{mode=\"idle\"}[5m])) * 100)",
            "legendFormat": "CPU Usage %"
          }
        ],
        "gridPos": {"h": 8, "w": 12, "x": 0, "y": 0}
      },
      {
        "id": 2,
        "title": "Memory Usage",
        "type": "stat",
        "targets": [
          {
            "expr": "(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100",
            "legendFormat": "Memory Usage %"
          }
        ],
        "gridPos": {"h": 8, "w": 12, "x": 12, "y": 0}
      },
      {
        "id": 3,
        "title": "HTTP Requests",
        "type": "graph",
        "targets": [
          {
            "expr": "rate(http_requests_total[5m])",
            "legendFormat": "{{method}} {{route}}"
          }
        ],
        "gridPos": {"h": 8, "w": 24, "x": 0, "y": 8}
      }
    ],
    "time": {
      "from": "now-1h",
      "to": "now"
    },
    "refresh": "5s"
  }
}
EOF
    
    # 대시보드 가져오기
    log_info "Grafana 대시보드 가져오기:"
    curl -X POST \
      http://admin:admin123@localhost:3000/api/dashboards/db \
      -H 'Content-Type: application/json' \
      -d @grafana-dashboard.json
    
    log_success "6단계 완료: 대시보드 생성 및 설정"
}

# 7단계: 모니터링 테스트 및 검증
step7_monitoring_test() {
    log_info "=== 7단계: 모니터링 테스트 및 검증 ==="
    
    # 웹 애플리케이션 부하 테스트
    log_info "웹 애플리케이션 부하 테스트:"
    for i in {1..100}; do
        curl -s http://localhost:8080/api/data > /dev/null &
        curl -s http://localhost:8080/health > /dev/null &
        if [ $((i % 10)) -eq 0 ]; then
            sleep 1
        fi
    done
    
    # 에러 시뮬레이션
    log_info "에러 시뮬레이션:"
    for i in {1..10}; do
        curl -s http://localhost:8080/api/error > /dev/null &
    done
    
    # 모니터링 서비스 상태 확인
    log_info "모니터링 서비스 상태 확인:"
    echo "=== Prometheus ==="
    curl -s http://localhost:9090/api/v1/targets | head -5
    
    echo "=== Grafana ==="
    curl -s http://localhost:3000/api/health | head -5
    
    echo "=== Elasticsearch ==="
    curl -s http://localhost:9200/_cluster/health | head -5
    
    echo "=== Kibana ==="
    curl -s http://localhost:5601/api/status | head -5
    
    log_success "7단계 완료: 모니터링 테스트 및 검증"
}

# 8단계: 정리 및 요약
step8_cleanup_and_summary() {
    log_info "=== 8단계: 정리 및 요약 ==="
    
    # 모든 서비스 중지
    log_info "모든 서비스 중지:"
    docker-compose down
    docker-compose -f elk-compose.yml down
    docker-compose -f app-compose.yml down
    
    # 볼륨 정리 (선택사항)
    log_warning "볼륨 정리 (선택사항):"
    echo "다음 명령어로 볼륨을 정리할 수 있습니다:"
    echo "  docker volume prune"
    
    # 실습 결과 요약
    log_success "=== 모니터링 실습 완료 ==="
    echo "✅ Prometheus & Grafana 모니터링 스택"
    echo "✅ CloudWatch 대시보드 및 메트릭"
    echo "✅ ELK Stack 로그 수집 및 분석"
    echo "✅ 애플리케이션 모니터링 설정"
    echo "✅ 알림 규칙 및 AlertManager"
    echo "✅ Grafana 대시보드 생성"
    echo "✅ 모니터링 테스트 및 검증"
    echo ""
    echo "🌐 접속 가능한 서비스:"
    echo "  - Prometheus: http://localhost:9090"
    echo "  - Grafana: http://localhost:3000 (admin/admin123)"
    echo "  - Elasticsearch: http://localhost:9200"
    echo "  - Kibana: http://localhost:5601"
    echo "  - AlertManager: http://localhost:9093"
    echo "  - 모니터링 앱: http://localhost:8080"
    echo ""
    echo "📊 주요 학습 내용:"
    echo "  - 메트릭 수집 및 저장 (Prometheus)"
    echo "  - 시각화 및 대시보드 (Grafana)"
    echo "  - 로그 수집 및 분석 (ELK Stack)"
    echo "  - 클라우드 모니터링 (CloudWatch)"
    echo "  - 알림 설정 및 관리"
    echo "  - 애플리케이션 모니터링"
}

# 메인 실행 함수
main() {
    log_info "Cloud Master Day 3 - Monitoring Practice Automation 시작"
    echo "================================================================="
    
    check_prerequisites
    step1_prometheus_grafana_setup
    step2_cloudwatch_setup
    step3_elk_stack_setup
    step4_application_monitoring
    step5_alerting_setup
    step6_dashboard_setup
    step7_monitoring_test
    step8_cleanup_and_summary
    
    log_success "모든 모니터링 실습이 완료되었습니다!"
}

# 스크립트 실행
main "$@"
