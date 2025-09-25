# Node.js 18 버전을 베이스 이미지로 사용
FROM node:18

# 작업 디렉토리 설정
WORKDIR /app

# 패키지 파일 복사 (캐시 최적화를 위해 의존성 설치를 먼저)
COPY package*.json ./

# 의존성 설치
RUN npm install

# 소스 코드 복사
COPY . .

# 포트 3000 노출
EXPOSE 3000

# 애플리케이션 시작
CMD ["npm", "start"]
