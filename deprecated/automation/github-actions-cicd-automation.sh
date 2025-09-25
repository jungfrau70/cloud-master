#!/bin/bash

# GitHub Actions CI/CD 자동화 스크립트
# Cloud Master 과정용 GitHub Actions CI/CD 파이프라인 자동 설정 도구

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

# 스크립트 설정
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
WORKFLOWS_DIR="$PROJECT_ROOT/.github/workflows"

# 기본 설정
DEFAULT_PROJECT_NAME="github-actions-cicd-practice"
DEFAULT_NODE_VERSION="18"
DEFAULT_DOCKER_USERNAME=""
DEFAULT_AWS_REGION="us-west-2"
DEFAULT_GCP_REGION="us-central1"

# 사용법 출력
usage() {
    echo "GitHub Actions CI/CD 자동화 스크립트"
    echo ""
    echo "사용법: $0 [옵션]"
    echo ""
    echo "옵션:"
    echo "  -n, --name NAME           프로젝트 이름 (기본값: $DEFAULT_PROJECT_NAME)"
    echo "  -v, --node-version VER    Node.js 버전 (기본값: $DEFAULT_NODE_VERSION)"
    echo "  -d, --docker-user USER    Docker Hub 사용자명"
    echo "  -a, --aws-region REGION   AWS 리전 (기본값: $DEFAULT_AWS_REGION)"
    echo "  -g, --gcp-region REGION   GCP 리전 (기본값: $DEFAULT_GCP_REGION)"
    echo "  -s, --skill-level LEVEL   실습 난이도 (초급/중급/고급)"
    echo "  -b, --budget BUDGET       예산 한도 (USD)"
    echo "  -c, --cloud-provider      클라우드 프로바이더 (aws/gcp/both)"
    echo "  --setup-only              설정만 생성 (실행하지 않음)"
    echo "  --cleanup                 생성된 리소스 정리"
    echo "  -h, --help                도움말 표시"
    echo ""
    echo "예시:"
    echo "  $0 --name my-app --docker-user myuser --skill-level 중급"
    echo "  $0 --cloud-provider both --budget 100"
    echo "  $0 --cleanup"
}

# 환경 체크
check_environment() {
    log_info "환경 체크 시작..."
    
    local missing_tools=()
    
    # 필수 도구 체크
    if ! command -v git &> /dev/null; then
        missing_tools+=("git")
    fi
    
    if ! command -v docker &> /dev/null; then
        missing_tools+=("docker")
    fi
    
    if ! command -v aws &> /dev/null; then
        missing_tools+=("aws")
    fi
    
    if ! command -v gcloud &> /dev/null; then
        missing_tools+=("gcloud")
    fi
    
    if ! command -v kubectl &> /dev/null; then
        missing_tools+=("kubectl")
    fi
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        log_error "다음 도구들이 설치되지 않았습니다: ${missing_tools[*]}"
        log_info "다음 명령어로 설치하세요:"
        for tool in "${missing_tools[@]}"; do
            case $tool in
                "git") echo "  sudo apt-get install git" ;;
                "docker") echo "  curl -fsSL https://get.docker.com -o get-docker.sh && sh get-docker.sh" ;;
                "aws") echo "  curl 'https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip' -o 'awscliv2.zip' && unzip awscliv2.zip && sudo ./aws/install" ;;
                "gcloud") echo "  curl https://sdk.cloud.google.com | bash" ;;
                "kubectl") echo "  curl -LO 'https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl' && sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl" ;;
            esac
        done
        exit 1
    fi
    
    log_success "모든 필수 도구가 설치되어 있습니다."
}

# 프로젝트 구조 생성
create_project_structure() {
    local project_name="$1"
    local project_dir="$PROJECT_ROOT/$project_name"
    
    log_info "프로젝트 구조 생성: $project_name"
    
    # 디렉토리 생성
    mkdir -p "$project_dir"/{src,tests,docs,.github/workflows,k8s}
    
    # package.json 생성
    cat > "$project_dir/package.json" << EOF
{
  "name": "$project_name",
  "version": "1.0.0",
  "description": "GitHub Actions CI/CD 실습 프로젝트",
  "main": "src/app.js",
  "scripts": {
    "start": "node src/app.js",
    "test": "jest",
    "lint": "eslint src/",
    "build": "echo 'Build completed'"
  },
  "dependencies": {
    "express": "^4.18.2",
    "cors": "^2.8.5"
  },
  "devDependencies": {
    "jest": "^29.7.0",
    "supertest": "^6.3.3",
    "eslint": "^8.57.0"
  }
}
EOF

    # 기본 애플리케이션 생성
    cat > "$project_dir/src/app.js" << 'EOF'
const express = require('express');
const cors = require('cors');
const app = express();
const port = process.env.PORT || 3000;

// 미들웨어 설정
app.use(cors());
app.use(express.json());

// 기본 라우트
app.get('/', (req, res) => {
  res.json({
    message: 'GitHub Actions CI/CD 실습 애플리케이션',
    version: '1.0.0',
    timestamp: new Date().toISOString(),
    environment: process.env.NODE_ENV || 'development'
  });
});

// 헬스 체크 엔드포인트
app.get('/health', (req, res) => {
  res.json({
    status: 'OK',
    uptime: process.uptime(),
    memory: process.memoryUsage(),
    timestamp: new Date().toISOString()
  });
});

// API 엔드포인트
app.get('/api/status', (req, res) => {
  res.json({
    service: 'GitHub Actions CI/CD Practice',
    status: 'running',
    version: '1.0.0'
  });
});

// 테스트 환경이 아닐 때만 서버 시작
if (process.env.NODE_ENV !== 'test') {
  app.listen(port, () => {
    console.log(`🚀 서버가 포트 ${port}에서 실행 중입니다.`);
    console.log(`📊 헬스 체크: http://localhost:${port}/health`);
  });
}

module.exports = app;
EOF

    # 테스트 파일 생성
    cat > "$project_dir/tests/app.test.js" << 'EOF'
const request = require('supertest');
const app = require('../src/app');

describe('App Tests', () => {
  beforeAll(() => {
    process.env.NODE_ENV = 'test';
  });

  test('GET / should return welcome message', async () => {
    const response = await request(app).get('/');
    expect(response.status).toBe(200);
    expect(response.body.message).toBe('GitHub Actions CI/CD 실습 애플리케이션');
  });

  test('GET /health should return health status', async () => {
    const response = await request(app).get('/health');
    expect(response.status).toBe(200);
    expect(response.body.status).toBe('OK');
  });

  test('GET /api/status should return API status', async () => {
    const response = await request(app).get('/api/status');
    expect(response.status).toBe(200);
    expect(response.body.service).toBe('GitHub Actions CI/CD Practice');
  });
});
EOF

    # Dockerfile 생성
    cat > "$project_dir/Dockerfile" << 'EOF'
# 멀티스테이지 빌드
FROM node:18-alpine AS builder

# 작업 디렉토리 설정
WORKDIR /app

# 패키지 파일 복사
COPY package*.json ./

# 의존성 설치
RUN npm ci --only=production && npm cache clean --force

# 런타임 스테이지
FROM node:18-alpine AS runtime

# 보안을 위한 비root 사용자 생성
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nextjs -u 1001

# 작업 디렉토리 설정
WORKDIR /app

# 의존성 복사
COPY --from=builder /app/node_modules ./node_modules

# 소스 코드 복사
COPY --chown=nextjs:nodejs . .

# 사용자 변경
USER nextjs

# 포트 노출
EXPOSE 3000

# 헬스 체크
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD node -e "require('http').get('http://localhost:3000/health', (res) => { process.exit(res.statusCode === 200 ? 0 : 1) })"

# 애플리케이션 시작
CMD ["node", "src/app.js"]
EOF

    # docker-compose.yml 생성
    cat > "$project_dir/docker-compose.yml" << 'EOF'
version: '3.8'
services:
  app:
    build: .
    ports:
      - "3000:3000"
    environment:
      - NODE_ENV=production
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "node", "-e", "require('http').get('http://localhost:3000/health', (res) => { process.exit(res.statusCode === 200 ? 0 : 1) })"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
EOF

    log_success "프로젝트 구조 생성 완료: $project_dir"
}

# GitHub Actions 워크플로우 생성
create_workflows() {
    local project_name="$1"
    local node_version="$2"
    local docker_username="$3"
    local aws_region="$4"
    local gcp_region="$5"
    local skill_level="$6"
    local budget="$7"
    local cloud_provider="$8"
    
    local workflows_dir="$PROJECT_ROOT/$project_name/.github/workflows"
    
    log_info "GitHub Actions 워크플로우 생성..."
    
    # CI 워크플로우 생성
    cat > "$workflows_dir/ci.yml" << EOF
name: CI Pipeline

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]

env:
  NODE_VERSION: '$node_version'

jobs:
  test:
    name: 테스트 실행
    runs-on: ubuntu-latest
    
    strategy:
      matrix:
        node-version: [16, 18, 20]
    
    steps:
    - name: 코드 체크아웃
      uses: actions/checkout@v4
      
    - name: Node.js \${{ matrix.node-version }} 설정
      uses: actions/setup-node@v4
      with:
        node-version: \${{ matrix.node-version }}
        cache: 'npm'
        
    - name: 의존성 설치
      run: npm ci
      
    - name: 린팅 실행
      run: npm run lint
      
    - name: 테스트 실행
      run: npm test
      
    - name: 테스트 결과 업로드
      uses: actions/upload-artifact@v4
      if: always()
      with:
        name: test-results-node-\${{ matrix.node-version }}
        path: test-results/
        retention-days: 30

  build:
    name: 애플리케이션 빌드
    runs-on: ubuntu-latest
    needs: test
    
    steps:
    - name: 코드 체크아웃
      uses: actions/checkout@v4
      
    - name: Node.js 설정
      uses: actions/setup-node@v4
      with:
        node-version: \${{ env.NODE_VERSION }}
        cache: 'npm'
        
    - name: 의존성 설치
      run: npm ci
      
    - name: 애플리케이션 빌드
      run: npm run build
      
    - name: 빌드 아티팩트 업로드
      uses: actions/upload-artifact@v4
      with:
        name: build-artifacts
        path: |
          src/
          package.json
          package-lock.json
        retention-days: 30

  security-scan:
    name: 보안 스캔
    runs-on: ubuntu-latest
    needs: test
    
    steps:
    - name: 코드 체크아웃
      uses: actions/checkout@v4
      
    - name: Node.js 설정
      uses: actions/setup-node@v4
      with:
        node-version: \${{ env.NODE_VERSION }}
        cache: 'npm'
        
    - name: 의존성 설치
      run: npm ci
      
    - name: 보안 취약점 스캔
      run: npm audit --audit-level moderate
      
    - name: 의존성 취약점 스캔
      run: npx audit-ci --moderate
EOF

    # Docker 빌드 워크플로우 생성
    if [ -n "$docker_username" ]; then
        cat > "$workflows_dir/docker-build.yml" << EOF
name: Docker Build and Push

on:
  push:
    branches: [ main ]
    tags: [ 'v*' ]
  pull_request:
    branches: [ main ]

env:
  REGISTRY: docker.io
  IMAGE_NAME: $docker_username/$project_name

jobs:
  build:
    name: Docker 이미지 빌드 및 푸시
    runs-on: ubuntu-latest
    
    steps:
    - name: 코드 체크아웃
      uses: actions/checkout@v4
      
    - name: Docker Buildx 설정
      uses: docker/setup-buildx-action@v3
      
    - name: Docker Hub 로그인
      uses: docker/login-action@v3
      with:
        username: \${{ secrets.DOCKER_USERNAME }}
        password: \${{ secrets.DOCKER_PASSWORD }}
        
    - name: 메타데이터 추출
      id: meta
      uses: docker/metadata-action@v5
      with:
        images: \${{ env.REGISTRY }}/\${{ env.IMAGE_NAME }}
        tags: |
          type=ref,event=branch
          type=ref,event=pr
          type=semver,pattern={{version}}
          type=semver,pattern={{major}}.{{minor}}
          type=raw,value=latest,enable={{is_default_branch}}
          
    - name: 이미지 빌드 및 푸시
      uses: docker/build-push-action@v5
      with:
        context: .
        push: true
        tags: \${{ steps.meta.outputs.tags }}
        labels: \${{ steps.meta.outputs.labels }}
        cache-from: type=gha
        cache-to: type=gha,mode=max
        platforms: linux/amd64,linux/arm64
        
    - name: 이미지 보안 스캔
      uses: aquasecurity/trivy-action@master
      with:
        image-ref: \${{ env.REGISTRY }}/\${{ env.IMAGE_NAME }}:\${{ github.sha }}
        format: 'sarif'
        output: 'trivy-results.sarif'
        
    - name: 보안 스캔 결과 업로드
      uses: github/codeql-action/upload-sarif@v2
      with:
        sarif_file: 'trivy-results.sarif'
EOF
    fi

    # 배포 워크플로우 생성
    cat > "$workflows_dir/deploy.yml" << EOF
name: Deploy to Cloud

on:
  push:
    branches: [ main ]
  workflow_dispatch:
    inputs:
      environment:
        description: '배포 환경 선택'
        required: true
        default: 'staging'
        type: choice
        options:
        - staging
        - production

env:
  DEPLOY_ENV: \${{ github.ref == 'refs/heads/main' && 'production' || 'staging' }}
  AWS_REGION: $aws_region
  GCP_REGION: $gcp_region

jobs:
  deploy-aws:
    name: AWS EC2 배포
    runs-on: ubuntu-latest
    if: \${{ '$cloud_provider' == 'aws' || '$cloud_provider' == 'both' }}
    environment: \${{ env.DEPLOY_ENV }}
    
    steps:
    - name: 코드 체크아웃
      uses: actions/checkout@v4
      
    - name: AWS 자격증명 설정
      uses: aws-actions/configure-aws-credentials@v4
      with:
        aws-access-key-id: \${{ secrets.AWS_ACCESS_KEY_ID }}
        aws-secret-access-key: \${{ secrets.AWS_SECRET_ACCESS_KEY }}
        aws-region: \${{ env.AWS_REGION }}
        
    - name: AWS EC2 배포
      uses: appleboy/ssh-action@v1.0.3
      with:
        host: \${{ secrets.AWS_HOST }}
        username: \${{ secrets.AWS_USERNAME }}
        key: \${{ secrets.AWS_SSH_KEY }}
        script: |
          cd /opt/$project_name
          git pull origin main
          docker-compose down
          docker-compose up -d --build
          docker ps
          curl -f http://localhost:3000/health || exit 1

  deploy-gcp:
    name: GCP Compute Engine 배포
    runs-on: ubuntu-latest
    if: \${{ '$cloud_provider' == 'gcp' || '$cloud_provider' == 'both' }}
    environment: \${{ env.DEPLOY_ENV }}
    
    steps:
    - name: 코드 체크아웃
      uses: actions/checkout@v4
      
    - name: GCP 자격증명 설정
      uses: google-github-actions/auth@v2
      with:
        credentials_json: \${{ secrets.GCP_SERVICE_ACCOUNT_KEY }}
        
    - name: GCP Compute Engine 배포
      uses: appleboy/ssh-action@v1.0.3
      with:
        host: \${{ secrets.GCP_HOST }}
        username: \${{ secrets.GCP_USERNAME }}
        key: \${{ secrets.GCP_SSH_KEY }}
        script: |
          cd /opt/$project_name
          git pull origin main
          docker-compose down
          docker-compose up -d --build
          docker ps
          curl -f http://localhost:3000/health || exit 1
EOF

    # 고급 CI/CD 워크플로우 생성 (중급 이상)
    if [ "$skill_level" = "중급" ] || [ "$skill_level" = "고급" ]; then
        cat > "$workflows_dir/advanced-cicd.yml" << EOF
name: Advanced CI/CD Pipeline

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]
  workflow_dispatch:
    inputs:
      cloud_provider:
        description: '클라우드 프로바이더 선택'
        required: true
        default: '$cloud_provider'
        type: choice
        options:
        - aws
        - gcp
        - both
      skill_level:
        description: '실습 난이도'
        required: true
        default: '$skill_level'
        type: choice
        options:
        - 초급
        - 중급
        - 고급

env:
  AWS_REGION: $aws_region
  GCP_REGION: $gcp_region
  BUDGET_LIMIT: $budget

jobs:
  environment-check:
    name: 환경 검증
    runs-on: ubuntu-latest
    outputs:
      environment-ok: \${{ steps.check.outputs.environment-ok }}
    steps:
    - name: 코드 체크아웃
      uses: actions/checkout@v4
      
    - name: 필수 도구 설치
      run: |
        sudo apt-get update
        sudo apt-get install -y curl wget git unzip jq
        
    - name: 환경 체크
      id: check
      run: |
        if ! command -v docker &> /dev/null; then
          echo "❌ Docker가 설치되지 않았습니다."
          echo "environment-ok=false" >> \$GITHUB_OUTPUT
          exit 1
        fi
        
        if ! command -v aws &> /dev/null; then
          echo "❌ AWS CLI가 설치되지 않았습니다."
          echo "environment-ok=false" >> \$GITHUB_OUTPUT
          exit 1
        fi
        
        if ! command -v gcloud &> /dev/null; then
          echo "❌ GCP CLI가 설치되지 않았습니다."
          echo "environment-ok=false" >> \$GITHUB_OUTPUT
          exit 1
        fi
        
        echo "✅ 모든 필수 도구가 설치되어 있습니다."
        echo "environment-ok=true" >> \$GITHUB_OUTPUT

  matrix-test:
    name: 매트릭스 테스트
    runs-on: ubuntu-latest
    needs: environment-check
    if: \${{ needs.environment-check.outputs.environment-ok == 'true' }}
    
    strategy:
      matrix:
        node-version: [16, 18, 20]
        os: [ubuntu-latest, windows-latest, macos-latest]
        exclude:
          - node-version: 16
            os: windows-latest
          - node-version: 20
            os: macos-latest
    
    steps:
    - name: 코드 체크아웃
      uses: actions/checkout@v4
      
    - name: Node.js \${{ matrix.node-version }} 설정
      uses: actions/setup-node@v4
      with:
        node-version: \${{ matrix.node-version }}
        cache: 'npm'
        
    - name: 의존성 설치
      run: npm ci
      
    - name: 테스트 실행
      run: npm test
      
    - name: 테스트 결과 업로드
      uses: actions/upload-artifact@v4
      if: always()
      with:
        name: test-results-\${{ matrix.os }}-node-\${{ matrix.node-version }}
        path: test-results/
        retention-days: 30

  kubernetes-deploy:
    name: Kubernetes 배포
    runs-on: ubuntu-latest
    needs: [environment-check, matrix-test]
    if: \${{ needs.environment-check.outputs.environment-ok == 'true' && needs.matrix-test.result == 'success' }}
    
    steps:
    - name: 코드 체크아웃
      uses: actions/checkout@v4
      
    - name: AWS EKS 클러스터 연결
      if: \${{ github.event.inputs.cloud_provider == 'aws' || github.event.inputs.cloud_provider == 'both' }}
      run: |
        aws eks update-kubeconfig --region \${{ env.AWS_REGION }} --name my-eks-cluster
        
    - name: GCP GKE 클러스터 연결
      if: \${{ github.event.inputs.cloud_provider == 'gcp' || github.event.inputs.cloud_provider == 'both' }}
      run: |
        gcloud container clusters get-credentials my-gke-cluster --zone \${{ env.GCP_REGION }}-a
        
    - name: Kubernetes 매니페스트 적용
      run: |
        kubectl apply -f k8s/
        
    - name: 배포 상태 확인
      run: |
        kubectl get pods
        kubectl get services
        kubectl get deployments
EOF
    fi

    # 모니터링 워크플로우 생성 (고급)
    if [ "$skill_level" = "고급" ]; then
        cat > "$workflows_dir/monitoring.yml" << EOF
name: Monitoring and Optimization

on:
  schedule:
    - cron: '0 9 * * *'
  workflow_dispatch:
    inputs:
      monitoring_type:
        description: '모니터링 유형 선택'
        required: true
        default: 'full'
        type: choice
        options:
        - full
        - basic
        - security

jobs:
  app-monitoring:
    name: 애플리케이션 모니터링
    runs-on: ubuntu-latest
    
    steps:
    - name: 코드 체크아웃
      uses: actions/checkout@v4
      
    - name: 애플리케이션 상태 확인
      run: |
        aws ec2 describe-instances --query 'Reservations[*].Instances[*].[InstanceId,State.Name,PublicIpAddress]' --output table
        gcloud compute instances list --format="table(name,zone,machineType,status)"
        
    - name: 애플리케이션 헬스 체크
      run: |
        curl -f http://\${{ secrets.AWS_HOST }}/health || echo "AWS 애플리케이션 상태 확인 실패"
        curl -f http://\${{ secrets.GCP_HOST }}/health || echo "GCP 애플리케이션 상태 확인 실패"

  security-monitoring:
    name: 보안 모니터링
    runs-on: ubuntu-latest
    
    steps:
    - name: 코드 체크아웃
      uses: actions/checkout@v4
      
    - name: 보안 취약점 스캔
      run: |
        npm audit --audit-level moderate
        docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \\
          aquasec/trivy image $docker_username/$project_name:latest
        
    - name: AWS 보안 스캔
      run: |
        aws inspector list-assessment-templates
        
    - name: GCP 보안 스캔
      run: |
        gcloud scc sources list

  cost-optimization:
    name: 비용 최적화
    runs-on: ubuntu-latest
    
    steps:
    - name: 코드 체크아웃
      uses: actions/checkout@v4
      
    - name: AWS 비용 분석
      run: |
        aws ce get-cost-and-usage \\
          --time-period Start=2024-01-01,End=2024-01-31 \\
          --granularity MONTHLY \\
          --metrics BlendedCost
          
    - name: GCP 비용 분석
      run: |
        gcloud billing accounts list
        
    - name: 비용 최적화 권장사항
      run: |
        echo "비용 최적화 권장사항:"
        echo "1. 사용하지 않는 리소스 정리"
        echo "2. 인스턴스 크기 최적화"
        echo "3. 예약 인스턴스 사용 고려"

  notification:
    name: 알림 및 보고서
    runs-on: ubuntu-latest
    needs: [app-monitoring, security-monitoring, cost-optimization]
    if: always()
    
    steps:
    - name: 모니터링 결과 수집
      run: |
        echo "모니터링 결과 수집 중..."
        
    - name: Slack 알림 전송
      if: \${{ secrets.SLACK_WEBHOOK_URL }}
      uses: 8398a7/action-slack@v3
      with:
        status: \${{ job.status }}
        channel: '#monitoring'
        text: |
          GitHub Actions CI/CD 모니터링 완료
          - 애플리케이션 모니터링: \${{ needs.app-monitoring.result }}
          - 보안 모니터링: \${{ needs.security-monitoring.result }}
          - 비용 최적화: \${{ needs.cost-optimization.result }}
EOF
    fi

    log_success "GitHub Actions 워크플로우 생성 완료"
}

# Kubernetes 매니페스트 생성
create_k8s_manifests() {
    local project_name="$1"
    local k8s_dir="$PROJECT_ROOT/$project_name/k8s"
    
    log_info "Kubernetes 매니페스트 생성..."
    
    # Deployment 생성
    cat > "$k8s_dir/deployment.yaml" << EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: $project_name
  labels:
    app: $project_name
spec:
  replicas: 3
  selector:
    matchLabels:
      app: $project_name
  template:
    metadata:
      labels:
        app: $project_name
    spec:
      containers:
      - name: $project_name
        image: $project_name:latest
        ports:
        - containerPort: 3000
        env:
        - name: NODE_ENV
          value: "production"
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "200m"
        livenessProbe:
          httpGet:
            path: /health
            port: 3000
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /health
            port: 3000
          initialDelaySeconds: 5
          periodSeconds: 5
EOF

    # Service 생성
    cat > "$k8s_dir/service.yaml" << EOF
apiVersion: v1
kind: Service
metadata:
  name: $project_name-service
  labels:
    app: $project_name
spec:
  selector:
    app: $project_name
  ports:
  - port: 80
    targetPort: 3000
    protocol: TCP
  type: LoadBalancer
EOF

    # ConfigMap 생성
    cat > "$k8s_dir/configmap.yaml" << EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: $project_name-config
data:
  NODE_ENV: "production"
  PORT: "3000"
EOF

    log_success "Kubernetes 매니페스트 생성 완료"
}

# GitHub Secrets 설정 가이드 생성
create_secrets_guide() {
    local project_name="$1"
    local docker_username="$2"
    
    log_info "GitHub Secrets 설정 가이드 생성..."
    
    cat > "$PROJECT_ROOT/$project_name/GITHUB_SECRETS_GUIDE.md" << EOF
# GitHub Secrets 설정 가이드

## 필수 Secrets 설정

### 1. Docker Hub 설정
- \`DOCKER_USERNAME\`: Docker Hub 사용자명 ($docker_username)
- \`DOCKER_PASSWORD\`: Docker Hub 비밀번호

### 2. AWS 설정
- \`AWS_ACCESS_KEY_ID\`: AWS 액세스 키 ID
- \`AWS_SECRET_ACCESS_KEY\`: AWS 시크릿 액세스 키
- \`AWS_HOST\`: AWS EC2 인스턴스 IP 주소
- \`AWS_USERNAME\`: AWS EC2 사용자명 (예: ec2-user)
- \`AWS_SSH_KEY\`: AWS EC2 SSH 개인 키

### 3. GCP 설정
- \`GCP_SERVICE_ACCOUNT_KEY\`: GCP 서비스 계정 JSON 키
- \`GCP_HOST\`: GCP Compute Engine 인스턴스 IP 주소
- \`GCP_USERNAME\`: GCP 사용자명 (예: ubuntu)
- \`GCP_SSH_KEY\`: GCP SSH 개인 키

### 4. 알림 설정 (선택사항)
- \`SLACK_WEBHOOK_URL\`: Slack 웹훅 URL
- \`EMAIL_USERNAME\`: 이메일 사용자명
- \`EMAIL_PASSWORD\`: 이메일 비밀번호
- \`EMAIL_NOTIFICATION\`: 알림 받을 이메일 주소

## Secrets 설정 방법

1. GitHub 저장소 페이지로 이동
2. Settings > Secrets and variables > Actions 클릭
3. "New repository secret" 버튼 클릭
4. 위의 각 항목을 추가

## SSH 키 생성 방법

### AWS용 SSH 키
\`\`\`bash
ssh-keygen -t rsa -b 4096 -f ~/.ssh/aws-key
\`\`\`

### GCP용 SSH 키
\`\`\`bash
ssh-keygen -t rsa -b 4096 -f ~/.ssh/gcp-key
\`\`\`

## 서비스 계정 키 생성 (GCP)

1. GCP 콘솔에서 IAM & Admin > Service Accounts 이동
2. 서비스 계정 생성 또는 선택
3. Keys 탭에서 "Add Key" > "Create new key" 선택
4. JSON 형식으로 다운로드
5. 다운로드한 JSON 내용을 \`GCP_SERVICE_ACCOUNT_KEY\`에 설정
EOF

    log_success "GitHub Secrets 설정 가이드 생성 완료"
}

# 리소스 정리
cleanup_resources() {
    log_info "생성된 리소스 정리 중..."
    
    # 프로젝트 디렉토리 정리
    if [ -d "$PROJECT_ROOT" ]; then
        find "$PROJECT_ROOT" -name "github-actions-cicd-practice*" -type d -exec rm -rf {} + 2>/dev/null || true
    fi
    
    # Docker 이미지 정리
    docker system prune -f 2>/dev/null || true
    
    # Kubernetes 리소스 정리
    kubectl delete deployment github-actions-cicd-practice 2>/dev/null || true
    kubectl delete service github-actions-cicd-practice-service 2>/dev/null || true
    kubectl delete configmap github-actions-cicd-practice-config 2>/dev/null || true
    
    log_success "리소스 정리 완료"
}

# 메인 함수
main() {
    # 기본값 설정
    local project_name="$DEFAULT_PROJECT_NAME"
    local node_version="$DEFAULT_NODE_VERSION"
    local docker_username="$DEFAULT_DOCKER_USERNAME"
    local aws_region="$DEFAULT_AWS_REGION"
    local gcp_region="$DEFAULT_GCP_REGION"
    local skill_level="중급"
    local budget="50"
    local cloud_provider="both"
    local setup_only=false
    local cleanup=false
    
    # 명령행 인수 파싱
    while [[ $# -gt 0 ]]; do
        case $1 in
            -n|--name)
                project_name="$2"
                shift 2
                ;;
            -v|--node-version)
                node_version="$2"
                shift 2
                ;;
            -d|--docker-user)
                docker_username="$2"
                shift 2
                ;;
            -a|--aws-region)
                aws_region="$2"
                shift 2
                ;;
            -g|--gcp-region)
                gcp_region="$2"
                shift 2
                ;;
            -s|--skill-level)
                skill_level="$2"
                shift 2
                ;;
            -b|--budget)
                budget="$2"
                shift 2
                ;;
            -c|--cloud-provider)
                cloud_provider="$2"
                shift 2
                ;;
            --setup-only)
                setup_only=true
                shift
                ;;
            --cleanup)
                cleanup=true
                shift
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                log_error "알 수 없는 옵션: $1"
                usage
                exit 1
                ;;
        esac
    done
    
    # 정리 모드
    if [ "$cleanup" = true ]; then
        cleanup_resources
        exit 0
    fi
    
    # 환경 체크
    check_environment
    
    # 프로젝트 구조 생성
    create_project_structure "$project_name"
    
    # GitHub Actions 워크플로우 생성
    create_workflows "$project_name" "$node_version" "$docker_username" "$aws_region" "$gcp_region" "$skill_level" "$budget" "$cloud_provider"
    
    # Kubernetes 매니페스트 생성
    create_k8s_manifests "$project_name"
    
    # GitHub Secrets 설정 가이드 생성
    create_secrets_guide "$project_name" "$docker_username"
    
    # 설정 완료 메시지
    log_success "GitHub Actions CI/CD 자동화 설정 완료!"
    echo ""
    echo "📁 프로젝트 디렉토리: $PROJECT_ROOT/$project_name"
    echo "🔧 다음 단계:"
    echo "1. GitHub 저장소에 코드 푸시"
    echo "2. GitHub Secrets 설정 (GITHUB_SECRETS_GUIDE.md 참조)"
    echo "3. GitHub Actions 워크플로우 실행"
    echo ""
    echo "📚 자세한 내용은 다음 문서를 참조하세요:"
    echo "- GitHub Actions CI/CD 완전 가이드"
    echo "- GitHub Secrets 설정 가이드"
    
    if [ "$setup_only" = false ]; then
        log_info "프로젝트 실행을 위해 다음 명령어를 실행하세요:"
        echo "cd $PROJECT_ROOT/$project_name"
        echo "npm install"
        echo "npm start"
    fi
}

# 스크립트 실행
main "$@"
