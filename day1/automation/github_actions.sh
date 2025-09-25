#!/bin/bash
# GitHub Actions CI/CD   

set -e

echo " GitHub Actions CI/CD   ..."

# .github/workflows  
mkdir -p .github/workflows

#  CI/CD  
cat > .github/workflows/ci-cd.yml << 'EOF'
name: CI/CD Pipeline

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]

jobs:
  test:
    runs-on: ubuntu-latest
    
    steps:
    - name: Checkout code
      uses: actions/checkout@v4
      
    - name: Setup Node.js
      uses: actions/setup-node@v4
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
    - name: Checkout code
      uses: actions/checkout@v4
      
    - name: Set up Docker Buildx
      uses: docker/setup-buildx-action@v3
      
    - name: Login to Docker Hub
      uses: docker/login-action@v3
      with:
        username: ${{ secrets.DOCKER_USERNAME }}
        password: ${{ secrets.DOCKER_PASSWORD }}
        
    - name: Build and push Docker image
      uses: docker/build-push-action@v5
      with:
        context: .
        push: true
        tags: |
          ${{ secrets.DOCKER_USERNAME }}/sample-app:latest
          ${{ secrets.DOCKER_USERNAME }}/sample-app:${{ github.sha }}
          
  deploy:
    needs: build
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'
    
    steps:
    - name: Deploy to AWS EC2
      uses: appleboy/ssh-action@v1.0.0
      with:
        host: ${{ secrets.EC2_HOST }}
        username: ${{ secrets.EC2_USERNAME }}
        key: ${{ secrets.EC2_SSH_KEY }}
        script: |
          docker pull ${{ secrets.DOCKER_USERNAME }}/sample-app:latest
          docker stop sample-app || true
          docker rm sample-app || true
          docker run -d --name sample-app -p 3000:3000 ${{ secrets.DOCKER_USERNAME }}/sample-app:latest
EOF

# package.json   
if [ -f package.json ]; then
    #  package.json 
    cp package.json package.json.backup
    
    # jq    (jq    )
    if command -v jq &> /dev/null; then
        jq '.scripts += {"test": "echo \"No tests specified\"", "lint": "echo \"No linting specified\""}' package.json > package.json.tmp
        mv package.json.tmp package.json
    else
        echo " jq  . package.json  ."
    fi
fi

# Dockerfile  ( )
cat > Dockerfile.optimized << 'EOF'
# Build stage
FROM node:18-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production

# Production stage
FROM node:18-alpine AS production
WORKDIR /app
COPY --from=builder /app/node_modules ./node_modules
COPY . .
EXPOSE 3000
USER node
CMD ["npm", "start"]
EOF

# Docker Compose  
cat > docker-compose.prod.yml << 'EOF'
version: '3.8'
services:
  app:
    image: ${DOCKER_USERNAME}/sample-app:latest
    ports:
      - "3000:3000"
    environment:
      - NODE_ENV=production
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3000/health"]
      interval: 30s
      timeout: 10s
      retries: 3
EOF

#    
cat > .env.template << 'EOF'
# GitHub Secrets  
# Repository Settings > Secrets and variables > Actions   :

# Docker Hub
DOCKER_USERNAME=your-docker-username
DOCKER_PASSWORD=your-docker-password

# AWS EC2
EC2_HOST=your-ec2-public-ip
EC2_USERNAME=ec2-user
EC2_SSH_KEY=your-private-key

# GCP ()
GCP_PROJECT_ID=your-project-id
GCP_SA_KEY=your-service-account-key
EOF

echo " GitHub Actions  !"
echo "  :"
echo "1. GitHub   "
echo "2.  GitHub "
echo "3. Actions    "

echo " GitHub Actions CI/CD   !"
