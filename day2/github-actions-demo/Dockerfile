# ECR 최적화된 프로덕션용 Dockerfile
# Docker Hub rate limit 우회를 위해 공식 Node.js 이미지 사용
FROM node:18-alpine AS base

# 보안 업데이트 및 필수 패키지 설치
RUN apk update && apk upgrade && \
    apk add --no-cache dumb-init curl && \
    rm -rf /var/cache/apk/*

# 비root 사용자 생성
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nextjs -u 1001

# 의존성 설치 단계
FROM base AS deps
WORKDIR /app

# package.json과 package-lock.json만 먼저 복사 (캐시 최적화)
COPY package*.json ./

# 프로덕션 의존성만 설치 및 보안 검사
RUN npm install --omit=dev && \
    npm audit --audit-level=moderate && \
    npm cache clean --force && \
    chown -R nextjs:nodejs /app

# 빌드 단계
FROM base AS builder
WORKDIR /app

# 모든 의존성 설치 (빌드용)
COPY package*.json ./
RUN npm install

# 소스 코드 복사 및 빌드
COPY . .
RUN chown -R nextjs:nodejs /app
USER nextjs

# 애플리케이션 빌드 (필요한 경우)
# RUN npm run build

# 프로덕션 단계
FROM base AS runner
WORKDIR /app

# 프로덕션 의존성만 복사
COPY --from=deps --chown=nextjs:nodejs /app/node_modules ./node_modules

# 필요한 소스 코드만 복사 (보안 강화)
COPY --chown=nextjs:nodejs src/ ./src/
COPY --chown=nextjs:nodejs package*.json ./

# 비root 사용자로 전환
USER nextjs

# 포트 노출
EXPOSE 3000

# 환경 변수 설정
ENV NODE_ENV=production
ENV PORT=3000

# 헬스 체크 (ECR 스캔 최적화)
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
  CMD node -e "require('http').get('http://localhost:3000/health', (res) => { process.exit(res.statusCode === 200 ? 0 : 1) })" || exit 1

# 메타데이터 라벨 (ECR 스캔 및 관리용)
LABEL maintainer="GitHub Actions Demo"
LABEL version="2.0.0"
LABEL description="Advanced CI/CD Pipeline Demo with ECR"
LABEL org.opencontainers.image.source="https://github.com/jungfrau70/github-actions-demo-day2"

# dumb-init를 사용하여 시그널 처리 최적화
ENTRYPOINT ["dumb-init", "--"]
CMD ["node", "src/app.js"]