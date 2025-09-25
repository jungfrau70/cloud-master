#!/bin/bash

# GCP 간단 테스트 스크립트

echo "🚀 GCP 간단 테스트 시작"

# GCP CLI 확인
if command -v gcloud &> /dev/null; then
    echo "✅ GCP CLI 설치됨"
    gcloud --version
else
    echo "❌ GCP CLI 설치되지 않음"
fi

# GCP 프로젝트 확인
if gcloud config get-value project &> /dev/null; then
    echo "✅ GCP 프로젝트 설정됨: $(gcloud config get-value project)"
else
    echo "❌ GCP 프로젝트 설정되지 않음"
fi

# GCP 인증 확인
if gcloud auth list --filter=status:ACTIVE --format="value(account)" | head -1 &> /dev/null; then
    echo "✅ GCP 인증됨: $(gcloud auth list --filter=status:ACTIVE --format='value(account)' | head -1)"
else
    echo "❌ GCP 인증되지 않음"
fi

# GCP VM 목록 확인
echo "📋 GCP VM 목록:"
gcloud compute instances list --format="table(name,zone,status,EXTERNAL_IP)" || echo "VM 목록 조회 실패"

echo "✅ GCP 간단 테스트 완료"
