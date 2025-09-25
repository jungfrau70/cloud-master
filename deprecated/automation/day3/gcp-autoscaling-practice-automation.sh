#!/bin/bash

# Cloud Master Day3 - GCP Managed Instance Group 자동 스케일링 실습 자동화 스크립트
# 기존 VM을 활용한 GCP MIG 자동 스케일링 구축

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
PROJECT_NAME="cloud-master-day3-gcp-mig"
ZONE="asia-northeast3-a"
REGION="asia-northeast3"
VM_NAME="cloud-deployment-server"
INSTANCE_TEMPLATE_NAME="cloud-master-day3-template"
MIG_NAME="cloud-master-day3-mig"

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
    
    # Compute Engine API 활성화
    log_info "Compute Engine API 활성화 확인 중..."
    gcloud services enable compute.googleapis.com --quiet
    
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

# 인스턴스 템플릿 생성
create_instance_template() {
    log_info "=== 인스턴스 템플릿 생성 ==="
    
    # 기존 템플릿 확인
    if gcloud compute instance-templates describe $INSTANCE_TEMPLATE_NAME &> /dev/null; then
        log_info "인스턴스 템플릿이 이미 존재합니다."
        return 0
    fi
    
    # 시작 스크립트 생성
    cat > startup-script.sh << 'EOF'
#!/bin/bash
# Cloud Master Day3 - GCP MIG 시작 스크립트

# 시스템 업데이트
apt-get update -y
apt-get install -y docker.io nginx

# Docker 서비스 시작
systemctl start docker
systemctl enable docker

# Docker Compose 설치
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# 애플리케이션 디렉토리 생성
mkdir -p /opt/app
cd /opt/app

# 간단한 웹 애플리케이션 생성
cat > app.js << 'EOL'
const express = require('express');
const app = express();
const port = 3000;

app.get('/', (req, res) => {
  res.json({
    message: 'Cloud Master Day3 - GCP MIG',
    version: '1.0.0',
    environment: 'production',
    timestamp: new Date().toISOString(),
    instance: process.env.HOSTNAME || 'unknown'
  });
});

app.get('/health', (req, res) => {
  res.json({ status: 'healthy', timestamp: new Date().toISOString() });
});

app.get('/metrics', (req, res) => {
  res.json({
    requests_total: Math.floor(Math.random() * 1000),
    cpu_usage: Math.random() * 100,
    memory_usage: Math.random() * 100
  });
});

app.listen(port, '0.0.0.0', () => {
  console.log(`App listening at http://0.0.0.0:${port}`);
});
EOL

# package.json 생성
cat > package.json << 'EOL'
{
  "name": "cloud-master-day3-gcp-mig",
  "version": "1.0.0",
  "description": "Cloud Master Day3 GCP MIG Application",
  "main": "app.js",
  "scripts": {
    "start": "node app.js"
  },
  "dependencies": {
    "express": "^4.18.2"
  }
}
EOL

# Node.js 설치
curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
apt-get install -y nodejs

# 애플리케이션 의존성 설치
npm install

# systemd 서비스 생성
cat > /etc/systemd/system/cloud-master-app.service << 'EOL'
[Unit]
Description=Cloud Master Day3 GCP MIG Application
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/app
ExecStart=/usr/bin/node app.js
Restart=always
RestartSec=10
Environment=NODE_ENV=production

[Install]
WantedBy=multi-user.target
EOL

# 서비스 시작
systemctl daemon-reload
systemctl enable cloud-master-app
systemctl start cloud-master-app

# Nginx 설정
cat > /etc/nginx/sites-available/default << 'EOL'
server {
    listen 80;
    server_name _;

    location / {
        proxy_pass http://localhost:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    location /health {
        proxy_pass http://localhost:3000/health;
    }

    location /metrics {
        proxy_pass http://localhost:3000/metrics;
    }
}
EOL

# Nginx 재시작
systemctl restart nginx
systemctl enable nginx

echo "Cloud Master Day3 GCP MIG 시작 스크립트 완료" > /var/log/startup-script.log
EOF

    # 인스턴스 템플릿 생성
    log_info "인스턴스 템플릿 생성 중..."
    run_with_timeout 120 gcloud compute instance-templates create $INSTANCE_TEMPLATE_NAME \
        --image-family=ubuntu-2004-lts \
        --image-project=ubuntu-os-cloud \
        --machine-type=e2-micro \
        --boot-disk-size=10GB \
        --boot-disk-type=pd-standard \
        --tags=cloud-master-day3,http-server,https-server \
        --metadata-from-file startup-script=startup-script.sh \
        --description="Cloud Master Day3 GCP MIG Template"
    
    log_success "인스턴스 템플릿 생성 완료"
    
    # 시작 스크립트 정리
    rm -f startup-script.sh
}

# Managed Instance Group 생성
create_mig() {
    log_info "=== Managed Instance Group 생성 ==="
    
    # 기존 MIG 확인
    if gcloud compute instance-groups managed describe $MIG_NAME --zone=$ZONE &> /dev/null; then
        log_info "Managed Instance Group이 이미 존재합니다."
        return 0
    fi
    
    # MIG 생성
    log_info "Managed Instance Group 생성 중..."
    run_with_timeout 120 gcloud compute instance-groups managed create $MIG_NAME \
        --template=$INSTANCE_TEMPLATE_NAME \
        --size=2 \
        --zone=$ZONE \
        --description="Cloud Master Day3 GCP MIG"
    
    log_success "Managed Instance Group 생성 완료"
}

# 자동 스케일링 설정
setup_autoscaling() {
    log_info "=== 자동 스케일링 설정 ==="
    
    # 자동 스케일링 설정
    log_info "자동 스케일링 정책 설정 중..."
    run_with_timeout 60 gcloud compute instance-groups managed set-autoscaling $MIG_NAME \
        --zone=$ZONE \
        --max-num-replicas=5 \
        --min-num-replicas=1 \
        --target-cpu-utilization=0.7 \
        --cool-down-period=60 \
        --description="Cloud Master Day3 GCP MIG Autoscaling"
    
    log_success "자동 스케일링 설정 완료"
}

# 헬스 체크 설정
setup_health_check() {
    log_info "=== 헬스 체크 설정 ==="
    
    # HTTP 헬스 체크 생성
    log_info "HTTP 헬스 체크 생성 중..."
    if ! gcloud compute health-checks describe $PROJECT_NAME-hc &> /dev/null; then
        run_with_timeout 60 gcloud compute health-checks create http $PROJECT_NAME-hc \
            --port=80 \
            --request-path=/health \
            --check-interval=10s \
            --timeout=5s \
            --healthy-threshold=2 \
            --unhealthy-threshold=3
        log_success "헬스 체크 생성 완료"
    else
        log_info "헬스 체크가 이미 존재합니다."
    fi
}

# 로드밸런서 설정
setup_load_balancer() {
    log_info "=== 로드밸런서 설정 ==="
    
    # Backend Service 생성
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
    
    # MIG를 Backend Service에 추가
    log_info "MIG를 Backend Service에 추가 중..."
    run_with_timeout 60 gcloud compute backend-services add-backend $PROJECT_NAME-backend \
        --instance-group=$MIG_NAME \
        --instance-group-zone=$ZONE \
        --global
    log_success "MIG 추가 완료"
    
    # URL Map 생성
    log_info "URL Map 생성 중..."
    if ! gcloud compute url-maps describe $PROJECT_NAME-url-map &> /dev/null; then
        run_with_timeout 60 gcloud compute url-maps create $PROJECT_NAME-url-map \
            --default-service=$PROJECT_NAME-backend
        log_success "URL Map 생성 완료"
    else
        log_info "URL Map이 이미 존재합니다."
    fi
    
    # Target HTTP Proxy 생성
    log_info "Target HTTP Proxy 생성 중..."
    if ! gcloud compute target-http-proxies describe $PROJECT_NAME-proxy &> /dev/null; then
        run_with_timeout 60 gcloud compute target-http-proxies create $PROJECT_NAME-proxy \
            --url-map=$PROJECT_NAME-url-map
        log_success "Target HTTP Proxy 생성 완료"
    else
        log_info "Target HTTP Proxy가 이미 존재합니다."
    fi
    
    # Forwarding Rule 생성
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
    
    # Load Balancer IP 확인
    log_info "Load Balancer IP 확인 중..."
    LB_IP=$(run_with_timeout 30 gcloud compute forwarding-rules describe $PROJECT_NAME-rule \
        --global \
        --format="value(IPAddress)" 2>/dev/null)
    
    if [ -n "$LB_IP" ]; then
        log_success "로드밸런서 설정 완료"
        log_info "Load Balancer IP: http://$LB_IP"
        echo "$LB_IP" > gcp-mig-lb-ip.txt
    else
        log_warning "Load Balancer IP를 가져올 수 없습니다."
    fi
}

# 모니터링 설정
setup_monitoring() {
    log_info "=== 모니터링 설정 ==="
    
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
  
  - job_name: 'gcp-mig'
    static_configs:
      - targets: ['43.200.248.222:3000']
    metrics_path: '/metrics'
    scrape_interval: 30s
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
    volumes:
      - grafana_data:/var/lib/grafana

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

volumes:
  prometheus_data:
  grafana_data:
EOF

    log_success "모니터링 설정 완료"
}

# 시스템 테스트
test_system() {
    log_info "=== 시스템 테스트 ==="
    
    # MIG 상태 확인
    log_info "MIG 상태 확인 중..."
    gcloud compute instance-groups managed describe $MIG_NAME --zone=$ZONE \
        --format="value(status.isStable,currentActions.none,autoscaler.status)"
    
    # 자동 스케일링 상태 확인
    log_info "자동 스케일링 상태 확인 중..."
    gcloud compute instance-groups managed describe-autoscaler $MIG_NAME --zone=$ZONE
    
    # Load Balancer 테스트
    if [ -f "gcp-mig-lb-ip.txt" ]; then
        LB_IP=$(cat gcp-mig-lb-ip.txt)
        log_info "Load Balancer 테스트 중..."
        if run_with_timeout 10 curl -f "http://$LB_IP" &> /dev/null; then
            log_success "Load Balancer 정상 작동"
        else
            log_warning "Load Balancer 헬스 체크 실패"
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
    
    # MIG 삭제
    if gcloud compute instance-groups managed describe $MIG_NAME --zone=$ZONE &> /dev/null; then
        log_info "Managed Instance Group 삭제 중..."
        gcloud compute instance-groups managed delete $MIG_NAME --zone=$ZONE --quiet
    fi
    
    # 인스턴스 템플릿 삭제
    if gcloud compute instance-templates describe $INSTANCE_TEMPLATE_NAME &> /dev/null; then
        log_info "인스턴스 템플릿 삭제 중..."
        gcloud compute instance-templates delete $INSTANCE_TEMPLATE_NAME --quiet
    fi
    
    # 모니터링 스택 정리
    if [ -d "monitoring-stack" ]; then
        log_info "모니터링 스택 정리 중..."
        cd monitoring-stack
        docker-compose down -v 2>/dev/null || true
        cd ..
        rm -rf monitoring-stack
    fi
    
    # 임시 파일 정리
    rm -f gcp-mig-lb-ip.txt
    
    log_success "리소스 정리 완료"
}

# 메인 함수
main() {
    case "${1:-setup}" in
        "setup")
            check_prerequisites
            setup_environment
            check_gcp_vm
            create_instance_template
            create_mig
            setup_autoscaling
            setup_health_check
            setup_load_balancer
            setup_monitoring
            test_system
            
            log_success "Cloud Master Day3 GCP MIG 자동 스케일링 실습 완료!"
            log_info "접속 URL:"
            if [ -f "gcp-mig-lb-ip.txt" ]; then
                log_info "  GCP Load Balancer: http://$(cat gcp-mig-lb-ip.txt)"
            fi
            log_info "  Prometheus: http://localhost:9090"
            log_info "  Grafana: http://localhost:3001 (admin/admin)"
            log_info "  Node Exporter: http://localhost:9100"
            ;;
        "cleanup")
            cleanup
            ;;
        "test")
            test_system
            ;;
        *)
            echo "사용법: $0 [setup|cleanup|test]"
            echo "  setup   - GCP MIG 자동 스케일링 설정 (기본값)"
            echo "  cleanup - 리소스 정리"
            echo "  test    - 시스템 테스트"
            exit 1
            ;;
    esac
}

# 스크립트 실행
main "$@"
