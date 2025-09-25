# Actions Demo - 고급 CI/CD 파이프라인

## 🎯 프로젝트 개요

이 프로젝트는 Day3에서 학습하는 고급 CI/CD 파이프라인을 보여주는 데모 프로젝트입니다. 로드 밸런싱, Auto Scaling, 모니터링이 통합된 완전 자동화된 배포 파이프라인을 구현합니다.

### 주요 기능
- **고급 CI/CD**: 로드 밸런서 + Auto Scaling 통합 배포
- **Blue-Green 배포**: 무중단 배포 전략
- **Canary 배포**: 점진적 배포 및 롤백
- **모니터링 통합**: 배포 후 자동 모니터링 설정
- **장애 복구**: 자동 롤백 및 복구

## 🏗️ 고급 CI/CD 파이프라인 아키텍처

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Code Push     │    │   Build & Test  │    │   Deploy        │
│   [GitHub]      │───►│   [Actions]     │───►│   [K8s + LB]    │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         │                       │                       │
         ▼                       ▼                       ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Security      │    │   Performance   │    │   Monitoring    │
│   [CodeQL]      │    │   [Load Test]   │    │   [Prometheus]  │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         │                       │                       │
         ▼                       ▼                       ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Blue-Green    │    │   Canary        │    │   Auto Rollback │
│   Deployment    │    │   Deployment    │    │   & Recovery    │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

## 🚀 시작하기

### 필수 요구사항
- GitHub 계정
- AWS 계정 [ELB, Auto Scaling]
- GCP 계정 [Cloud Load Balancing, MIG]
- Kubernetes 클러스터 ["EKS, GKE, 또는 로컬"]

### 환경 설정

#### 1. 저장소 포크 및 클론
```bash
# GitHub에서 이 저장소를 포크
git clone <your-forked-repository>
cd actions-demo
```

#### 2. 시크릿 설정
GitHub 저장소 Settings > Secrets and variables > Actions에서 다음 시크릿을 설정:

```bash
# AWS 인증
AWS_ACCESS_KEY_ID=your-aws-access-key
AWS_SECRET_ACCESS_KEY=your-aws-secret-key
AWS_REGION=ap-northeast-2

# GCP 인증
GCP_PROJECT_ID=your-gcp-project-id
GCP_SA_KEY=base64-encoded-service-account-key

# Kubernetes 클러스터
KUBE_CONFIG_AWS=base64-encoded-aws-kubeconfig
KUBE_CONFIG_GCP=base64-encoded-gcp-kubeconfig

# 모니터링
PROMETHEUS_URL=https:///prometheus.example.com
GRAFANA_URL=https:///grafana.example.com
GRAFANA_API_KEY=your-grafana-api-key

# 알림
SLACK_WEBHOOK_URL=https:///hooks.slack.com/services/...
DISCORD_WEBHOOK_URL=https:///discord.com/api/webhooks/...
```

## 📁 프로젝트 구조

```
actions-demo/
├── .github/
│   └── workflows/
│       ├── ci.yml                    # 지속적 통합
│       ├── cd-blue-green.yml         # Blue-Green 배포
│       ├── cd-canary.yml             # Canary 배포
│       ├── security-scan.yml         # 보안 스캔
│       ├── performance-test.yml      # 성능 테스트
│       ├── monitoring-setup.yml      # 모니터링 설정
│       └── disaster-recovery.yml     # 재해 복구
├── infrastructure/                   # Infrastructure as Code
│   ├── aws/
│   │   ├── terraform/
│   │   └── cloudformation/
│   ├── gcp/
│   │   └── terraform/
│   └── k8s/
│       ├── base/
│       └── overlays/
├── monitoring/                       # 모니터링 설정
│   ├── prometheus/
│   ├── grafana/
│   └── alertmanager/
├── tests/                           # 테스트 스크립트
│   ├── load-test.js
│   ├── stress-test.js
│   └── chaos-test.js
├── scripts/                         # 배포 및 관리 스크립트
│   ├── deploy-blue-green.sh
│   ├── deploy-canary.sh
│   ├── rollback.sh
│   └── health-check.sh
├── src/                             # 애플리케이션 소스
│   ├── app.py
│   ├── requirements.txt
│   └── tests/
├── docker-compose.yml
├── Dockerfile
└── README.md
```

## 🔧 고급 CI/CD 워크플로우

### 1. Blue-Green 배포
```yaml
# .github/workflows/cd-blue-green.yml
name: Blue-Green Deployment

on:
  push:
    branches: [main]
  workflow_dispatch:
    inputs:
      environment:
        description: 'Deployment environment'
        required: true
        default: 'production'
        type: choice
        options:
        - staging
        - production

jobs:
  blue-green-deploy:
    runs-on: ubuntu-latest
    environment: ${{ github.event.inputs.environment || 'production' }}
    
    steps:
    - uses: actions/checkout@v3
    
    - name: Build Docker image
      run: |
        docker build -t my-app:${{ github.sha }} .
        docker tag my-app:${{ github.sha }} my-app:latest
    
    - name: Push to registry
      run: |
        echo ${{ secrets.DOCKER_PASSWORD }} | docker login -u ${{ secrets.DOCKER_USERNAME }} --password-stdin
        docker push my-app:${{ github.sha }}
        docker push my-app:latest
    
    - name: Deploy to Blue environment
      run: |
        kubectl apply -f k8s/overlays/${{ github.event.inputs.environment || 'production' }}/blue/
        kubectl rollout status deployment/my-app-blue
    
    - name: Run health checks
      run: |
        ./scripts/health-check.sh blue
    
    - name: Switch traffic to Blue
      run: |
        kubectl patch service my-app-service -p '{"spec":{"selector":{"version":"blue"}}}'
    
    - name: Wait for traffic switch
      run: |
        sleep 30
        ./scripts/health-check.sh blue
    
    - name: Clean up Green environment
      run: |
        kubectl delete -f k8s/overlays/${{ github.event.inputs.environment || 'production' }}/green/ || true
```

### 2. Canary 배포
```yaml
# .github/workflows/cd-canary.yml
name: Canary Deployment

on:
  push:
    branches: [develop]
  workflow_dispatch:
    inputs:
      canary_percentage:
        description: 'Canary traffic percentage'
        required: true
        default: '10'
        type: string

jobs:
  canary-deploy:
    runs-on: ubuntu-latest
    
    steps:
    - uses: actions/checkout@v3
    
    - name: Build Docker image
      run: |
        docker build -t my-app:${{ github.sha }} .
        docker tag my-app:${{ github.sha }} my-app:latest
    
    - name: Deploy Canary
      run: |
        kubectl apply -f k8s/overlays/canary/
        kubectl set image deployment/my-app-canary my-app=my-app:${{ github.sha }}
        kubectl rollout status deployment/my-app-canary
    
    - name: Configure traffic splitting
      run: |
        kubectl apply -f - <<EOF
        apiVersion: networking.istio.io/v1alpha3
        kind: VirtualService
        metadata:
          name: my-app
        spec:
          http:
          - route:
            - destination:
                host: my-app
                subset: stable
              weight: ${{ 100 - github.event.inputs.canary_percentage }}
            - destination:
                host: my-app
                subset: canary
              weight: ${{ github.event.inputs.canary_percentage }}
        EOF
    
    - name: Monitor canary metrics
      run: |
        ./scripts/monitor-canary.sh ${{ github.event.inputs.canary_percentage }}
    
    - name: Promote canary or rollback
      run: |
        if ./scripts/check-canary-health.sh; then
          echo "Canary is healthy, promoting to stable"
          kubectl patch service my-app-service -p '{"spec":{"selector":{"version":"stable"}}}'
        else
          echo "Canary is unhealthy, rolling back"
          kubectl patch service my-app-service -p '{"spec":{"selector":{"version":"stable"}}}'
          exit 1
        fi
```

### 3. 모니터링 설정
```yaml
# .github/workflows/monitoring-setup.yml
name: Monitoring Setup

on:
  workflow_run:
    workflows: ["Blue-Green Deployment", "Canary Deployment"]
    types: [completed]

jobs:
  setup-monitoring:
    runs-on: ubuntu-latest
    if: ${{ github.event.workflow_run.conclusion == 'success' }}
    
    steps:
    - uses: actions/checkout@v3
    
    - name: Deploy Prometheus
      run: |
        kubectl apply -f monitoring/prometheus/
        kubectl rollout status deployment/prometheus
    
    - name: Deploy Grafana
      run: |
        kubectl apply -f monitoring/grafana/
        kubectl rollout status deployment/grafana
    
    - name: Configure Grafana dashboards
      run: |
        ./scripts/setup-grafana-dashboards.sh
    
    - name: Setup alerting rules
      run: |
        kubectl apply -f monitoring/alertmanager/
        ./scripts/configure-alerts.sh
    
    - name: Send deployment notification
      run: |
        curl -X POST -H 'Content-type: application/json' /
          --data '{"text":"🚀 Deployment completed successfully! Monitoring is now active."}' /
          ${{ secrets.SLACK_WEBHOOK_URL }}
```

### 4. 재해 복구
```yaml
# .github/workflows/disaster-recovery.yml
name: Disaster Recovery

on:
  workflow_dispatch:
    inputs:
      recovery_type:
        description: 'Recovery type'
        required: true
        default: 'rollback'
        type: choice
        options:
        - rollback
        - failover
        - restore

jobs:
  disaster-recovery:
    runs-on: ubuntu-latest
    
    steps:
    - uses: actions/checkout@v3
    
    - name: Check current deployment status
      run: |
        kubectl get deployments
        kubectl get services
        kubectl get pods
    
    - name: Execute recovery based on type
      run: |
        case "${{ github.event.inputs.recovery_type }}" in
          "rollback")
            ./scripts/rollback.sh
            ;;
          "failover")
            ./scripts/failover.sh
            ;;
          "restore")
            ./scripts/restore.sh
            ;;
        esac
    
    - name: Verify recovery
      run: |
        ./scripts/health-check.sh
        ./scripts/verify-recovery.sh
    
    - name: Send recovery notification
      run: |
        curl -X POST -H 'Content-type: application/json' /
          --data '{"text":"🔄 Disaster recovery completed: ${{ github.event.inputs.recovery_type }}"}' /
          ${{ secrets.SLACK_WEBHOOK_URL }}
```

## 🧪 고급 테스트

### 1. 카오스 엔지니어링
```javascript
// tests/chaos-test.js
import http from 'k6/http';
import { check, sleep } from 'k6';

export let options = {
  stages: [
    { duration: '2m', target: 100 },
    { duration: '5m', target: 100 },
    { duration: '2m', target: 0 },
  ],
  thresholds: {
    http_req_duration: ['p[95]<1000'],
    http_req_failed: ['rate<0.1'],
  },
};

export default function() {
  // 정상 요청
  let response = http.get['http://load-balancer/'];
  check[response, {
    'status is 200': [r] => r.status === 200,
  }];
  
  // 장애 시뮬레이션 ["10% 확률"]
  if [Math.random[] < 0.1] {
    // 네트워크 지연 시뮬레이션
    sleep[2];
  }
  
  sleep[1];
}
```

### 2. 부하 테스트
```javascript
// tests/load-test.js
import http from 'k6/http';
import { check, sleep } from 'k6';

export let options = {
  stages: [
    { duration: '1m', target: 50 },
    { duration: '2m', target: 100 },
    { duration: '2m', target: 200 },
    { duration: '2m', target: 300 },
    { duration: '2m', target: 400 },
    { duration: '2m', target: 500 },
    { duration: '5m', target: 0 },
  ],
  thresholds: {
    http_req_duration: ['p[95]<500'],
    http_req_failed: ['rate<0.05'],
  },
};

export default function() {
  let response = http.get['http://load-balancer/'];
  check[response, {
    'status is 200': [r] => r.status === 200,
    'response time < 500ms': [r] => r.timings.duration < 500,
  }];
  sleep[1];
}
```

### 3. 스트레스 테스트
```javascript
// tests/stress-test.js
import http from 'k6/http';
import { check, sleep } from 'k6';

export let options = {
  stages: [
    { duration: '1m', target: 100 },
    { duration: '2m', target: 200 },
    { duration: '2m', target: 400 },
    { duration: '2m', target: 600 },
    { duration: '2m', target: 800 },
    { duration: '2m', target: 1000 },
    { duration: '5m', target: 0 },
  ],
  thresholds: {
    http_req_duration: ['p[95]<1000'],
    http_req_failed: ['rate<0.2'],
  },
};

export default function() {
  let response = http.get['http://load-balancer/'];
  check[response, {
    'status is 200': [r] => r.status === 200,
  }];
  sleep[1];
}
```

## 📊 모니터링 및 알림

### 1. Prometheus 알림 규칙
```yaml
# monitoring/prometheus/alerts.yml
groups:
- name: my-app
  rules:
  - alert: HighErrorRate
    expr: rate[http_requests_total{status=~"5.."}[5m]] > 0.1
    for: 2m
    labels:
      severity: critical
    annotations:
      summary: "High error rate detected"
      description: "Error rate is {{ $value }} errors per second"
  
  - alert: HighResponseTime
    expr: histogram_quantile[0.95, rate[http_request_duration_seconds_bucket[5m]]] > 1
    for: 2m
    labels:
      severity: warning
    annotations:
      summary: "High response time detected"
      description: "95th percentile response time is {{ $value }} seconds"
  
  - alert: PodCrashLooping
    expr: rate[kube_pod_container_status_restarts_total[15m]] > 0
    for: 2m
    labels:
      severity: critical
    annotations:
      summary: "Pod is crash looping"
      description: "Pod {{ $labels.pod }} is restarting frequently"
```

### 2. Grafana 대시보드
```json
{
  "dashboard": {
    "title": "My App Production Dashboard",
    "panels": [
      {
        "title": "Request Rate",
        "type": "graph",
        "targets": [
          {
            "expr": "rate[http_requests_total[5m]]",
            "legendFormat": "{{instance}}"
          }
        ]
      },
      {
        "title": "Error Rate",
        "type": "graph",
        "targets": [
          {
            "expr": "rate[http_requests_total{status=~/"5../"}[5m]]",
            "legendFormat": "5xx Errors"
          }
        ]
      },
      {
        "title": "Response Time",
        "type": "graph",
        "targets": [
          {
            "expr": "histogram_quantile[0.95, rate[http_request_duration_seconds_bucket[5m]]]",
            "legendFormat": "95th percentile"
          }
        ]
      },
      {
        "title": "Pod Status",
        "type": "table",
        "targets": [
          {
            "expr": "kube_pod_status_phase",
            "format": "table"
          }
        ]
      }
    ]
  }
}
```

## 🔗 관련 자료

- ["GitHub Actions 공식 문서"][https:///docs.github.com/en/actions]
- ["Kubernetes 공식 문서"][https:///kubernetes.io/docs/]
- ["Istio 공식 문서"][https:///istio.io/latest/docs/]
- ["Prometheus 공식 문서"][https:///prometheus.io/docs/]
- ["Grafana 공식 문서"][https:///grafana.com/docs/]
- ["k6 성능 테스트"][https:///k6.io/]
