# MCP Cloud Master Day1 실습용 Dockerfile
# Node.js 기반 웹 애플리케이션

# 1단계: 빌드 환경
FROM node:18-alpine AS builder

# 작업 디렉토리 설정
WORKDIR /app

# 패키지 파일 복사
COPY package*.json ./

# 의존성 설치
RUN npm ci --only=production

# 소스 코드 복사
COPY . .

# 애플리케이션 빌드
RUN npm run build

# 2단계: 프로덕션 환경
FROM node:18-alpine AS production

# 보안을 위한 non-root 사용자 생성
RUN addgroup -g 1001 -S nodejs
RUN adduser -S nextjs -u 1001

# 작업 디렉토리 설정
WORKDIR /app

# 패키지 파일 복사
COPY package*.json ./

# 프로덕션 의존성만 설치
RUN npm ci --only=production && npm cache clean --force

# 빌드된 애플리케이션 복사
COPY --from=builder --chown=nextjs:nodejs /app/dist ./dist
COPY --from=builder --chown=nextjs:nodejs /app/public ./public

# 사용자 변경
USER nextjs

# 포트 노출
EXPOSE 8080

# 환경 변수 설정
ENV NODE_ENV=production
ENV PORT=8080

# 헬스체크 추가
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:8080/health || exit 1

# 애플리케이션 실행
CMD ["node", "dist/server.js"]