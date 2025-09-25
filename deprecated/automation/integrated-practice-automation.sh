#!/bin/bash

# Cloud Master - Integrated Practice Automation Script
# 작성자: Cloud Master Team
# 목적: 전체 Cloud Master 과정 통합 실습 자동화

set -e  # 오류 발생 시 스크립트 중단

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
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

log_step() {
    echo -e "${PURPLE}[STEP]${NC} $1"
}

# 실습 환경 확인
check_prerequisites() {
    log_info "실습 환경 확인 중..."
    
    # 필수 도구 확인
    local tools=("docker" "git" "curl" "jq")
    for tool in "${tools[@]}"; do
        if ! command -v $tool &> /dev/null; then
            log_error "$tool이 설치되지 않았습니다. 먼저 $tool을 설치해주세요."
            exit 1
        fi
    done
    
    # Docker 서비스 확인
    if ! docker info &> /dev/null; then
        log_error "Docker 서비스가 실행되지 않았습니다. Docker를 시작해주세요."
        exit 1
    fi
    
    log_success "실습 환경 확인 완료"
}

# 1일차: Docker & GitHub Actions 실습
day1_docker_github_actions() {
    log_step "=== 1일차: Docker & GitHub Actions 실습 ==="
    
    # Docker 실습
    log_info "Docker 실습 시작..."
    if [ -f "mcp_knowledge_base/cloud_master/automation/day1/docker-practice-automation.sh" ]; then
        chmod +x mcp_knowledge_base/cloud_master/automation/day1/docker-practice-automation.sh
        ./mcp_knowledge_base/cloud_master/automation/day1/docker-practice-automation.sh
    else
        log_warning "Docker 실습 스크립트를 찾을 수 없습니다. 수동으로 실행해주세요."
    fi
    
    # GitHub Actions 실습
    log_info "GitHub Actions 실습 시작..."
    if [ -f "mcp_knowledge_base/cloud_master/automation/day1/github-actions-automation.sh" ]; then
        chmod +x mcp_knowledge_base/cloud_master/automation/day1/github-actions-automation.sh
        ./mcp_knowledge_base/cloud_master/automation/day1/github-actions-automation.sh
    else
        log_warning "GitHub Actions 실습 스크립트를 찾을 수 없습니다. 수동으로 실행해주세요."
    fi
    
    log_success "1일차 실습 완료"
}

# 2일차: Kubernetes 실습
day2_kubernetes() {
    log_step "=== 2일차: Kubernetes 실습 ==="
    
    # Kubernetes 실습
    log_info "Kubernetes 실습 시작..."
    if [ -f "mcp_knowledge_base/cloud_master/automation/day2/kubernetes-practice-automation.sh" ]; then
        chmod +x mcp_knowledge_base/cloud_master/automation/day2/kubernetes-practice-automation.sh
        ./mcp_knowledge_base/cloud_master/automation/day2/kubernetes-practice-automation.sh
    else
        log_warning "Kubernetes 실습 스크립트를 찾을 수 없습니다. 수동으로 실행해주세요."
    fi
    
    log_success "2일차 실습 완료"
}

# 3일차: 모니터링 실습
day3_monitoring() {
    log_step "=== 3일차: 모니터링 실습 ==="
    
    # 모니터링 실습
    log_info "모니터링 실습 시작..."
    if [ -f "mcp_knowledge_base/cloud_master/automation/day3/monitoring-practice-automation.sh" ]; then
        chmod +x mcp_knowledge_base/cloud_master/automation/day3/monitoring-practice-automation.sh
        ./mcp_knowledge_base/cloud_master/automation/day3/monitoring-practice-automation.sh
    else
        log_warning "모니터링 실습 스크립트를 찾을 수 없습니다. 수동으로 실행해주세요."
    fi
    
    log_success "3일차 실습 완료"
}

# 통합 프로젝트 생성
create_integrated_project() {
    log_step "=== 통합 프로젝트 생성 ==="
    
    # 통합 프로젝트 디렉토리 확인 및 생성
    log_info "통합 프로젝트 디렉토리 확인..."
    if [ -d "~/cloud-master-integrated-project" ]; then
        log_info "통합 프로젝트 디렉토리가 이미 존재합니다."
        cd ~/cloud-master-integrated-project
        
        # 기존 컨테이너 정리
        log_info "기존 컨테이너 정리..."
        docker-compose down 2>/dev/null || true
    else
        log_info "통합 프로젝트 디렉토리 생성..."
        mkdir -p ~/cloud-master-integrated-project
        cd ~/cloud-master-integrated-project
    fi
    
    # 프로젝트 구조 생성
    log_info "프로젝트 구조 생성..."
    mkdir -p {src,deployments,monitoring,scripts,docs}
    
    # Docker Compose 통합 파일 생성
    log_info "Docker Compose 통합 파일 생성..."
    cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  # 웹 애플리케이션
  web-app:
    build: ./src
    container_name: cloud-master-web-app
    ports:
      - "3000:3000"
    environment:
      - NODE_ENV=production
      - DATABASE_URL=postgresql://postgres:password@db:5432/cloudmaster
    depends_on:
      - db
      - redis
    networks:
      - app-network

  # 데이터베이스
  db:
    image: postgres:13
    container_name: cloud-master-db
    environment:
      - POSTGRES_DB=cloudmaster
      - POSTGRES_USER=postgres
      - POSTGRES_PASSWORD=password
    volumes:
      - postgres_data:/var/lib/postgresql/data
    networks:
      - app-network

  # Redis 캐시
  redis:
    image: redis:6-alpine
    container_name: cloud-master-redis
    ports:
      - "6379:6379"
    networks:
      - app-network

  # Nginx 로드 밸런서
  nginx:
    image: nginx:alpine
    container_name: cloud-master-nginx
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf
    depends_on:
      - web-app
    networks:
      - app-network

  # Prometheus 모니터링
  prometheus:
    image: prom/prometheus:latest
    container_name: cloud-master-prometheus
    ports:
      - "9090:9090"
    volumes:
      - ./monitoring/prometheus.yml:/etc/prometheus/prometheus.yml
    networks:
      - app-network

  # Grafana 대시보드
  grafana:
    image: grafana/grafana:latest
    container_name: cloud-master-grafana
    ports:
      - "3001:3000"
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin123
    volumes:
      - grafana_data:/var/lib/grafana
    networks:
      - app-network

volumes:
  postgres_data:
  grafana_data:

networks:
  app-network:
    driver: bridge
EOF
    
    # Kubernetes 배포 파일 생성
    log_info "Kubernetes 배포 파일 생성..."
    mkdir -p deployments/k8s
    
    cat > deployments/k8s/namespace.yaml << 'EOF'
apiVersion: v1
kind: Namespace
metadata:
  name: cloud-master
  labels:
    name: cloud-master
EOF
    
    cat > deployments/k8s/deployment.yaml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cloud-master-app
  namespace: cloud-master
spec:
  replicas: 3
  selector:
    matchLabels:
      app: cloud-master-app
  template:
    metadata:
      labels:
        app: cloud-master-app
    spec:
      containers:
      - name: web-app
        image: cloud-master-web-app:latest
        ports:
        - containerPort: 3000
        env:
        - name: NODE_ENV
          value: "production"
        resources:
          requests:
            memory: "256Mi"
            cpu: "250m"
          limits:
            memory: "512Mi"
            cpu: "500m"
EOF
    
    cat > deployments/k8s/service.yaml << 'EOF'
apiVersion: v1
kind: Service
metadata:
  name: cloud-master-service
  namespace: cloud-master
spec:
  selector:
    app: cloud-master-app
  ports:
  - port: 80
    targetPort: 3000
  type: LoadBalancer
EOF
    
    # GitHub Actions 워크플로우 생성
    log_info "GitHub Actions 워크플로우 생성..."
    mkdir -p .github/workflows
    
    cat > .github/workflows/integrated-ci-cd.yml << 'EOF'
name: Integrated CI/CD Pipeline

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

env:
  REGISTRY: ghcr.io
  IMAGE_NAME: ${{ github.repository }}

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v3
    
    - name: Setup Node.js
      uses: actions/setup-node@v3
      with:
        node-version: '18'
        cache: 'npm'
    
    - name: Install dependencies
      run: npm ci
    
    - name: Run tests
      run: npm test
    
    - name: Run linting
      run: npm run lint

  build:
    needs: test
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v3
    
    - name: Set up Docker Buildx
      uses: docker/setup-buildx-action@v2
    
    - name: Login to Container Registry
      uses: docker/login-action@v2
      with:
        registry: ${{ env.REGISTRY }}
        username: ${{ github.actor }}
        password: ${{ secrets.GITHUB_TOKEN }}
    
    - name: Build and push Docker image
      uses: docker/build-push-action@v4
      with:
        context: .
        push: true
        tags: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:latest

  deploy:
    needs: build
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'
    steps:
    - uses: actions/checkout@v3
    
    - name: Deploy to Kubernetes
      run: |
        echo "Deploying to Kubernetes cluster..."
        # 실제 배포 로직은 여기에 구현
        echo "Deployment completed!"
EOF
    
    # 모니터링 설정 생성
    log_info "모니터링 설정 생성..."
    cat > monitoring/prometheus.yml << 'EOF'
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'cloud-master-app'
    static_configs:
      - targets: ['web-app:3000']
  
  - job_name: 'postgres'
    static_configs:
      - targets: ['db:5432']
  
  - job_name: 'redis'
    static_configs:
      - targets: ['redis:6379']
EOF
    
    # Nginx 설정 생성
    log_info "Nginx 설정 생성..."
    cat > nginx.conf << 'EOF'
events {
    worker_connections 1024;
}

http {
    upstream web-app {
        server web-app:3000;
    }
    
    server {
        listen 80;
        
        location / {
            proxy_pass http://web-app;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
        }
        
        location /metrics {
            proxy_pass http://web-app:3000/metrics;
        }
    }
}
EOF
    
    # 애플리케이션 소스 코드 생성
    log_info "애플리케이션 소스 코드 생성..."
    cat > src/package.json << 'EOF'
{
  "name": "cloud-master-integrated-app",
  "version": "1.0.0",
  "description": "Cloud Master Integrated Application",
  "main": "server.js",
  "scripts": {
    "start": "node server.js",
    "test": "jest",
    "lint": "eslint ."
  },
  "dependencies": {
    "express": "^4.18.0",
    "redis": "^4.6.0",
    "pg": "^8.8.0",
    "prom-client": "^14.0.0"
  },
  "devDependencies": {
    "jest": "^29.0.0",
    "eslint": "^8.0.0"
  }
}
EOF
    
    cat > src/server.js << 'EOF'
const express = require('express');
const { createClient } = require('redis');
const { Pool } = require('pg');
const client = require('prom-client');

const app = express();
const port = process.env.PORT || 3000;

// Prometheus 메트릭 설정
const register = new client.Registry();
client.collectDefaultMetrics({ register });

const httpRequestDuration = new client.Histogram({
  name: 'http_request_duration_seconds',
  help: 'Duration of HTTP requests in seconds',
  labelNames: ['method', 'route', 'status_code']
});

const httpRequestTotal = new client.Counter({
  name: 'http_requests_total',
  help: 'Total number of HTTP requests',
  labelNames: ['method', 'route', 'status_code']
});

register.registerMetric(httpRequestDuration);
register.registerMetric(httpRequestTotal);

// Redis 클라이언트
const redisClient = createClient({
  host: process.env.REDIS_HOST || 'redis',
  port: process.env.REDIS_PORT || 6379
});

// PostgreSQL 클라이언트
const pool = new Pool({
  host: process.env.DB_HOST || 'db',
  port: process.env.DB_PORT || 5432,
  database: process.env.DB_NAME || 'cloudmaster',
  user: process.env.DB_USER || 'postgres',
  password: process.env.DB_PASSWORD || 'password'
});

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
    message: 'Cloud Master Integrated Application',
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    version: '1.0.0'
  });
});

app.get('/health', async (req, res) => {
  try {
    // Redis 연결 확인
    await redisClient.ping();
    
    // PostgreSQL 연결 확인
    await pool.query('SELECT 1');
    
    res.json({
      status: 'healthy',
      timestamp: new Date().toISOString(),
      services: {
        redis: 'connected',
        postgresql: 'connected'
      }
    });
  } catch (error) {
    res.status(500).json({
      status: 'unhealthy',
      error: error.message
    });
  }
});

app.get('/api/data', async (req, res) => {
  try {
    // Redis에서 캐시 확인
    const cacheKey = 'data:latest';
    const cached = await redisClient.get(cacheKey);
    
    if (cached) {
      return res.json(JSON.parse(cached));
    }
    
    // 데이터베이스에서 데이터 조회
    const result = await pool.query('SELECT * FROM data ORDER BY created_at DESC LIMIT 10');
    
    // Redis에 캐시 저장
    await redisClient.setex(cacheKey, 300, JSON.stringify(result.rows));
    
    res.json(result.rows);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.get('/metrics', (req, res) => {
  res.set('Content-Type', register.contentType);
  res.end(register.metrics());
});

// 서버 시작
app.listen(port, async () => {
  try {
    await redisClient.connect();
    console.log('Connected to Redis');
    
    await pool.query('SELECT 1');
    console.log('Connected to PostgreSQL');
    
    console.log(`Server running on port ${port}`);
  } catch (error) {
    console.error('Failed to connect to services:', error);
  }
});

// Graceful shutdown
process.on('SIGTERM', async () => {
  console.log('SIGTERM received, shutting down gracefully');
  await redisClient.quit();
  await pool.end();
  process.exit(0);
});

process.on('SIGINT', async () => {
  console.log('SIGINT received, shutting down gracefully');
  await redisClient.quit();
  await pool.end();
  process.exit(0);
});
EOF
    
    # Dockerfile 생성
    cat > src/Dockerfile << 'EOF'
FROM node:18-alpine

WORKDIR /app

COPY package*.json ./
RUN npm ci --only=production

COPY . .

EXPOSE 3000

CMD ["npm", "start"]
EOF
    
    # README 생성
    cat > README.md << 'EOF'
# Cloud Master Integrated Project

이 프로젝트는 Cloud Master 과정에서 학습한 모든 기술을 통합한 실습 프로젝트입니다.

## 기술 스택

- **Frontend/Backend**: Node.js, Express.js
- **Database**: PostgreSQL
- **Cache**: Redis
- **Containerization**: Docker, Docker Compose
- **Orchestration**: Kubernetes
- **CI/CD**: GitHub Actions
- **Monitoring**: Prometheus, Grafana
- **Load Balancing**: Nginx

## 실행 방법

### Docker Compose로 실행
```bash
docker-compose up -d
```

### Kubernetes로 실행
```bash
kubectl apply -f deployments/k8s/
```

## 접속 정보

- 웹 애플리케이션: http://localhost:3000
- Nginx 로드 밸런서: http://localhost:80
- Prometheus: http://localhost:9090
- Grafana: http://localhost:3001 (admin/admin123)

## API 엔드포인트

- `GET /` - 애플리케이션 정보
- `GET /health` - 헬스 체크
- `GET /api/data` - 데이터 조회
- `GET /metrics` - Prometheus 메트릭
EOF
    
    log_success "통합 프로젝트 생성 완료"
}

# GitHub Actions CI/CD 파이프라인 설정
setup_github_actions() {
    log_step "=== GitHub Actions CI/CD 파이프라인 설정 ==="
    
    # GitHub Actions 워크플로우 확인
    if [ -f "../cloud-scripts/.github/workflows/cloud-master-ci-cd.yml" ]; then
        log_success "GitHub Actions CI/CD 파이프라인을 찾았습니다."
        
        # 워크플로우 기능 설명
        log_info "CI/CD 파이프라인 기능:"
        echo "  - Docker 이미지 자동 빌드"
        echo "  - Docker Hub 자동 푸시"
        echo "  - AWS EC2 자동 배포"
        echo "  - GCP Compute Engine 자동 배포"
        echo "  - 헬스체크 및 알림"
        echo "  - 환경별 배포 관리"
        
        # GitHub Secrets 설정 안내
        log_info "GitHub Secrets 설정이 필요합니다:"
        echo "  - DOCKERHUB_USERNAME: Docker Hub 사용자명"
        echo "  - DOCKERHUB_TOKEN: Docker Hub 액세스 토큰"
        echo "  - AWS_ACCESS_KEY_ID: AWS 액세스 키"
        echo "  - AWS_SECRET_ACCESS_KEY: AWS 시크릿 키"
        echo "  - AWS_SSH_PRIVATE_KEY: AWS SSH 개인키"
        echo "  - GCP_PROJECT_ID: GCP 프로젝트 ID"
        echo "  - GCP_SA_KEY: GCP 서비스 계정 키"
        echo "  - GCP_SSH_PRIVATE_KEY: GCP SSH 개인키"
        
        # SSH 키 생성 안내
        log_info "SSH 키 생성이 필요합니다:"
        echo "  ssh-keygen -t rsa -b 4096 -f aws-key -C 'mcp-cloud-master-aws'"
        echo "  ssh-keygen -t rsa -b 4096 -f gcp-key -C 'mcp-cloud-master-gcp'"
        
        # 워크플로우 실행 방법
        log_info "워크플로우 실행 방법:"
        echo "  1. 코드를 GitHub에 푸시"
        echo "  2. GitHub Actions 탭에서 워크플로우 확인"
        echo "  3. 자동으로 Docker 이미지 빌드 및 배포"
        
    else
        log_warning "GitHub Actions CI/CD 파이프라인을 찾을 수 없습니다."
        log_info "cloud-scripts 디렉토리에 .github/workflows/cloud-master-ci-cd.yml 파일이 있는지 확인하세요."
    fi
    
    log_success "GitHub Actions CI/CD 파이프라인 설정 완료"
}

# 통합 CI/CD 파이프라인 실행
run_integrated_cicd() {
    log_step "=== 통합 CI/CD 파이프라인 실행 ==="
    
    # 통합 자동화 스크립트 실행
    log_info "통합 자동화 스크립트 실행 중..."
    if [ -f "../cloud-scripts/integrated-automation.sh" ]; then
        # AWS 환경에서 CI/CD 실행
        log_info "AWS 환경에서 CI/CD 실행:"
        bash ../cloud-scripts/integrated-automation.sh aws --ci-cd-only
        
        # GCP 환경에서 CI/CD 실행
        log_info "GCP 환경에서 CI/CD 실행:"
        bash ../cloud-scripts/integrated-automation.sh gcp --ci-cd-only
        
    else
        log_warning "통합 자동화 스크립트를 찾을 수 없습니다."
    fi
    
    log_success "통합 CI/CD 파이프라인 실행 완료"
}

# 실습 실행
run_practice() {
    local day=$1
    
    case $day in
        "1"|"day1")
            day1_docker_github_actions
            setup_github_actions
            ;;
        "2"|"day2")
            day2_kubernetes
            setup_github_actions
            ;;
        "3"|"day3")
            day3_monitoring
            setup_github_actions
            ;;
        "all"|"integrated")
            day1_docker_github_actions
            day2_kubernetes
            day3_monitoring
            create_integrated_project
            setup_github_actions
            run_integrated_cicd
            ;;
        "cicd")
            setup_github_actions
            run_integrated_cicd
            ;;
        *)
            log_error "잘못된 일차입니다. 1, 2, 3, all, cicd 중 하나를 선택해주세요."
            exit 1
            ;;
    esac
}

# 메인 실행 함수
main() {
    log_info "Cloud Master - Integrated Practice Automation 시작"
    echo "========================================================="
    
    # 인수 확인
    if [ $# -eq 0 ]; then
        log_info "사용법: $0 [1|2|3|all|cicd]"
        echo "  1    - 1일차: Docker & GitHub Actions"
        echo "  2    - 2일차: Kubernetes"
        echo "  3    - 3일차: 모니터링"
        echo "  all  - 전체 과정 통합 실습"
        echo "  cicd - GitHub Actions CI/CD 파이프라인만 실행"
        exit 1
    fi
    
    check_prerequisites
    run_practice $1
    
    log_success "실습이 완료되었습니다!"
}

# 스크립트 실행
main "$@"
