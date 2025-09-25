# AWS ECR 마이그레이션 완료 요약

## 🎯 변경 사항

### 1. Docker Registry 변경
- **이전**: Docker Hub [`docker.io`]
- **현재**: AWS ECR [`{ACCOUNT_ID}.dkr.ecr.{REGION}.amazonaws.com`]

### 2. 워크플로우 최적화
- Docker Hub rate limit 문제 해결
- AWS ECR 전용 인증 방식 적용
- 멀티 스테이지 빌드로 이미지 크기 최적화

### 3. 보안 강화
- 이미지 스캔 자동화
- 생명주기 정책으로 오래된 이미지 자동 삭제
- 최소 권한 IAM 정책 적용

## 📋 필요한 GitHub Secrets

다음 secrets를 GitHub 리포지토리에 추가해야 합니다:

```bash
# AWS 자격 증명
AWS_ACCESS_KEY_ID=AKIA...
AWS_SECRET_ACCESS_KEY=...

# ECR 설정
AWS_ACCOUNT_ID=123456789012
AWS_REGION=ap-northeast-2
ECR_REPOSITORY=github-actions-demo-day2
```

## 🚀 사용 방법

### 1. ECR 리포지토리 생성
```bash
./scripts/create-ecr-repository.sh
```

### 2. 생명주기 정책 적용
```bash
./scripts/apply-ecr-lifecycle-policy.sh
```

### 3. GitHub Secrets 설정
리포지토리 설정 → Secrets and variables → Actions에서 위의 secrets 추가

### 4. 워크플로우 실행
```bash
git push origin day2-advanced
```

## 📊 이미지 태그 전략

### 프로덕션 이미지
- `latest`: 최신 안정 버전
- `v2.0.0`: 버전 태그
- `main-abc123`: 브랜치-커밋 해시

### 개발 이미지
- `develop-abc123`: 개발 브랜치
- `feature-abc123`: 기능 브랜치
- `pr-123`: Pull Request 번호

### 백업 이미지
- `backup-20241201-143022`: Blue-Green 배포용 백업

## 🔧 최적화 사항

### Dockerfile 개선
- 멀티 스테이지 빌드로 이미지 크기 최적화
- 보안 업데이트 자동화
- dumb-init로 시그널 처리 개선
- ECR 스캔 최적화된 헬스체크

### 생명주기 정책
- 프로덕션 이미지: 최대 10개 유지
- 브랜치 이미지: 최대 5개 유지
- PR 이미지: 최대 3개 유지
- 태그 없는 이미지: 1일 후 삭제
- 백업 이미지: 7일 후 삭제

## 💰 비용 최적화

### ECR 비용 구조
- 스토리지: $0.10/GB/월
- 데이터 전송: 무료 ["같은 리전 내"]
- API 요청: 무료 ["월 500,000회까지"]

### 예상 월 비용 ["이미지 10개 기준"]
- 스토리지: ~$1-2/월
- 데이터 전송: $0
- API 요청: $0
- **총 예상 비용: $1-2/월**

## 🔍 모니터링

### CloudWatch 메트릭
- 이미지 푸시/풀 횟수
- 스토리지 사용량
- 스캔 결과

### 알림 설정
- 이미지 스캔 실패 시 알림
- 스토리지 사용량 임계값 초과 시 알림
- 비정상적인 접근 시 알림

## 🛠️ 문제 해결

### 일반적인 오류
1. **권한 부족**: IAM 정책 확인
2. **리전 불일치**: AWS_REGION 설정 확인
3. **인증 실패**: 액세스 키 유효성 확인
4. **이미지 푸시 실패**: ECR 리포지토리 존재 여부 확인

### 디버깅 명령어
```bash
# AWS 자격 증명 확인
aws sts get-caller-identity

# ECR 리포지토리 목록 확인
aws ecr describe-repositories --region ap-northeast-2

# 이미지 목록 확인
aws ecr list-images --repository-name github-actions-demo-day2 --region ap-northeast-2

# 생명주기 정책 확인
aws ecr get-lifecycle-policy --repository-name github-actions-demo-day2 --region ap-northeast-2
```

## 🎉 마이그레이션 완료!

이제 Docker Hub rate limit 없이 안정적인 CI/CD 파이프라인을 사용할 수 있습니다.

### 다음 단계
1. ECR 리포지토리 생성
2. GitHub Secrets 설정
3. 워크플로우 테스트
4. 모니터링 설정
