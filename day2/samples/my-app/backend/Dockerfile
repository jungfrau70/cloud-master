# 멀티스테이지 빌드 - Build stage
FROM python:3.11-slim AS builder

# 작업 디렉토리 설정
WORKDIR /app

# 시스템 패키지 업데이트 및 의존성 설치
RUN apt-get update && apt-get install -y \
    gcc \
    libpq-dev \
    && rm -rf /var/lib/apt/lists/*

# Python 의존성 파일 복사
COPY requirements.txt .

# 가상환경 생성 및 의존성 설치
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"
RUN pip install --no-cache-dir -r requirements.txt

# Production stage
FROM python:3.11-slim AS production

# 작업 디렉토리 설정
WORKDIR /app

# 시스템 패키지 설치 (런타임 의존성만)
RUN apt-get update && apt-get install -y \
    libpq5 \
    && rm -rf /var/lib/apt/lists/*

# 가상환경 복사
COPY --from=builder /opt/venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# 비root 사용자 생성
RUN groupadd -r appuser && useradd -r -g appuser appuser

# 애플리케이션 코드 복사
COPY app.py .
COPY requirements.txt .

# 소유권 변경
RUN chown -R appuser:appuser /app
USER appuser

# 포트 노출
EXPOSE 3000

# 헬스체크
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD python -c "import requests; requests.get('http://localhost:3000/health')"

# 애플리케이션 실행
CMD ["gunicorn", "--bind", "0.0.0.0:3000", "--workers", "4", "--timeout", "30", "app:app"]
