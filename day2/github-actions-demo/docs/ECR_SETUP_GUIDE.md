# AWS ECR 설정 가이드

## 1. ECR 리포지토리 생성

### 스크립트 실행
```bash
# 기본 설정으로 생성 [ap-northeast-2, github-actions-demo-day2]
./scripts/create-ecr-repository.sh

# 또는 커스텀 설정으로 생성
./scripts/create-ecr-repository.sh ap-northeast-2 github-actions-demo-day2
```

### 수동 생성 ["AWS 콘솔"]
1. AWS 콘솔에서 ECR 서비스로 이동
2. "리포지토리 생성" 클릭
3. 리포지토리 이름: `github-actions-demo-day2`
4. 이미지 스캔 설정: "스캔 시 푸시" 활성화
5. 암호화: AES256 선택
6. 태그 변경 가능성: 변경 가능
7. 생명주기 정책: 기본 설정 사용

## 2. IAM 사용자 생성 및 권한 설정

### IAM 사용자 생성
1. AWS IAM 콘솔에서 "사용자" → "사용자 생성"
2. 사용자 이름: `itadmin`
3. 액세스 유형: "프로그래밍 방식 액세스"

### 정책 연결
다음 정책을 생성하고 사용자에게 연결:

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "ecr:GetAuthorizationToken",
                "ecr:BatchCheckLayerAvailability",
                "ecr:GetDownloadUrlForLayer",
                "ecr:BatchGetImage",
                "ecr:InitiateLayerUpload",
                "ecr:UploadLayerPart",
                "ecr:CompleteLayerUpload",
                "ecr:PutImage"
            ],
            "Resource": "*"
        }
    ]
}
```

## 3. GitHub Secrets 설정

리포지토리 설정 → Secrets and variables → Actions에서 다음 secrets를 추가:

### 필수 Secrets
- `AWS_ACCESS_KEY_ID`: IAM 사용자의 액세스 키 ID
- `AWS_SECRET_ACCESS_KEY`: IAM 사용자의 시크릿 액세스 키
- `AWS_REGION`: ECR 리전 ["예: ap-northeast-2"]
- `ECR_REPOSITORY`: ECR 리포지토리 이름 ["예: github-actions-demo-day2"]

### 자동 생성되는 값들
스크립트 실행 후 다음 값들을 복사해서 추가:
- `AWS_ACCOUNT_ID`: AWS 계정 ID
- `ECR_REGISTRY`: ECR 레지스트리 URL
- `ECR_REPOSITORY_URI`: 전체 ECR 리포지토리 URI

## 4. ECR 로그인 테스트

로컬에서 ECR 로그인 테스트:
```bash
# ECR 로그인
aws ecr get-login-password --region ap-northeast-2 | docker login --username AWS --password-stdin 123456789012.dkr.ecr.ap-northeast-2.amazonaws.com

# 이미지 빌드 및 푸시 테스트
docker build -t github-actions-demo-day2 .
docker tag github-actions-demo-day2:latest 123456789012.dkr.ecr.ap-northeast-2.amazonaws.com/github-actions-demo-day2:latest
docker push 123456789012.dkr.ecr.ap-northeast-2.amazonaws.com/github-actions-demo-day2:latest
```

## 5. 비용 최적화

### 생명주기 정책
- 최근 10개 이미지만 유지
- 태그 없는 이미지는 1일 후 삭제
- 7일 이상 된 이미지 자동 삭제

### 이미지 태그 전략
- `latest`: 최신 안정 버전
- `v1.0.0`: 버전 태그
- `main-abc123`: 브랜치-커밋 해시
- `pr-123`: Pull Request 번호

## 6. 보안 고려사항

### 이미지 스캔
- 푸시 시 자동 스캔 활성화
- 취약점 발견 시 알림 설정
- 심각한 취약점 발견 시 푸시 차단

### 접근 제어
- IAM 정책으로 최소 권한 원칙 적용
- 리포지토리별 접근 권한 분리
- 정기적인 액세스 키 로테이션

## 7. 모니터링

### CloudWatch 메트릭
- 이미지 푸시/풀 횟수
- 스토리지 사용량
- 스캔 결과

### 알림 설정
- 이미지 스캔 실패 시 알림
- 스토리지 사용량 임계값 초과 시 알림
- 비정상적인 접근 시 알림

## 8. 문제 해결

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
```
