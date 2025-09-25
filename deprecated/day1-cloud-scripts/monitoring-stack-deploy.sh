#!/bin/bash

# 모니터링 스택 자동 배포 스크립트
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
NAMESPACE="monitoring"
PROMETHEUS_PORT=9090
GRAFANA_PORT=3000
ALERTMANAGER_PORT=9093
NODE_EXPORTER_PORT=9100

# 체크포인트 파일
CHECKPOINT_FILE="monitoring-stack-checkpoint.json"

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
NAMESPACE_CREATED=$NAMESPACE_CREATED
PROMETHEUS_DEPLOYED=$PROMETHEUS_DEPLOYED
GRAFANA_DEPLOYED=$GRAFANA_DEPLOYED
NODE_EXPORTER_DEPLOYED=$NODE_EXPORTER_DEPLOYED
ALERTMANAGER_DEPLOYED=$ALERTMANAGER_DEPLOYED
EOF
}

# 환경 체크
check_environment() {
    log_info "환경 체크 중..."
    
    # Docker 체크
    if ! command -v docker &> /dev/null; then
        log_error "Docker가 설치되지 않았습니다."
        exit 1
    fi
    
    # kubectl 체크 (선택사항)
    if command -v kubectl &> /dev/null; then
        log_info "Kubernetes 환경 감지됨"
        K8S_MODE=true
    else
        log_info "Docker 환경으로 실행"
        K8S_MODE=false
    fi
    
    log_success "환경 체크 완료"
}

# 네임스페이스 생성 (Kubernetes 모드)
create_namespace() {
    if [ "$K8S_MODE" = "false" ]; then
        return 0
    fi
    
    if [ "$NAMESPACE_CREATED" = "true" ]; then
        log_info "네임스페이스가 이미 생성되어 있습니다."
        return 0
    fi
    
    log_info "네임스페이스 생성 중..."
    
    kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
    
    if [ $? -eq 0 ]; then
        NAMESPACE_CREATED="true"
        log_success "네임스페이스 생성 완료: $NAMESPACE"
    else
        log_error "네임스페이스 생성 실패"
        exit 1
    fi
}

# Prometheus 설정 파일 생성
create_prometheus_config() {
    log_info "Prometheus 설정 파일 생성 중..."
    
    mkdir -p monitoring/prometheus
    
    cat > monitoring/prometheus/prometheus.yml << EOF
global:
  scrape_interval: 15s
  evaluation_interval: 15s

rule_files:
  - "rules/*.yml"

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

  - job_name: 'kubernetes-pods'
    kubernetes_sd_configs:
      - role: pod
    relabel_configs:
      - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
        action: keep
        regex: true
      - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_path]
        action: replace
        target_label: __metrics_path__
        regex: (.+)
      - source_labels: [__address__, __meta_kubernetes_pod_annotation_prometheus_io_port]
        action: replace
        regex: ([^:]+)(?::\d+)?;(\d+)
        replacement: \$1:\$2
        target_label: __address__
      - action: labelmap
        regex: __meta_kubernetes_pod_label_(.+)
      - source_labels: [__meta_kubernetes_namespace]
        action: replace
        target_label: kubernetes_namespace
      - source_labels: [__meta_kubernetes_pod_name]
        action: replace
        target_label: kubernetes_pod_name
EOF
    
    log_success "Prometheus 설정 파일 생성 완료"
}

# AlertManager 설정 파일 생성
create_alertmanager_config() {
    log_info "AlertManager 설정 파일 생성 중..."
    
    mkdir -p monitoring/alertmanager
    
    cat > monitoring/alertmanager/alertmanager.yml << EOF
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
    
    log_success "AlertManager 설정 파일 생성 완료"
}

# Grafana 설정 파일 생성
create_grafana_config() {
    log_info "Grafana 설정 파일 생성 중..."
    
    mkdir -p monitoring/grafana/provisioning/datasources
    mkdir -p monitoring/grafana/provisioning/dashboards
    
    # 데이터 소스 설정
    cat > monitoring/grafana/provisioning/datasources/prometheus.yml << EOF
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
    editable: true
EOF
    
    # 대시보드 설정
    cat > monitoring/grafana/provisioning/dashboards/dashboard.yml << EOF
apiVersion: 1

providers:
  - name: 'default'
    orgId: 1
    folder: ''
    type: file
    disableDeletion: false
    updateIntervalSeconds: 10
    allowUiUpdates: true
    options:
      path: /var/lib/grafana/dashboards
EOF
    
    log_success "Grafana 설정 파일 생성 완료"
}

# Docker Compose 파일 생성
create_docker_compose() {
    log_info "Docker Compose 파일 생성 중..."
    
    cat > monitoring/docker-compose.yml << EOF
version: '3.8'

services:
  prometheus:
    image: prom/prometheus:latest
    container_name: prometheus
    ports:
      - "$PROMETHEUS_PORT:9090"
    volumes:
      - ./prometheus/prometheus.yml:/etc/prometheus/prometheus.yml
      - ./prometheus/rules:/etc/prometheus/rules
      - prometheus_data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--web.console.libraries=/etc/prometheus/console_libraries'
      - '--web.console.templates=/etc/prometheus/consoles'
      - '--storage.tsdb.retention.time=200h'
      - '--web.enable-lifecycle'
    restart: unless-stopped

  grafana:
    image: grafana/grafana:latest
    container_name: grafana
    ports:
      - "$GRAFANA_PORT:3000"
    volumes:
      - grafana_data:/var/lib/grafana
      - ./grafana/provisioning:/etc/grafana/provisioning
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin
      - GF_USERS_ALLOW_SIGN_UP=false
    restart: unless-stopped

  node-exporter:
    image: prom/node-exporter:latest
    container_name: node-exporter
    ports:
      - "$NODE_EXPORTER_PORT:9100"
    volumes:
      - /proc:/host/proc:ro
      - /sys:/host/sys:ro
      - /:/rootfs:ro
    command:
      - '--path.procfs=/host/proc'
      - '--path.rootfs=/rootfs'
      - '--path.sysfs=/host/sys'
      - '--collector.filesystem.mount-points-exclude=^/(sys|proc|dev|host|etc)($$|/)'
    restart: unless-stopped

  alertmanager:
    image: prom/alertmanager:latest
    container_name: alertmanager
    ports:
      - "$ALERTMANAGER_PORT:9093"
    volumes:
      - ./alertmanager/alertmanager.yml:/etc/alertmanager/alertmanager.yml
      - alertmanager_data:/alertmanager
    command:
      - '--config.file=/etc/alertmanager/alertmanager.yml'
      - '--storage.path=/alertmanager'
      - '--web.external-url=http://localhost:9093'
    restart: unless-stopped

volumes:
  prometheus_data:
  grafana_data:
  alertmanager_data:
EOF
    
    log_success "Docker Compose 파일 생성 완료"
}

# Kubernetes 매니페스트 생성
create_k8s_manifests() {
    if [ "$K8S_MODE" = "false" ]; then
        return 0
    fi
    
    log_info "Kubernetes 매니페스트 생성 중..."
    
    # Prometheus ConfigMap
    cat > monitoring/k8s/prometheus-configmap.yml << EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: prometheus-config
  namespace: $NAMESPACE
data:
  prometheus.yml: |
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
EOF
    
    # Prometheus Deployment
    cat > monitoring/k8s/prometheus-deployment.yml << EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: prometheus
  namespace: $NAMESPACE
spec:
  replicas: 1
  selector:
    matchLabels:
      app: prometheus
  template:
    metadata:
      labels:
        app: prometheus
    spec:
      containers:
      - name: prometheus
        image: prom/prometheus:latest
        ports:
        - containerPort: 9090
        volumeMounts:
        - name: config
          mountPath: /etc/prometheus
        - name: storage
          mountPath: /prometheus
      volumes:
      - name: config
        configMap:
          name: prometheus-config
      - name: storage
        emptyDir: {}
EOF
    
    # Prometheus Service
    cat > monitoring/k8s/prometheus-service.yml << EOF
apiVersion: v1
kind: Service
metadata:
  name: prometheus
  namespace: $NAMESPACE
spec:
  selector:
    app: prometheus
  ports:
  - port: 9090
    targetPort: 9090
  type: LoadBalancer
EOF
    
    # Grafana Deployment
    cat > monitoring/k8s/grafana-deployment.yml << EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: grafana
  namespace: $NAMESPACE
spec:
  replicas: 1
  selector:
    matchLabels:
      app: grafana
  template:
    metadata:
      labels:
        app: grafana
    spec:
      containers:
      - name: grafana
        image: grafana/grafana:latest
        ports:
        - containerPort: 3000
        env:
        - name: GF_SECURITY_ADMIN_PASSWORD
          value: "admin"
        volumeMounts:
        - name: storage
          mountPath: /var/lib/grafana
      volumes:
      - name: storage
        emptyDir: {}
EOF
    
    # Grafana Service
    cat > monitoring/k8s/grafana-service.yml << EOF
apiVersion: v1
kind: Service
metadata:
  name: grafana
  namespace: $NAMESPACE
spec:
  selector:
    app: grafana
  ports:
  - port: 3000
    targetPort: 3000
  type: LoadBalancer
EOF
    
    log_success "Kubernetes 매니페스트 생성 완료"
}

# Docker 모드 배포
deploy_docker() {
    log_info "Docker 모드로 모니터링 스택 배포 중..."
    
    cd monitoring
    
    # Docker Compose 실행
    docker-compose up -d
    
    if [ $? -eq 0 ]; then
        PROMETHEUS_DEPLOYED="true"
        GRAFANA_DEPLOYED="true"
        NODE_EXPORTER_DEPLOYED="true"
        ALERTMANAGER_DEPLOYED="true"
        log_success "Docker 모니터링 스택 배포 완료"
    else
        log_error "Docker 모니터링 스택 배포 실패"
        exit 1
    fi
    
    cd ..
}

# Kubernetes 모드 배포
deploy_k8s() {
    log_info "Kubernetes 모드로 모니터링 스택 배포 중..."
    
    # 네임스페이스 생성
    create_namespace
    
    # Prometheus 배포
    kubectl apply -f monitoring/k8s/prometheus-configmap.yml
    kubectl apply -f monitoring/k8s/prometheus-deployment.yml
    kubectl apply -f monitoring/k8s/prometheus-service.yml
    
    if [ $? -eq 0 ]; then
        PROMETHEUS_DEPLOYED="true"
        log_success "Prometheus 배포 완료"
    fi
    
    # Grafana 배포
    kubectl apply -f monitoring/k8s/grafana-deployment.yml
    kubectl apply -f monitoring/k8s/grafana-service.yml
    
    if [ $? -eq 0 ]; then
        GRAFANA_DEPLOYED="true"
        log_success "Grafana 배포 완료"
    fi
    
    # Node Exporter 배포
    kubectl create -f - <<EOF
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: node-exporter
  namespace: $NAMESPACE
spec:
  selector:
    matchLabels:
      app: node-exporter
  template:
    metadata:
      labels:
        app: node-exporter
    spec:
      containers:
      - name: node-exporter
        image: prom/node-exporter:latest
        ports:
        - containerPort: 9100
        volumeMounts:
        - name: proc
          mountPath: /host/proc
          readOnly: true
        - name: sys
          mountPath: /host/sys
          readOnly: true
      volumes:
      - name: proc
        hostPath:
          path: /proc
      - name: sys
        hostPath:
          path: /sys
EOF
    
    if [ $? -eq 0 ]; then
        NODE_EXPORTER_DEPLOYED="true"
        log_success "Node Exporter 배포 완료"
    fi
}

# 배포 상태 확인
check_deployment_status() {
    log_info "배포 상태 확인 중..."
    
    if [ "$K8S_MODE" = "true" ]; then
        # Kubernetes 상태 확인
        log_info "Kubernetes Pod 상태:"
        kubectl get pods -n "$NAMESPACE"
        
        log_info "Kubernetes Service 상태:"
        kubectl get services -n "$NAMESPACE"
        
        # 외부 IP 확인
        PROMETHEUS_IP=$(kubectl get service prometheus -n "$NAMESPACE" -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
        GRAFANA_IP=$(kubectl get service grafana -n "$NAMESPACE" -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
        
        if [ ! -z "$PROMETHEUS_IP" ]; then
            log_info "Prometheus 접속: http://$PROMETHEUS_IP:9090"
        fi
        
        if [ ! -z "$GRAFANA_IP" ]; then
            log_info "Grafana 접속: http://$GRAFANA_IP:3000 (admin/admin)"
        fi
    else
        # Docker 상태 확인
        log_info "Docker 컨테이너 상태:"
        docker ps --filter "name=prometheus\|grafana\|node-exporter\|alertmanager"
        
        log_info "모니터링 스택 접속 정보:"
        log_info "Prometheus: http://localhost:$PROMETHEUS_PORT"
        log_info "Grafana: http://localhost:$GRAFANA_PORT (admin/admin)"
        log_info "AlertManager: http://localhost:$ALERTMANAGER_PORT"
        log_info "Node Exporter: http://localhost:$NODE_EXPORTER_PORT"
    fi
}

# 정리 함수
cleanup() {
    log_info "정리 중..."
    
    if [ "$K8S_MODE" = "true" ]; then
        # Kubernetes 리소스 정리
        kubectl delete namespace "$NAMESPACE" --ignore-not-found=true
    else
        # Docker 컨테이너 정리
        cd monitoring
        docker-compose down -v
        cd ..
    fi
    
    # 체크포인트 파일 삭제
    rm -f "$CHECKPOINT_FILE"
    
    log_success "정리 완료"
}

# 메인 함수
main() {
    log_info "=== Cloud Master Day3 - 모니터링 스택 배포 시작 ==="
    
    # 체크포인트 로드
    load_checkpoint
    
    # 환경 체크
    check_environment
    
    # 설정 파일 생성
    create_prometheus_config
    create_alertmanager_config
    create_grafana_config
    
    if [ "$K8S_MODE" = "true" ]; then
        create_k8s_manifests
        deploy_k8s
    else
        create_docker_compose
        deploy_docker
    fi
    
    save_checkpoint
    
    # 배포 상태 확인
    check_deployment_status
    
    log_success "=== 모니터링 스택 배포 완료 ==="
    log_info "Prometheus: 메트릭 수집 및 저장"
    log_info "Grafana: 대시보드 및 시각화"
    log_info "Node Exporter: 시스템 메트릭 수집"
    log_info "AlertManager: 알림 관리"
    
    log_info "다음 단계:"
    log_info "1. Grafana에 접속하여 대시보드 설정"
    log_info "2. Prometheus에서 메트릭 쿼리 테스트"
    log_info "3. AlertManager에서 알림 규칙 설정"
}

# 스크립트 실행
if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    main "$@"
fi
