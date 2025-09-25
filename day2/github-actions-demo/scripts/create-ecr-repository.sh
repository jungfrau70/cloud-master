#!/bin/bash

# AWS ECR 리포지토리 생성 스크립트
# 사용법: ./create-ecr-repository.sh [리전] [리포지토리명]

set -e

# 기본값 설정
REGION=${1:-ap-northeast-2}
REPOSITORY_NAME=${2:-github-actions-demo-day2}

echo "🚀 AWS ECR 리포지토리 생성 시작..."
echo "리전: $REGION"
echo "리포지토리명: $REPOSITORY_NAME"

# AWS CLI 설치 확인
if ! command -v aws &> /dev/null; then
    echo "❌ AWS CLI가 설치되지 않았습니다."
    echo "다음 명령어로 설치하세요:"
    echo "curl 'https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip' -o 'awscliv2.zip'"
    echo "unzip awscliv2.zip"
    echo "sudo ./aws/install"
    exit 1
fi

# AWS 자격 증명 확인
if ! aws sts get-caller-identity &> /dev/null; then
    echo "❌ AWS 자격 증명이 설정되지 않았습니다."
    echo "다음 명령어로 설정하세요:"
    echo "aws configure"
    exit 1
fi

# ECR 리포지토리 생성
echo "📦 ECR 리포지토리 생성 중..."
aws ecr create-repository \
    --repository-name $REPOSITORY_NAME \
    --region $REGION \
    --image-scanning-configuration scanOnPush=true \
    --encryption-configuration encryptionType=AES256 \
    --image-tag-mutability MUTABLE || echo "⚠️ 리포지토리가 이미 존재할 수 있습니다."

# 생명주기 정책 적용 (별도로 실행)
echo "📋 생명주기 정책 적용 중..."
if [ -f "scripts/ecr-lifecycle-policy.json" ]; then
    aws ecr put-lifecycle-policy \
        --repository-name $REPOSITORY_NAME \
        --region $REGION \
        --lifecycle-policy-text file://scripts/ecr-lifecycle-policy.json
    echo "✅ 생명주기 정책이 적용되었습니다."
else
    echo "⚠️ 생명주기 정책 파일이 없습니다. 기본 정책을 생성합니다."
    # 기본 생명주기 정책 생성
    cat > scripts/ecr-lifecycle-policy.json << 'EOF'
{
    "rules": [
        {
            "rulePriority": 1,
            "description": "Keep last 10 images",
            "selection": {
                "tagStatus": "tagged",
                "countType": "imageCountMoreThan",
                "countNumber": 10
            },
            "action": {
                "type": "expire"
            }
        },
        {
            "rulePriority": 2,
            "description": "Delete untagged images older than 1 day",
            "selection": {
                "tagStatus": "untagged",
                "countType": "sinceImagePushed",
                "countUnit": "days",
                "countNumber": 1
            },
            "action": {
                "type": "expire"
            }
        }
    ]
}
EOF
    aws ecr put-lifecycle-policy \
        --repository-name $REPOSITORY_NAME \
        --region $REGION \
        --lifecycle-policy-text file://scripts/ecr-lifecycle-policy.json
    echo "✅ 기본 생명주기 정책이 적용되었습니다."
fi

# 리포지토리 URI 가져오기
REPOSITORY_URI=$(aws ecr describe-repositories \
    --repository-names $REPOSITORY_NAME \
    --region $REGION \
    --query 'repositories[0].repositoryUri' \
    --output text)

echo "✅ ECR 리포지토리 생성 완료!"
echo "📋 리포지토리 정보:"
echo "   이름: $REPOSITORY_NAME"
echo "   URI: $REPOSITORY_URI"
echo "   리전: $REGION"

# 로그인 명령어 생성
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo ""
echo "🔐 ECR 로그인 명령어:"
echo "aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com"

# GitHub Secrets에 필요한 정보 출력
echo ""
echo "🔑 GitHub Secrets에 추가할 정보:"
echo "   AWS_ACCOUNT_ID: $ACCOUNT_ID"
echo "   AWS_REGION: $REGION"
echo "   ECR_REPOSITORY: $REPOSITORY_NAME"
echo "   ECR_REGISTRY: $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com"
echo "   ECR_REPOSITORY_URI: $REPOSITORY_URI"

# IAM 정책 생성 (선택사항)
echo ""
echo "📝 IAM 정책 생성 (GitHub Actions용):"
cat << EOF
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
EOF

echo ""
echo "🎉 ECR 설정이 완료되었습니다!"
echo "다음 단계:"
echo "1. GitHub Secrets에 위의 정보들을 추가하세요"
echo "2. IAM 사용자를 생성하고 위의 정책을 연결하세요"
echo "3. 워크플로우를 실행해보세요"
