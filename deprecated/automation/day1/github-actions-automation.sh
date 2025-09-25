#!/bin/bash

# Cloud Master Day 1 - GitHub Actions Practice Automation Script
# 작성자: Cloud Master Team
# 목적: GitHub Actions CI/CD 파이프라인 실습 자동화

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
    
    # Git 설치 확인
    if ! command -v git &> /dev/null; then
        log_error "Git이 설치되지 않았습니다. 먼저 Git을 설치해주세요."
        exit 1
    fi
    
    # Node.js 설치 확인
    if ! command -v node &> /dev/null; then
        log_warning "Node.js가 설치되지 않았습니다. 자동으로 설치를 시도합니다."
        install_nodejs
    fi
    
    # GitHub CLI 설치 확인
    if ! command -v gh &> /dev/null; then
        log_warning "GitHub CLI가 설치되지 않았습니다. 수동으로 GitHub에 푸시해야 합니다."
    fi
    
    log_success "실습 환경 확인 완료"
}

# Node.js 설치
install_nodejs() {
    log_info "Node.js 설치 중..."
    
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        # Ubuntu/Debian
        curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
        sudo apt-get install -y nodejs
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        if command -v brew &> /dev/null; then
            brew install node
        else
            log_error "Homebrew가 설치되지 않았습니다. Node.js를 수동으로 설치해주세요."
            exit 1
        fi
    else
        log_error "지원되지 않는 운영체제입니다. Node.js를 수동으로 설치해주세요."
        exit 1
    fi
    
    log_success "Node.js 설치 완료"
}

# 1단계: 프로젝트 초기화
step1_project_initialization() {
    log_info "=== 1단계: 프로젝트 초기화 ==="
    
    # 실습용 디렉토리 생성
    log_info "실습용 프로젝트 디렉토리 생성:"
    mkdir -p ~/github-actions-practice
    cd ~/github-actions-practice
    
    # Git 저장소 초기화
    log_info "Git 저장소 초기화:"
    git init
    git config user.name "Cloud Master Student"
    git config user.email "student@cloudmaster.com"
    
    # package.json 생성
    log_info "package.json 생성:"
    cat > package.json << 'EOF'
{
  "name": "github-actions-practice",
  "version": "1.0.0",
  "description": "GitHub Actions CI/CD Practice Project",
  "main": "index.js",
  "scripts": {
    "test": "jest",
    "lint": "eslint .",
    "build": "webpack --mode production",
    "start": "node server.js",
    "dev": "node server.js"
  },
  "keywords": ["github-actions", "ci-cd", "automation"],
  "author": "Cloud Master Student",
  "license": "MIT",
  "devDependencies": {
    "jest": "^29.0.0",
    "eslint": "^8.0.0",
    "webpack": "^5.0.0",
    "webpack-cli": "^5.0.0"
  },
  "dependencies": {
    "express": "^4.18.0"
  }
}
EOF
    
    log_success "1단계 완료: 프로젝트 초기화"
}

# 2단계: 애플리케이션 코드 생성
step2_application_code() {
    log_info "=== 2단계: 애플리케이션 코드 생성 ==="
    
    # Express 서버 생성
    log_info "Express 서버 생성:"
    cat > server.js << 'EOF'
const express = require('express');
const app = express();
const PORT = process.env.PORT || 3000;

// 미들웨어
app.use(express.json());
app.use(express.static('public'));

// 라우트
app.get('/', (req, res) => {
    res.send(`
        <!DOCTYPE html>
        <html>
        <head>
            <title>GitHub Actions Practice</title>
            <style>
                body { font-family: Arial, sans-serif; margin: 40px; }
                .container { max-width: 600px; margin: 0 auto; }
                h1 { color: #333; }
                p { color: #666; }
                .status { background: #e7f5e7; padding: 10px; border-radius: 5px; }
            </style>
        </head>
        <body>
            <div class="container">
                <h1>🚀 GitHub Actions Practice App</h1>
                <p>This application is deployed using GitHub Actions CI/CD pipeline!</p>
                <div class="status">
                    <strong>Status:</strong> Running successfully ✅
                </div>
                <p>Environment: ${process.env.NODE_ENV || 'development'}</p>
                <p>Port: ${PORT}</p>
            </div>
        </body>
        </html>
    `);
});

app.get('/api/health', (req, res) => {
    res.json({ 
        status: 'healthy', 
        timestamp: new Date().toISOString(),
        version: '1.0.0'
    });
});

app.get('/api/status', (req, res) => {
    res.json({
        message: 'GitHub Actions CI/CD is working!',
        environment: process.env.NODE_ENV || 'development',
        uptime: process.uptime()
    });
});

// 서버 시작
app.listen(PORT, () => {
    console.log(`Server running on port ${PORT}`);
});

module.exports = app;
EOF
    
    # 테스트 파일 생성
    log_info "테스트 파일 생성:"
    mkdir -p tests
    cat > tests/server.test.js << 'EOF'
const request = require('supertest');
const app = require('../server');

describe('Server Tests', () => {
    test('GET / should return 200', async () => {
        const response = await request(app).get('/');
        expect(response.status).toBe(200);
        expect(response.text).toContain('GitHub Actions Practice');
    });

    test('GET /api/health should return health status', async () => {
        const response = await request(app).get('/api/health');
        expect(response.status).toBe(200);
        expect(response.body.status).toBe('healthy');
    });

    test('GET /api/status should return status info', async () => {
        const response = await request(app).get('/api/status');
        expect(response.status).toBe(200);
        expect(response.body.message).toContain('GitHub Actions');
    });
});
EOF
    
    # ESLint 설정 생성
    log_info "ESLint 설정 생성:"
    cat > .eslintrc.js << 'EOF'
module.exports = {
    env: {
        node: true,
        es2021: true,
        jest: true
    },
    extends: ['eslint:recommended'],
    parserOptions: {
        ecmaVersion: 12,
        sourceType: 'module'
    },
    rules: {
        'no-console': 'warn',
        'no-unused-vars': 'error',
        'semi': ['error', 'always'],
        'quotes': ['error', 'single']
    }
};
EOF
    
    # Jest 설정 생성
    log_info "Jest 설정 생성:"
    cat > jest.config.js << 'EOF'
module.exports = {
    testEnvironment: 'node',
    testMatch: ['**/tests/**/*.test.js'],
    collectCoverage: true,
    coverageDirectory: 'coverage',
    coverageReporters: ['text', 'lcov', 'html']
};
EOF
    
    log_success "2단계 완료: 애플리케이션 코드 생성"
}

# 3단계: GitHub Actions 워크플로우 생성
step3_github_actions_workflow() {
    log_info "=== 3단계: GitHub Actions 워크플로우 생성 ==="
    
    # .github/workflows 디렉토리 생성
    log_info "GitHub Actions 워크플로우 디렉토리 생성:"
    mkdir -p .github/workflows
    
    # 기본 CI 워크플로우 생성
    log_info "기본 CI 워크플로우 생성:"
    cat > .github/workflows/ci.yml << 'EOF'
name: CI Pipeline

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]

jobs:
  test:
    runs-on: ubuntu-latest

    strategy:
      matrix:
        node-version: [16.x, 18.x, 20.x]

    steps:
    - name: Checkout code
      uses: actions/checkout@v3

    - name: Setup Node.js ${{ matrix.node-version }}
      uses: actions/setup-node@v3
      with:
        node-version: ${{ matrix.node-version }}
        cache: 'npm'

    - name: Install dependencies
      run: npm ci

    - name: Run linting
      run: npm run lint

    - name: Run tests
      run: npm test

    - name: Build application
      run: npm run build

    - name: Upload build artifacts
      uses: actions/upload-artifact@v3
      with:
        name: build-files-${{ matrix.node-version }}
        path: dist/

  security-scan:
    runs-on: ubuntu-latest
    needs: test

    steps:
    - name: Checkout code
      uses: actions/checkout@v3

    - name: Run security audit
      run: npm audit --audit-level moderate

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
EOF
    
    # 고급 워크플로우 생성
    log_info "고급 워크플로우 생성:"
    cat > .github/workflows/advanced-ci.yml << 'EOF'
name: Advanced CI/CD Pipeline

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]
  workflow_dispatch:

env:
  NODE_VERSION: '18.x'

jobs:
  quality-checks:
    runs-on: ubuntu-latest
    outputs:
      should-deploy: ${{ steps.changes.outputs.any-changed }}

    steps:
    - name: Checkout code
      uses: actions/checkout@v3
      with:
        fetch-depth: 0

    - name: Detect changes
      uses: dorny/paths-filter@v2
      id: changes
      with:
        filters: |
          src:
            - 'src/**'
          tests:
            - 'tests/**'
          config:
            - 'package.json'
            - '*.config.js'

    - name: Setup Node.js
      uses: actions/setup-node@v3
      with:
        node-version: ${{ env.NODE_VERSION }}
        cache: 'npm'

    - name: Install dependencies
      run: npm ci

    - name: Run linting
      run: npm run lint

    - name: Run tests with coverage
      run: npm test -- --coverage

    - name: Upload coverage to Codecov
      uses: codecov/codecov-action@v3
      with:
        file: ./coverage/lcov.info

  build-and-test:
    runs-on: ubuntu-latest
    needs: quality-checks
    if: needs.quality-checks.outputs.should-deploy == 'true'

    steps:
    - name: Checkout code
      uses: actions/checkout@v3

    - name: Setup Node.js
      uses: actions/setup-node@v3
      with:
        node-version: ${{ env.NODE_VERSION }}
        cache: 'npm'

    - name: Install dependencies
      run: npm ci

    - name: Build application
      run: npm run build

    - name: Run integration tests
      run: npm test -- --testPathPattern=integration

    - name: Upload build artifacts
      uses: actions/upload-artifact@v3
      with:
        name: build-files
        path: dist/

  deploy:
    runs-on: ubuntu-latest
    needs: [quality-checks, build-and-test]
    if: github.ref == 'refs/heads/main' && needs.quality-checks.outputs.should-deploy == 'true'

    steps:
    - name: Checkout code
      uses: actions/checkout@v3

    - name: Download build artifacts
      uses: actions/download-artifact@v3
      with:
        name: build-files
        path: dist/

    - name: Deploy to staging
      run: |
        echo "Deploying to staging environment..."
        # 실제 배포 로직은 여기에 구현
        echo "Staging deployment completed!"

    - name: Notify deployment
      run: |
        echo "Deployment notification sent!"
        # Slack, Discord 등 알림 구현
EOF
    
    # Docker 워크플로우 생성
    log_info "Docker 워크플로우 생성:"
    cat > .github/workflows/docker.yml << 'EOF'
name: Docker Build and Push

on:
  push:
    branches: [ main ]
    tags: [ 'v*' ]
  pull_request:
    branches: [ main ]

jobs:
  docker:
    runs-on: ubuntu-latest

    steps:
    - name: Checkout code
      uses: actions/checkout@v3

    - name: Set up Docker Buildx
      uses: docker/setup-buildx-action@v2

    - name: Login to Docker Hub
      uses: docker/login-action@v2
      with:
        username: ${{ secrets.DOCKER_USERNAME }}
        password: ${{ secrets.DOCKER_PASSWORD }}

    - name: Extract metadata
      id: meta
      uses: docker/metadata-action@v4
      with:
        images: ${{ secrets.DOCKER_USERNAME }}/github-actions-practice
        tags: |
          type=ref,event=branch
          type=ref,event=pr
          type=semver,pattern={{version}}
          type=semver,pattern={{major}}.{{minor}}

    - name: Build and push Docker image
      uses: docker/build-push-action@v4
      with:
        context: .
        push: true
        tags: ${{ steps.meta.outputs.tags }}
        labels: ${{ steps.meta.outputs.labels }}
        cache-from: type=gha
        cache-to: type=gha,mode=max
EOF
    
    # Dockerfile 생성
    log_info "Dockerfile 생성:"
    cat > Dockerfile << 'EOF'
# 베이스 이미지
FROM node:18-alpine

# 작업 디렉토리 설정
WORKDIR /app

# 의존성 파일 복사
COPY package*.json ./

# 의존성 설치
RUN npm ci --only=production

# 애플리케이션 코드 복사
COPY . .

# 포트 노출
EXPOSE 3000

# 애플리케이션 실행
CMD ["npm", "start"]
EOF
    
    # .dockerignore 생성
    log_info ".dockerignore 생성:"
    cat > .dockerignore << 'EOF'
node_modules
npm-debug.log
.git
.gitignore
README.md
.env
.nyc_output
coverage
.nyc_output
.coverage
EOF
    
    log_success "3단계 완료: GitHub Actions 워크플로우 생성"
}

# 4단계: 의존성 설치 및 테스트
step4_install_and_test() {
    log_info "=== 4단계: 의존성 설치 및 테스트 ==="
    
    # 의존성 설치
    log_info "의플리케이션 의존성 설치:"
    npm install
    
    # 린팅 실행
    log_info "코드 린팅 실행:"
    npm run lint
    
    # 테스트 실행
    log_info "테스트 실행:"
    npm test
    
    # 빌드 실행
    log_info "애플리케이션 빌드:"
    npm run build
    
    log_success "4단계 완료: 의존성 설치 및 테스트"
}

# 5단계: Git 커밋 및 푸시
step5_git_commit_and_push() {
    log_info "=== 5단계: Git 커밋 및 푸시 ==="
    
    # 모든 파일 추가
    log_info "모든 파일 Git에 추가:"
    git add .
    
    # 커밋
    log_info "변경사항 커밋:"
    git commit -m "feat: Add GitHub Actions CI/CD pipeline

- Add basic CI workflow with testing and linting
- Add advanced CI workflow with quality checks
- Add Docker workflow for containerization
- Add comprehensive test suite
- Add ESLint configuration
- Add Jest testing framework
- Add Express.js web application

This commit sets up a complete CI/CD pipeline using GitHub Actions."
    
    # GitHub 저장소 생성 (GitHub CLI 사용)
    if command -v gh &> /dev/null; then
        log_info "GitHub 저장소 생성:"
        gh repo create github-actions-practice --public --source=. --remote=origin --push
    else
        log_warning "GitHub CLI가 설치되지 않았습니다. 수동으로 GitHub에 저장소를 생성하고 푸시해주세요."
        echo "다음 명령어를 실행하세요:"
        echo "  git remote add origin https://github.com/YOUR_USERNAME/github-actions-practice.git"
        echo "  git branch -M main"
        echo "  git push -u origin main"
    fi
    
    log_success "5단계 완료: Git 커밋 및 푸시"
}

# 6단계: 워크플로우 실행 및 확인
step6_workflow_execution() {
    log_info "=== 6단계: 워크플로우 실행 및 확인 ==="
    
    # 로컬에서 애플리케이션 실행
    log_info "로컬에서 애플리케이션 실행:"
    log_info "애플리케이션을 백그라운드에서 실행합니다..."
    nohup npm start > app.log 2>&1 &
    APP_PID=$!
    
    # 애플리케이션 시작 대기
    sleep 3
    
    # 애플리케이션 테스트
    log_info "애플리케이션 테스트:"
    if command -v curl &> /dev/null; then
        curl -s http://localhost:3000 | head -5
        curl -s http://localhost:3000/api/health
        curl -s http://localhost:3000/api/status
    else
        log_warning "curl이 설치되지 않았습니다. 브라우저에서 http://localhost:3000 접속해보세요."
    fi
    
    # 애플리케이션 종료
    log_info "애플리케이션 종료:"
    kill $APP_PID 2>/dev/null || true
    
    log_success "6단계 완료: 워크플로우 실행 및 확인"
}

# 7단계: Cloud Master CI/CD 파이프라인 연계
step7_cloud_master_integration() {
    log_info "=== 7단계: Cloud Master CI/CD 파이프라인 연계 ==="
    
    # Cloud Master CI/CD 파이프라인 확인
    log_info "Cloud Master CI/CD 파이프라인 확인:"
    if [ -f "../../../cloud-scripts/.github/workflows/cloud-master-ci-cd.yml" ]; then
        log_success "Cloud Master CI/CD 파이프라인을 찾았습니다."
        
        # 파이프라인 기능 설명
        log_info "Cloud Master CI/CD 파이프라인 기능:"
        echo "  - Docker 이미지 자동 빌드"
        echo "  - Docker Hub 자동 푸시"
        echo "  - AWS EC2 자동 배포"
        echo "  - GCP Compute Engine 자동 배포"
        echo "  - 헬스체크 및 알림"
        echo "  - 환경별 배포 관리"
        
        # 연계 방법 안내
        log_info "Cloud Master 파이프라인과 연계 방법:"
        echo "  1. 현재 프로젝트를 Cloud Master 저장소에 통합"
        echo "  2. cloud-scripts/.github/workflows/cloud-master-ci-cd.yml 사용"
        echo "  3. samples/day1/my-app/ 디렉토리에 프로젝트 배치"
        echo "  4. 통합된 CI/CD 파이프라인으로 자동 배포"
        
        # 통합 스크립트 실행 안내
        log_info "통합 자동화 스크립트 실행:"
        echo "  cd ../../../cloud-scripts"
        echo "  ./integrated-automation.sh aws --ci-cd-only"
        echo "  ./integrated-automation.sh gcp --ci-cd-only"
        
    else
        log_warning "Cloud Master CI/CD 파이프라인을 찾을 수 없습니다."
        log_info "cloud-scripts 디렉토리에 .github/workflows/cloud-master-ci-cd.yml 파일이 있는지 확인하세요."
    fi
    
    # 프로젝트를 Cloud Master 구조에 맞게 복사
    log_info "Cloud Master 구조에 맞게 프로젝트 복사:"
    if [ -d "../../../cloud-scripts/samples/day1/my-app" ]; then
        log_info "Cloud Master samples 디렉토리에 프로젝트 복사 중..."
        cp -r . ../../../cloud-scripts/samples/day1/my-app/
        log_success "프로젝트가 Cloud Master 구조에 복사되었습니다."
    else
        log_warning "Cloud Master samples 디렉토리를 찾을 수 없습니다."
    fi
    
    log_success "7단계 완료: Cloud Master CI/CD 파이프라인 연계"
}

# 8단계: 정리 및 요약
step8_cleanup_and_summary() {
    log_info "=== 8단계: 정리 및 요약 ==="
    
    # 생성된 파일 목록
    log_info "생성된 파일 목록:"
    find . -type f -name "*.js" -o -name "*.json" -o -name "*.yml" -o -name "Dockerfile" | sort
    
    # 워크플로우 파일 확인
    log_info "GitHub Actions 워크플로우 파일:"
    ls -la .github/workflows/
    
    # 실습 결과 요약
    log_success "=== GitHub Actions 실습 완료 ==="
    echo "✅ 프로젝트 초기화 및 설정"
    echo "✅ Express.js 웹 애플리케이션 생성"
    echo "✅ Jest 테스트 프레임워크 설정"
    echo "✅ ESLint 코드 품질 도구 설정"
    echo "✅ GitHub Actions CI 워크플로우 생성"
    echo "✅ 고급 CI/CD 파이프라인 설정"
    echo "✅ Docker 컨테이너화 설정"
    echo "✅ Cloud Master CI/CD 파이프라인 연계"
    echo "✅ Git 커밋 및 푸시"
    echo ""
    echo "🌐 로컬 테스트:"
    echo "  - 애플리케이션: http://localhost:3000"
    echo "  - 헬스 체크: http://localhost:3000/api/health"
    echo "  - 상태 확인: http://localhost:3000/api/status"
    echo ""
    echo "🚀 Cloud Master CI/CD:"
    echo "  - 통합 자동화 파이프라인"
    echo "  - AWS/GCP 자동 배포"
    echo "  - Docker Hub 자동 푸시"
    echo "  - 헬스체크 및 알림"
    echo ""
    echo "📁 프로젝트 위치: ~/github-actions-practice"
    echo "🔧 다음 단계: Cloud Master 통합 자동화 스크립트 실행"
}

# 메인 실행 함수
main() {
    log_info "Cloud Master Day 1 - GitHub Actions Practice Automation 시작"
    echo "================================================================"
    
    check_prerequisites
    step1_project_initialization
    step2_application_code
    step3_github_actions_workflow
    step4_install_and_test
    step5_git_commit_and_push
    step6_workflow_execution
    step7_cloud_master_integration
    step8_cleanup_and_summary
    
    log_success "모든 GitHub Actions 실습이 완료되었습니다!"
}

# 스크립트 실행
main "$@"
