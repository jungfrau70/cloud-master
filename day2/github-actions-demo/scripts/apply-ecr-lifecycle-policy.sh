#!/bin/bash

# ECR 생명주기 정책 적용 스크립트
# 사용법: ./apply-ecr-lifecycle-policy.sh [리전] [리포지토리명]

set -e

# 기본값 설정
REGION=${1:-ap-northeast-2}
REPOSITORY_NAME=${2:-github-actions-demo-day2}

echo "🔄 ECR 생명주기 정책 적용 중..."
echo "리전: $REGION"
echo "리포지토리명: $REPOSITORY_NAME"

# AWS CLI 설치 확인
if ! command -v aws &> /dev/null; then
    echo "❌ AWS CLI가 설치되지 않았습니다."
    exit 1
fi

# AWS 자격 증명 확인
if ! aws sts get-caller-identity &> /dev/null; then
    echo "❌ AWS 자격 증명이 설정되지 않았습니다."
    exit 1
fi

# 생명주기 정책 적용
echo "📋 생명주기 정책 적용 중..."
aws ecr put-lifecycle-policy \
    --repository-name $REPOSITORY_NAME \
    --region $REGION \
    --lifecycle-policy-text file://scripts/ecr-lifecycle-policy.json

echo "✅ ECR 생명주기 정책이 성공적으로 적용되었습니다!"

# 현재 정책 확인
echo "📊 현재 적용된 생명주기 정책:"
aws ecr get-lifecycle-policy \
    --repository-name $REPOSITORY_NAME \
    --region $REGION \
    --query 'lifecyclePolicyText' \
    --output text | jq .

echo ""
echo "🎯 정책 요약:"
echo "   - 프로덕션 이미지 (v*, latest): 최대 10개 유지"
echo "   - 브랜치 이미지 (main-*, develop-*, feature-*): 최대 5개 유지"
echo "   - PR 이미지 (pr-*): 최대 3개 유지"
echo "   - 태그 없는 이미지: 1일 후 삭제"
echo "   - 백업 이미지 (backup-*): 7일 후 삭제"
