#!/bin/bash

# Cloud Master AI 기반 실시간 질문 답변 시스템

# 사용법 함수
usage() {
  echo "Usage: $0 [--ask QUESTION] [--interactive] [--context CONTEXT] [--skill-level LEVEL]"
  echo "  --ask QUESTION: 특정 질문에 대한 답변 요청"
  echo "  --interactive: 대화형 모드로 실행"
  echo "  --context CONTEXT: 질문의 맥락 지정 (예: 'aws', 'gcp', 'kubernetes')"
  echo "  --skill-level LEVEL: 기술 수준 지정 (초급, 중급, 고급)"
  exit 1
}

# 인자 확인
if [ $# -eq 0 ]; then
  usage
fi

QUESTION=""
INTERACTIVE=false
CONTEXT=""
SKILL_LEVEL="중급"

# 옵션 파싱
while [[ $# -gt 0 ]]; do
  case $1 in
    --ask)
      QUESTION="$2"
      shift 2
      ;;
    --interactive)
      INTERACTIVE=true
      shift
      ;;
    --context)
      CONTEXT="$2"
      shift 2
      ;;
    --skill-level)
      SKILL_LEVEL="$2"
      shift 2
      ;;
    *)
      shift
      ;;
  esac
done

# AI 답변 생성 함수
generate_ai_answer() {
  local question="$1"
  local context="$2"
  local skill_level="$3"
  
  echo "🤖 AI가 답변을 생성하고 있습니다..."
  
  # 질문 분석
  local question_type=""
  local keywords=""
  
  # 질문 유형 분석
  if [[ "$question" =~ (어떻게|how|방법) ]]; then
    question_type="how-to"
  elif [[ "$question" =~ (무엇|what|이해) ]]; then
    question_type="concept"
  elif [[ "$question" =~ (왜|why|이유) ]]; then
    question_type="explanation"
  elif [[ "$question" =~ (오류|error|문제|troubleshoot) ]]; then
    question_type="troubleshooting"
  else
    question_type="general"
  fi
  
  # 키워드 추출
  keywords=$(echo "$question" | tr ' ' '\n' | grep -E "(aws|gcp|kubernetes|docker|cloud|vm|instance|cluster|monitoring|cost|security|network)" | tr '\n' ' ')
  
  # 맥락별 답변 생성
  case $context in
    "aws")
      generate_aws_answer "$question" "$question_type" "$skill_level"
      ;;
    "gcp")
      generate_gcp_answer "$question" "$question_type" "$skill_level"
      ;;
    "kubernetes")
      generate_kubernetes_answer "$question" "$question_type" "$skill_level"
      ;;
    "docker")
      generate_docker_answer "$question" "$question_type" "$skill_level"
      ;;
    "monitoring")
      generate_monitoring_answer "$question" "$question_type" "$skill_level"
      ;;
    "cost")
      generate_cost_answer "$question" "$question_type" "$skill_level"
      ;;
    *)
      generate_general_answer "$question" "$question_type" "$skill_level"
      ;;
  esac
}

# AWS 관련 답변 생성
generate_aws_answer() {
  local question="$1"
  local question_type="$2"
  local skill_level="$3"
  
  case $question_type in
    "how-to")
      echo "📚 AWS 실습 가이드:"
      echo "1. AWS CLI 설정 확인: aws configure list"
      echo "2. 리전 설정: aws configure set region ap-northeast-2"
      echo "3. 리소스 생성: aws ec2 create-instance --help"
      echo "4. 상태 확인: aws ec2 describe-instances"
      echo ""
      echo "💡 실습 팁:"
      echo "- 실습 전에 AWS Free Tier 한도 확인"
      echo "- 리소스 생성 후 반드시 정리 실행"
      echo "- 비용 모니터링 설정 권장"
      ;;
    "concept")
      echo "🔍 AWS 핵심 개념:"
      echo "• EC2: 가상 서버 인스턴스"
      echo "• VPC: 가상 네트워크 환경"
      echo "• S3: 객체 스토리지 서비스"
      echo "• IAM: 사용자 및 권한 관리"
      echo "• CloudWatch: 모니터링 및 로깅"
      echo ""
      echo "📖 학습 자료:"
      echo "- AWS 공식 문서: https://docs.aws.amazon.com/"
      echo "- AWS Free Tier 가이드"
      echo "- Cloud Master Day1 실습 가이드"
      ;;
    "troubleshooting")
      echo "🔧 AWS 문제 해결:"
      echo "1. 권한 오류: IAM 역할 및 정책 확인"
      echo "2. 리소스 생성 실패: 서비스 한도 확인"
      echo "3. 네트워크 문제: 보안 그룹 및 VPC 설정 확인"
      echo "4. 비용 초과: 예산 설정 및 알림 확인"
      echo ""
      echo "🆘 도움말:"
      echo "- AWS Support Center"
      echo "- Cloud Master 커뮤니티"
      echo "- 실습 가이드 문제 해결 섹션"
      ;;
    *)
      echo "🌐 AWS 종합 정보:"
      echo "AWS는 Amazon Web Services의 약자로, 클라우드 컴퓨팅 서비스를 제공합니다."
      echo "Cloud Master 과정에서는 EC2, VPC, S3, IAM 등의 핵심 서비스를 학습합니다."
      echo ""
      echo "🎯 학습 목표:"
      echo "- AWS 기본 서비스 이해"
      echo "- 실습 환경 구축 능력"
      echo "- 비용 최적화 전략 수립"
      ;;
  esac
}

# GCP 관련 답변 생성
generate_gcp_answer() {
  local question="$1"
  local question_type="$2"
  local skill_level="$3"
  
  case $question_type in
    "how-to")
      echo "📚 GCP 실습 가이드:"
      echo "1. gcloud CLI 설정: gcloud auth login"
      echo "2. 프로젝트 설정: gcloud config set project PROJECT_ID"
      echo "3. 리소스 생성: gcloud compute instances create"
      echo "4. 상태 확인: gcloud compute instances list"
      echo ""
      echo "💡 실습 팁:"
      echo "- GCP Free Tier 한도 확인"
      echo "- 리소스 생성 후 정리 실행"
      echo "- 비용 모니터링 설정"
      ;;
    "concept")
      echo "🔍 GCP 핵심 개념:"
      echo "• Compute Engine: 가상 머신 인스턴스"
      echo "• VPC: 가상 네트워크"
      echo "• Cloud Storage: 객체 스토리지"
      echo "• IAM: 사용자 및 권한 관리"
      echo "• Cloud Monitoring: 모니터링 및 로깅"
      echo ""
      echo "📖 학습 자료:"
      echo "- GCP 공식 문서: https://cloud.google.com/docs"
      echo "- GCP Free Tier 가이드"
      echo "- Cloud Master Day1 실습 가이드"
      ;;
    "troubleshooting")
      echo "🔧 GCP 문제 해결:"
      echo "1. 권한 오류: IAM 역할 및 권한 확인"
      echo "2. 리소스 생성 실패: 서비스 한도 확인"
      echo "3. 네트워크 문제: 방화벽 규칙 및 VPC 설정 확인"
      echo "4. 비용 초과: 예산 설정 및 알림 확인"
      echo ""
      echo "🆘 도움말:"
      echo "- GCP Support Center"
      echo "- Cloud Master 커뮤니티"
      echo "- 실습 가이드 문제 해결 섹션"
      ;;
    *)
      echo "🌐 GCP 종합 정보:"
      echo "GCP는 Google Cloud Platform의 약자로, Google의 클라우드 컴퓨팅 서비스입니다."
      echo "Cloud Master 과정에서는 Compute Engine, VPC, Cloud Storage, IAM 등을 학습합니다."
      echo ""
      echo "🎯 학습 목표:"
      echo "- GCP 기본 서비스 이해"
      echo "- 실습 환경 구축 능력"
      echo "- 비용 최적화 전략 수립"
      ;;
  esac
}

# Kubernetes 관련 답변 생성
generate_kubernetes_answer() {
  local question="$1"
  local question_type="$2"
  local skill_level="$3"
  
  case $question_type in
    "how-to")
      echo "📚 Kubernetes 실습 가이드:"
      echo "1. 클러스터 생성: gcloud container clusters create"
      echo "2. 클러스터 연결: gcloud container clusters get-credentials"
      echo "3. 애플리케이션 배포: kubectl apply -f deployment.yaml"
      echo "4. 상태 확인: kubectl get pods, kubectl get services"
      echo ""
      echo "💡 실습 팁:"
      echo "- GKE 또는 EKS 클러스터 사용"
      echo "- 네임스페이스 활용"
      echo "- 모니터링 도구 설치"
      ;;
    "concept")
      echo "🔍 Kubernetes 핵심 개념:"
      echo "• Pod: 컨테이너 실행 단위"
      echo "• Deployment: 애플리케이션 배포 관리"
      echo "• Service: 네트워크 접근 제공"
      echo "• Ingress: 외부 접근 관리"
      echo "• ConfigMap/Secret: 설정 및 보안 정보 관리"
      echo ""
      echo "📖 학습 자료:"
      echo "- Kubernetes 공식 문서"
      echo "- Cloud Master Day2 실습 가이드"
      echo "- kubectl 치트시트"
      ;;
    "troubleshooting")
      echo "🔧 Kubernetes 문제 해결:"
      echo "1. Pod 상태 확인: kubectl describe pod POD_NAME"
      echo "2. 로그 확인: kubectl logs POD_NAME"
      echo "3. 이벤트 확인: kubectl get events"
      echo "4. 리소스 확인: kubectl top pods"
      echo ""
      echo "🆘 도움말:"
      echo "- Kubernetes 공식 문제 해결 가이드"
      echo "- Cloud Master 커뮤니티"
      echo "- 실습 가이드 문제 해결 섹션"
      ;;
    *)
      echo "🌐 Kubernetes 종합 정보:"
      echo "Kubernetes는 컨테이너 오케스트레이션 플랫폼입니다."
      echo "Cloud Master 과정에서는 GKE/EKS를 통해 Kubernetes를 학습합니다."
      echo ""
      echo "🎯 학습 목표:"
      echo "- Kubernetes 기본 개념 이해"
      echo "- 컨테이너 애플리케이션 배포"
      echo "- 서비스 및 인그레스 설정"
      ;;
  esac
}

# Docker 관련 답변 생성
generate_docker_answer() {
  local question="$1"
  local question_type="$2"
  local skill_level="$3"
  
  case $question_type in
    "how-to")
      echo "📚 Docker 실습 가이드:"
      echo "1. 이미지 빌드: docker build -t my-app ."
      echo "2. 컨테이너 실행: docker run -p 3000:3000 my-app"
      echo "3. 이미지 푸시: docker push gcr.io/PROJECT_ID/my-app"
      echo "4. 컨테이너 관리: docker ps, docker logs, docker stop"
      echo ""
      echo "💡 실습 팁:"
      echo "- Dockerfile 최적화"
      echo "- 멀티스테이지 빌드 활용"
      echo "- 이미지 크기 최적화"
      ;;
    "concept")
      echo "🔍 Docker 핵심 개념:"
      echo "• Image: 애플리케이션 패키지"
      echo "• Container: 실행 중인 인스턴스"
      echo "• Dockerfile: 이미지 빌드 스크립트"
      echo "• Registry: 이미지 저장소"
      echo "• Docker Compose: 다중 컨테이너 관리"
      echo ""
      echo "📖 학습 자료:"
      echo "- Docker 공식 문서"
      echo "- Cloud Master Day1 실습 가이드"
      echo "- Docker 치트시트"
      ;;
    "troubleshooting")
      echo "🔧 Docker 문제 해결:"
      echo "1. 컨테이너 상태 확인: docker ps -a"
      echo "2. 로그 확인: docker logs CONTAINER_ID"
      echo "3. 리소스 사용량: docker stats"
      echo "4. 이미지 정리: docker system prune"
      echo ""
      echo "🆘 도움말:"
      echo "- Docker 공식 문제 해결 가이드"
      echo "- Cloud Master 커뮤니티"
      echo "- 실습 가이드 문제 해결 섹션"
      ;;
    *)
      echo "🌐 Docker 종합 정보:"
      echo "Docker는 컨테이너화 플랫폼으로, 애플리케이션을 패키지화합니다."
      echo "Cloud Master 과정에서는 Docker를 통해 애플리케이션을 컨테이너화합니다."
      echo ""
      echo "🎯 학습 목표:"
      echo "- Docker 기본 개념 이해"
      echo "- 컨테이너 이미지 빌드"
      echo "- 컨테이너 배포 및 관리"
      ;;
  esac
}

# 모니터링 관련 답변 생성
generate_monitoring_answer() {
  local question="$1"
  local question_type="$2"
  local skill_level="$3"
  
  case $question_type in
    "how-to")
      echo "📚 모니터링 실습 가이드:"
      echo "1. Prometheus 설치: helm install prometheus prometheus-community/kube-prometheus-stack"
      echo "2. Grafana 설정: kubectl port-forward svc/prometheus-grafana 3000:80"
      echo "3. 대시보드 생성: Grafana에서 커스텀 대시보드 생성"
      echo "4. 알림 설정: AlertManager 규칙 구성"
      echo ""
      echo "💡 실습 팁:"
      echo "- 메트릭 수집 전략 수립"
      echo "- 알림 임계값 적절히 설정"
      echo "- 대시보드 정기적 업데이트"
      ;;
    "concept")
      echo "🔍 모니터링 핵심 개념:"
      echo "• Prometheus: 메트릭 수집 및 저장"
      echo "• Grafana: 시각화 및 대시보드"
      echo "• AlertManager: 알림 관리"
      echo "• Node Exporter: 시스템 메트릭 수집"
      echo "• Service Discovery: 자동 메트릭 수집"
      echo ""
      echo "📖 학습 자료:"
      echo "- Prometheus 공식 문서"
      echo "- Grafana 공식 문서"
      echo "- Cloud Master Day3 실습 가이드"
      ;;
    "troubleshooting")
      echo "🔧 모니터링 문제 해결:"
      echo "1. 메트릭 수집 확인: curl http://prometheus:9090/api/v1/targets"
      echo "2. 알림 상태 확인: curl http://alertmanager:9093/api/v1/alerts"
      echo "3. 대시보드 로드 확인: Grafana UI 접속 테스트"
      echo "4. 리소스 사용량: kubectl top pods -n monitoring"
      echo ""
      echo "🆘 도움말:"
      echo "- Prometheus 문제 해결 가이드"
      echo "- Cloud Master 커뮤니티"
      echo "- 실습 가이드 문제 해결 섹션"
      ;;
    *)
      echo "🌐 모니터링 종합 정보:"
      echo "모니터링은 시스템의 상태와 성능을 실시간으로 추적하는 것입니다."
      echo "Cloud Master 과정에서는 Prometheus, Grafana를 통해 모니터링을 학습합니다."
      echo ""
      echo "🎯 학습 목표:"
      echo "- 모니터링 시스템 구축"
      echo "- 메트릭 수집 및 시각화"
      echo "- 알림 시스템 설정"
      ;;
  esac
}

# 비용 관련 답변 생성
generate_cost_answer() {
  local question="$1"
  local question_type="$2"
  local skill_level="$3"
  
  case $question_type in
    "how-to")
      echo "📚 비용 최적화 실습 가이드:"
      echo "1. 비용 분석: aws ce get-cost-and-usage"
      echo "2. 예산 설정: aws budgets create-budget"
      echo "3. 리소스 정리: aws ec2 describe-instances --filters 'Name=state-name,Values=stopped'"
      echo "4. 최적화 권장사항: aws ce get-right-sizing-recommendation"
      echo ""
      echo "💡 실습 팁:"
      echo "- 정기적인 비용 검토"
      echo "- 사용하지 않는 리소스 정리"
      echo "- 예약 인스턴스 활용"
      ;;
    "concept")
      echo "🔍 비용 최적화 핵심 개념:"
      echo "• Right Sizing: 적절한 리소스 크기 선택"
      echo "• Reserved Instances: 예약 인스턴스 활용"
      echo "• Spot Instances: 스팟 인스턴스 활용"
      echo "• Auto Scaling: 자동 스케일링"
      echo "• Cost Monitoring: 비용 모니터링"
      echo ""
      echo "📖 학습 자료:"
      echo "- AWS Cost Optimization 가이드"
      echo "- GCP Cost Optimization 가이드"
      echo "- Cloud Master Day3 실습 가이드"
      ;;
    "troubleshooting")
      echo "🔧 비용 최적화 문제 해결:"
      echo "1. 비용 초과 확인: 예산 설정 및 알림 확인"
      echo "2. 리소스 사용량: CloudWatch/GCP Monitoring 확인"
      echo "3. 최적화 권장사항: Cost Explorer/Billing Reports 확인"
      echo "4. 리소스 정리: 사용하지 않는 리소스 식별 및 삭제"
      echo ""
      echo "🆘 도움말:"
      echo "- AWS Cost Management 가이드"
      echo "- GCP Billing 가이드"
      echo "- Cloud Master 커뮤니티"
      ;;
    *)
      echo "🌐 비용 최적화 종합 정보:"
      echo "비용 최적화는 클라우드 리소스를 효율적으로 사용하여 비용을 절약하는 것입니다."
      echo "Cloud Master 과정에서는 비용 분석, 최적화 전략을 학습합니다."
      echo ""
      echo "🎯 학습 목표:"
      echo "- 비용 분석 및 모니터링"
      echo "- 최적화 전략 수립"
      echo "- 예산 관리 및 알림 설정"
      ;;
  esac
}

# 일반적인 답변 생성
generate_general_answer() {
  local question="$1"
  local question_type="$2"
  local skill_level="$3"
  
  echo "🤖 Cloud Master AI 어시스턴트:"
  echo "질문: $question"
  echo ""
  echo "📚 일반적인 답변:"
  echo "Cloud Master 과정은 클라우드 컴퓨팅의 핵심 개념과 실무를 학습하는 과정입니다."
  echo ""
  echo "🎯 주요 학습 내용:"
  echo "• Day 1: VM 기반 애플리케이션 배포"
  echo "• Day 2: Kubernetes 기반 컨테이너 배포"
  echo "• Day 3: 모니터링 및 비용 최적화"
  echo ""
  echo "💡 도움말:"
  echo "- 더 구체적인 질문을 해주세요"
  echo "- 맥락을 지정해주세요 (--context 옵션)"
  echo "- 기술 수준을 알려주세요 (--skill-level 옵션)"
  echo ""
  echo "🆘 추가 지원:"
  echo "- Cloud Master 공식 문서"
  echo "- 실습 가이드 참조"
  echo "- 커뮤니티 질문 게시판"
}

# 대화형 모드 실행
run_interactive_mode() {
  echo "🤖 Cloud Master AI 어시스턴트에 오신 것을 환영합니다!"
  echo "질문을 입력하거나 'quit'를 입력하여 종료하세요."
  echo ""
  
  while true; do
    echo -n "질문: "
    read -r question
    
    if [ "$question" = "quit" ] || [ "$question" = "exit" ]; then
      echo "👋 안녕히 가세요!"
      break
    fi
    
    if [ -n "$question" ]; then
      echo ""
      generate_ai_answer "$question" "$CONTEXT" "$SKILL_LEVEL"
      echo ""
      echo "---"
      echo ""
    fi
  done
}

# 메인 실행
if [ "$INTERACTIVE" == "true" ]; then
  run_interactive_mode
elif [ -n "$QUESTION" ]; then
  generate_ai_answer "$QUESTION" "$CONTEXT" "$SKILL_LEVEL"
else
  usage
fi
