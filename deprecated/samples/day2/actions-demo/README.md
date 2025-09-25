# Actions Demo - 고급 CI/CD 파이프라인

## 🎯 프로젝트 개요

이 프로젝트는 Day2에서 학습하는 고급 GitHub Actions 워크플로우를 보여주는 데모 프로젝트입니다.

### 주요 기능
- **매트릭스 빌드**: 여러 환경에서 동시 빌드
- **환경별 배포**: 개발, 스테이징, 프로덕션 환경 분리
- **보안 스캔**: 코드 보안 취약점 검사
- **성능 테스트**: 자동화된 성능 테스트

## 🏗️ CI/CD 파이프라인 아키텍처

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Code Push     │    │   Build & Test  │    │   Deploy        │
│   [GitHub]      │───►│   [Actions]     │───►│   [Kubernetes]  │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         │                       │                       │
         ▼                       ▼                       ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Security      │    │   Performance   │    │   Monitoring    │
│   [CodeQL]      │    │   [Load Test]   │    │   [Prometheus]  │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

## 🚀 시작하기

### 필수 요구사항
- GitHub 계정
- Docker Hub 계정 ["또는 GitHub Container Registry"]
- Kubernetes 클러스터 ["GKE, EKS, 또는 로컬"]

### 설정

#### 1. 저장소 포크
```bash
# GitHub에서 이 저장소를 포크
# 또는 로컬에 클론
git clone <your-forked-repository>
cd actions-demo
```

#### 2. 시크릿 설정
GitHub 저장소 Settings > Secrets and variables > Actions에서 다음 시크릿을 설정:

```bash
# Docker Hub 인증
DOCKER_USERNAME=your-dockerhub-username
DOCKER_PASSWORD=your-dockerhub-password

# Kubernetes 클러스터 인증
KUBE_CONFIG=base64-encoded-kubeconfig

# 환경별 설정
DEV_DATABASE_URL=postgresql://dev-db-url
STAGING_DATABASE_URL=postgresql://staging-db-url
PROD_DATABASE_URL=postgresql://prod-db-url
```

## 📁 프로젝트 구조

```
actions-demo/
├── .github/
│   └── workflows/
│       ├── ci.yml              # 지속적 통합
│       ├── cd.yml              # 지속적 배포
│       ├── security.yml        # 보안 스캔
│       ├── performance.yml     # 성능 테스트
│       └── matrix-build.yml    # 매트릭스 빌드
├── src/                        # 애플리케이션 소스
│   ├── app.py
│   ├── requirements.txt
│   └── tests/
├── k8s/                        # Kubernetes 매니페스트
│   ├── dev/
│   ├── staging/
│   └── prod/
├── scripts/                    # 유틸리티 스크립트
│   ├── deploy.sh
│   ├── test.sh
│   └── cleanup.sh
├── Dockerfile
├── docker-compose.yml
└── README.md
```

## 🔧 고급 GitHub Actions 워크플로우

### 1. 매트릭스 빌드
```yaml
# .github/workflows/matrix-build.yml
name: Matrix Build

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

jobs:
  matrix-build:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        python-version: [3.8, 3.9, 3.10, 3.11]
        os: [ubuntu-latest, windows-latest, macos-latest]
        include:
          - python-version: 3.9
            os: ubuntu-latest
            node-version: 16
          - python-version: 3.10
            os: ubuntu-latest
            node-version: 18
    
    steps:
    - uses: actions/checkout@v3
    
    - name: Set up Python ${{ matrix.python-version }}
      uses: actions/setup-python@v4
      with:
        python-version: ${{ matrix.python-version }}
    
    - name: Set up Node.js ${{ matrix.node-version }}
      if: matrix.node-version
      uses: actions/setup-node@v3
      with:
        node-version: ${{ matrix.node-version }}
    
    - name: Install dependencies
      run: |
        pip install -r requirements.txt
        if [ "${{ matrix.node-version }}" ]; then
          npm install
        fi
    
    - name: Run tests
      run: |
        python -m pytest tests/
        if [ "${{ matrix.node-version }}" ]; then
          npm test
        fi
```

### 2. 환경별 배포
```yaml
# .github/workflows/cd.yml
name: Continuous Deployment

on:
  push:
    branches: [main, develop]
  workflow_dispatch:
    inputs:
      environment:
        description: 'Deployment environment'
        required: true
        default: 'staging'
        type: choice
        options:
        - staging
        - production

jobs:
  deploy:
    runs-on: ubuntu-latest
    environment: ${{ github.event.inputs.environment || [github.ref == 'refs/heads/main' && 'production'] || 'staging' }}
    
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
    
    - name: Deploy to Kubernetes
      run: |
        echo "${{ secrets.KUBE_CONFIG }}" | base64 -d > kubeconfig
        export KUBECONFIG=kubeconfig
        
        # 환경별 설정 적용
        envsubst < k8s/${{ github.event.inputs.environment || [github.ref == 'refs/heads/main' && 'prod'] || 'staging' }}/deployment.yaml | kubectl apply -f -
        kubectl rollout status deployment/my-app
```

### 3. 보안 스캔
```yaml
# .github/workflows/security.yml
name: Security Scan

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]
  schedule:
    - cron: '0 2 * * 1'  # 매주 월요일 오전 2시

jobs:
  security-scan:
    runs-on: ubuntu-latest
    
    steps:
    - uses: actions/checkout@v3
    
    - name: CodeQL Analysis
      uses: github/codeql-action/init@v2
      with:
        languages: python, javascript
    
    - name: Perform CodeQL Analysis
      uses: github/codeql-action/analyze@v2
    
    - name: Run Trivy vulnerability scanner
      uses: aquasecurity/trivy-action@master
      with:
        scan-type: 'fs'
        scan-ref: '.'
        format: 'sarif'
        output: 'trivy-results.sarif'
    
    - name: Upload Trivy scan results
      uses: github/codeql-action/upload-sarif@v2
      with:
        sarif_file: 'trivy-results.sarif'
    
    - name: Run Snyk security scan
      uses: snyk/actions/python@master
      env:
        SNYK_TOKEN: ${{ secrets.SNYK_TOKEN }}
      with:
        args: --severity-threshold=high
```

### 4. 성능 테스트
```yaml
# .github/workflows/performance.yml
name: Performance Test

on:
  push:
    branches: [main]
  workflow_dispatch:

jobs:
  performance-test:
    runs-on: ubuntu-latest
    
    steps:
    - uses: actions/checkout@v3
    
    - name: Deploy test environment
      run: |
        docker-compose up -d
        sleep 30  # 애플리케이션 시작 대기
    
    - name: Run load test
      uses: grafana/k6-action@v0.3.1
      with:
        filename: tests/load-test.js
        options: '--out json=results.json'
    
    - name: Run stress test
      uses: grafana/k6-action@v0.3.1
      with:
        filename: tests/stress-test.js
        options: '--out json=stress-results.json'
    
    - name: Upload test results
      uses: actions/upload-artifact@v3
      with:
        name: performance-results
        path: |
          results.json
          stress-results.json
```

## 🧪 테스트 스크립트

### 로드 테스트
```javascript
// tests/load-test.js
import http from 'k6/http';
import { check, sleep } from 'k6';

export let options = {
  stages: [
    { duration: '2m', target: 100 }, // Ramp up
    { duration: '5m', target: 100 }, // Stay at 100 users
    { duration: '2m', target: 0 },   // Ramp down
  ],
  thresholds: {
    http_req_duration: ['p[95]<500'], // 95% of requests under 500ms
    http_req_failed: ['rate<0.1'],    // Error rate under 10%
  },
};

export default function() {
  let response = http.get['http://localhost:8000/'];
  check[response, {
    'status is 200': [r] => r.status === 200,
    'response time < 500ms': [r] => r.timings.duration < 500,
  }];
  sleep[1];
}
```

### 스트레스 테스트
```javascript
// tests/stress-test.js
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
    http_req_duration: ['p[95]<1000'],
    http_req_failed: ['rate<0.2'],
  },
};

export default function() {
  let response = http.get['http://localhost:8000/'];
  check[response, {
    'status is 200': [r] => r.status === 200,
  }];
  sleep[1];
}
```

## 📊 모니터링 및 알림

### Slack 알림 설정
```yaml
# .github/workflows/notify.yml
name: Notify

on:
  workflow_run:
    workflows: ["CI", "CD", "Security Scan"]
    types: [completed]

jobs:
  notify:
    runs-on: ubuntu-latest
    if: ${{ github.event.workflow_run.conclusion != 'success' }}
    
    steps:
    - name: Notify Slack
      uses: 8398a7/action-slack@v3
      with:
        status: ${{ github.event.workflow_run.conclusion }}
        channel: '#deployments'
        webhook_url: ${{ secrets.SLACK_WEBHOOK }}
```

### 이메일 알림 설정
```yaml
# .github/workflows/email-notify.yml
name: Email Notification

on:
  workflow_run:
    workflows: ["CD"]
    types: [completed]

jobs:
  email-notify:
    runs-on: ubuntu-latest
    
    steps:
    - name: Send email
      uses: dawidd6/action-send-mail@v3
      with:
        server_address: smtp.gmail.com
        server_port: 587
        username: ${{ secrets.EMAIL_USERNAME }}
        password: ${{ secrets.EMAIL_PASSWORD }}
        subject: 'Deployment Status: ${{ github.event.workflow_run.conclusion }}'
        to: ${{ secrets.EMAIL_TO }}
        from: GitHub Actions
        body: |
          Workflow: ${{ github.event.workflow_run.name }}
          Status: ${{ github.event.workflow_run.conclusion }}
          URL: ${{ github.event.workflow_run.html_url }}
```

## 🔗 관련 자료

- ["GitHub Actions 공식 문서"][https:///docs.github.com/en/actions]
- ["CodeQL 공식 문서"][https:///codeql.github.com/]
- ["Trivy 보안 스캐너"][https:///trivy.dev/]
- ["k6 성능 테스트"][https:///k6.io/]
- ["Kubernetes 공식 문서"][https:///kubernetes.io/docs/]
