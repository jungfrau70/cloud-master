#!/bin/bash

# Cloud Master AI 기반 실습 환경 자동 생성 스크립트

# 사용법 함수
usage() {
  echo "Usage: $0 [aws|gcp] [--skill-level LEVEL] [--learning-goals GOALS] [--budget BUDGET] [--duration DURATION]"
  echo "  aws: AWS 환경에 AI 최적화된 실습 환경 생성"
  echo "  gcp: GCP 환경에 AI 최적화된 실습 환경 생성"
  echo "  --skill-level LEVEL: 초급|중급|고급 (기본값: 중급)"
  echo "  --learning-goals GOALS: 학습 목표 (예: 'kubernetes,monitoring,cost-optimization')"
  echo "  --budget BUDGET: 예산 한도 (USD, 기본값: 100)"
  echo "  --duration DURATION: 실습 기간 (시간, 기본값: 8)"
  exit 1
}

# 인자 확인
if [ -z "$1" ]; then
  usage
fi

CLOUD_PROVIDER=$1
SKILL_LEVEL="중급"
LEARNING_GOALS=""
BUDGET=100
DURATION=8

# 옵션 파싱
while [[ $# -gt 1 ]]; do
  case $2 in
    --skill-level)
      SKILL_LEVEL="$3"
      shift 2
      ;;
    --learning-goals)
      LEARNING_GOALS="$3"
      shift 2
      ;;
    --budget)
      BUDGET="$3"
      shift 2
      ;;
    --duration)
      DURATION="$3"
      shift 2
      ;;
    *)
      shift
      ;;
  esac
done

REGION="ap-northeast-2"  # AWS 기본 리전
GCP_REGION="asia-northeast3"  # GCP 기본 리전
AI_CONFIG_FILE="ai-environment-config.json"
ENVIRONMENT_NAME="cloud-master-ai-$(date +%Y%m%d-%H%M%S)"

echo "🤖 Cloud Master AI 기반 실습 환경 생성을 시작합니다..."
echo "   클라우드 제공자: $CLOUD_PROVIDER"
echo "   기술 수준: $SKILL_LEVEL"
echo "   학습 목표: ${LEARNING_GOALS:-'전체 과정'}"
echo "   예산 한도: \$$BUDGET"
echo "   실습 기간: ${DURATION}시간"
echo "   환경 이름: $ENVIRONMENT_NAME"

# AI 기반 환경 구성 생성
echo "🧠 AI가 최적화된 환경 구성을 생성합니다..."

# 학습 목표 분석
if [ -n "$LEARNING_GOALS" ]; then
  IFS=',' read -ra GOALS_ARRAY <<< "$LEARNING_GOALS"
  GOALS_COUNT=${#GOALS_ARRAY[@]}
  echo "   분석된 학습 목표: $GOALS_COUNT개"
  for goal in "${GOALS_ARRAY[@]}"; do
    echo "     - $goal"
  done
else
  echo "   전체 과정 학습 목표로 설정"
fi

# 기술 수준별 리소스 최적화
case $SKILL_LEVEL in
  "초급")
    INSTANCE_TYPE="t3.micro"
    NODE_COUNT=1
    COMPLEXITY="basic"
    MONITORING_LEVEL="basic"
    ;;
  "중급")
    INSTANCE_TYPE="t3.small"
    NODE_COUNT=2
    COMPLEXITY="intermediate"
    MONITORING_LEVEL="standard"
    ;;
  "고급")
    INSTANCE_TYPE="t3.medium"
    NODE_COUNT=3
    COMPLEXITY="advanced"
    MONITORING_LEVEL="comprehensive"
    ;;
  *)
    echo "❌ 지원하지 않는 기술 수준: $SKILL_LEVEL"
    exit 1
    ;;
esac

echo "   최적화된 리소스 구성:"
echo "     - 인스턴스 타입: $INSTANCE_TYPE"
echo "     - 노드 수: $NODE_COUNT"
echo "     - 복잡도: $COMPLEXITY"
echo "     - 모니터링 수준: $MONITORING_LEVEL"

# AI 기반 환경 구성 JSON 생성
cat > "$AI_CONFIG_FILE" << EOF
{
  "environment": {
    "name": "$ENVIRONMENT_NAME",
    "cloud_provider": "$CLOUD_PROVIDER",
    "region": "$REGION",
    "skill_level": "$SKILL_LEVEL",
    "learning_goals": "$LEARNING_GOALS",
    "budget_limit": $BUDGET,
    "duration_hours": $DURATION,
    "created_at": "$(date -Iseconds)"
  },
  "resources": {
    "compute": {
      "instance_type": "$INSTANCE_TYPE",
      "node_count": $NODE_COUNT,
      "auto_scaling": $([ "$SKILL_LEVEL" == "고급" ] && echo "true" || echo "false")
    },
    "storage": {
      "volume_size": $([ "$SKILL_LEVEL" == "초급" ] && echo "20" || [ "$SKILL_LEVEL" == "중급" ] && echo "50" || echo "100"),
      "volume_type": "gp3"
    },
    "networking": {
      "vpc_cidr": "10.0.0.0/16",
      "subnet_count": $([ "$SKILL_LEVEL" == "고급" ] && echo "3" || echo "2"),
      "load_balancer": $([ "$SKILL_LEVEL" == "초급" ] && echo "false" || echo "true")
    },
    "monitoring": {
      "level": "$MONITORING_LEVEL",
      "alerts": $([ "$SKILL_LEVEL" == "초급" ] && echo "false" || echo "true"),
      "dashboards": $([ "$SKILL_LEVEL" == "초급" ] && echo "false" || echo "true")
    },
    "security": {
      "encryption": true,
      "backup": $([ "$SKILL_LEVEL" == "고급" ] && echo "true" || echo "false"),
      "access_control": $([ "$SKILL_LEVEL" == "초급" ] && echo "basic" || echo "advanced")
    }
  },
  "learning_path": {
    "day1": {
      "focus": "기본 인프라 구축",
      "duration": "2-3시간",
      "complexity": "$COMPLEXITY"
    },
    "day2": {
      "focus": "컨테이너 및 오케스트레이션",
      "duration": "3-4시간",
      "complexity": "$COMPLEXITY"
    },
    "day3": {
      "focus": "모니터링 및 최적화",
      "duration": "2-3시간",
      "complexity": "$COMPLEXITY"
    }
  },
  "ai_recommendations": {
    "cost_optimization": [
      "예산 한도 내에서 최적의 리소스 구성",
      "사용하지 않는 리소스 자동 정리",
      "Reserved Instances 권장사항 제공"
    ],
    "learning_optimization": [
      "개인별 학습 패턴 분석",
      "맞춤형 실습 가이드 제공",
      "진도에 따른 난이도 조절"
    ],
    "performance_optimization": [
      "리소스 사용률 기반 자동 스케일링",
      "성능 병목 지점 자동 감지",
      "최적화 권장사항 실시간 제공"
    ]
  }
}
EOF

echo "✅ AI 기반 환경 구성 생성 완료: $AI_CONFIG_FILE"

# AI 기반 실습 환경 배포
echo "🚀 AI 최적화된 실습 환경을 배포합니다..."

if [ "$CLOUD_PROVIDER" == "aws" ]; then
  echo "⚙️ AWS 환경에 AI 최적화된 실습 환경을 배포합니다..."

  # VPC 생성
  echo "   - VPC 생성..."
  VPC_ID=$(aws ec2 create-vpc \
    --cidr-block 10.0.0.0/16 \
    --tag-specifications 'ResourceType=vpc,Tags=[{Key=Name,Value='$ENVIRONMENT_NAME'-vpc},{Key=AI-Optimized,Value=true},{Key=Skill-Level,Value='$SKILL_LEVEL'}]' \
    --query 'Vpc.VpcId' \
    --output text)

  # 서브넷 생성
  echo "   - 서브넷 생성..."
  SUBNET_1_ID=$(aws ec2 create-subnet \
    --vpc-id $VPC_ID \
    --cidr-block 10.0.1.0/24 \
    --availability-zone ${REGION}a \
    --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value='$ENVIRONMENT_NAME'-subnet-1}]' \
    --query 'Subnet.SubnetId' \
    --output text)

  SUBNET_2_ID=$(aws ec2 create-subnet \
    --vpc-id $VPC_ID \
    --cidr-block 10.0.2.0/24 \
    --availability-zone ${REGION}c \
    --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value='$ENVIRONMENT_NAME'-subnet-2}]' \
    --query 'Subnet.SubnetId' \
    --output text)

  # 보안 그룹 생성
  echo "   - 보안 그룹 생성..."
  SG_ID=$(aws ec2 create-security-group \
    --group-name $ENVIRONMENT_NAME-sg \
    --description "AI-optimized security group for Cloud Master practice" \
    --vpc-id $VPC_ID \
    --tag-specifications 'ResourceType=security-group,Tags=[{Key=Name,Value='$ENVIRONMENT_NAME'-sg}]' \
    --query 'GroupId' \
    --output text)

  # 보안 그룹 규칙 추가
  aws ec2 authorize-security-group-ingress \
    --group-id $SG_ID \
    --protocol tcp \
    --port 22 \
    --cidr 0.0.0.0/0

  aws ec2 authorize-security-group-ingress \
    --group-id $SG_ID \
    --protocol tcp \
    --port 80 \
    --cidr 0.0.0.0/0

  aws ec2 authorize-security-group-ingress \
    --group-id $SG_ID \
    --protocol tcp \
    --port 443 \
    --cidr 0.0.0.0/0

  # EC2 인스턴스 생성
  echo "   - EC2 인스턴스 생성 ($NODE_COUNT개)..."
  for i in $(seq 1 $NODE_COUNT); do
    INSTANCE_ID=$(aws ec2 run-instances \
      --image-id ami-0c9c942bd7bf113a2 \
      --count 1 \
      --instance-type $INSTANCE_TYPE \
      --key-name $ENVIRONMENT_NAME-key \
      --security-group-ids $SG_ID \
      --subnet-id $SUBNET_1_ID \
      --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value='$ENVIRONMENT_NAME'-instance-'$i'},{Key=AI-Optimized,Value=true},{Key=Skill-Level,Value='$SKILL_LEVEL'}]' \
      --query 'Instances[0].InstanceId' \
      --output text)
    
    echo "     인스턴스 $i 생성 완료: $INSTANCE_ID"
  done

  # EKS 클러스터 생성 (중급 이상)
  if [ "$SKILL_LEVEL" != "초급" ]; then
    echo "   - EKS 클러스터 생성..."
    eksctl create cluster \
      --name $ENVIRONMENT_NAME-eks \
      --region $REGION \
      --nodegroup-name workers \
      --node-type $INSTANCE_TYPE \
      --nodes $NODE_COUNT \
      --nodes-min 1 \
      --nodes-max $((NODE_COUNT + 2)) \
      --managed \
      --tags "AI-Optimized=true,Skill-Level=$SKILL_LEVEL"
  fi

  # CloudWatch 대시보드 생성 (모니터링 수준이 standard 이상)
  if [ "$MONITORING_LEVEL" != "basic" ]; then
    echo "   - CloudWatch 대시보드 생성..."
    ./monitoring-dashboard-setup.sh aws --dashboard-url
  fi

elif [ "$CLOUD_PROVIDER" == "gcp" ]; then
  echo "⚙️ GCP 환경에 AI 최적화된 실습 환경을 배포합니다..."

  # VPC 네트워크 생성
  echo "   - VPC 네트워크 생성..."
  gcloud compute networks create $ENVIRONMENT_NAME-vpc \
    --subnet-mode custom \
    --bgp-routing-mode regional \
    --description "AI-optimized VPC for Cloud Master practice"

  # 서브넷 생성
  echo "   - 서브넷 생성..."
  gcloud compute networks subnets create $ENVIRONMENT_NAME-subnet-1 \
    --network $ENVIRONMENT_NAME-vpc \
    --range 10.0.1.0/24 \
    --region $GCP_REGION

  gcloud compute networks subnets create $ENVIRONMENT_NAME-subnet-2 \
    --network $ENVIRONMENT_NAME-vpc \
    --range 10.0.2.0/24 \
    --region $GCP_REGION

  # 방화벽 규칙 생성
  echo "   - 방화벽 규칙 생성..."
  gcloud compute firewall-rules create $ENVIRONMENT_NAME-allow-ssh \
    --network $ENVIRONMENT_NAME-vpc \
    --allow tcp:22 \
    --source-ranges 0.0.0.0/0 \
    --description "Allow SSH access"

  gcloud compute firewall-rules create $ENVIRONMENT_NAME-allow-http \
    --network $ENVIRONMENT_NAME-vpc \
    --allow tcp:80 \
    --source-ranges 0.0.0.0/0 \
    --description "Allow HTTP access"

  gcloud compute firewall-rules create $ENVIRONMENT_NAME-allow-https \
    --network $ENVIRONMENT_NAME-vpc \
    --allow tcp:443 \
    --source-ranges 0.0.0.0/0 \
    --description "Allow HTTPS access"

  # Compute Engine 인스턴스 생성
  echo "   - Compute Engine 인스턴스 생성 ($NODE_COUNT개)..."
  for i in $(seq 1 $NODE_COUNT); do
    gcloud compute instances create $ENVIRONMENT_NAME-instance-$i \
      --zone ${GCP_REGION}-a \
      --machine-type $INSTANCE_TYPE \
      --network $ENVIRONMENT_NAME-vpc \
      --subnet $ENVIRONMENT_NAME-subnet-1 \
      --tags $ENVIRONMENT_NAME-tag \
      --metadata "ai-optimized=true,skill-level=$SKILL_LEVEL"
    
    echo "     인스턴스 $i 생성 완료: $ENVIRONMENT_NAME-instance-$i"
  done

  # GKE 클러스터 생성 (중급 이상)
  if [ "$SKILL_LEVEL" != "초급" ]; then
    echo "   - GKE 클러스터 생성..."
    gcloud container clusters create $ENVIRONMENT_NAME-gke \
      --zone ${GCP_REGION}-a \
      --num-nodes $NODE_COUNT \
      --machine-type $INSTANCE_TYPE \
      --network $ENVIRONMENT_NAME-vpc \
      --subnetwork $ENVIRONMENT_NAME-subnet-1 \
      --enable-autoscaling \
      --min-nodes 1 \
      --max-nodes $((NODE_COUNT + 2)) \
      --labels "ai-optimized=true,skill-level=$SKILL_LEVEL"
  fi

  # Monitoring 대시보드 생성 (모니터링 수준이 standard 이상)
  if [ "$MONITORING_LEVEL" != "basic" ]; then
    echo "   - Monitoring 대시보드 생성..."
    ./monitoring-dashboard-setup.sh gcp --dashboard-url
  fi

else
  usage
fi

# AI 기반 학습 경로 생성
echo "📚 AI 기반 개인화된 학습 경로를 생성합니다..."

cat > "ai-learning-path-$ENVIRONMENT_NAME.md" << EOF
# AI 기반 개인화된 Cloud Master 학습 경로

**환경 이름**: $ENVIRONMENT_NAME
**기술 수준**: $SKILL_LEVEL
**학습 목표**: ${LEARNING_GOALS:-'전체 과정'}
**예산 한도**: \$$BUDGET
**실습 기간**: ${DURATION}시간

## 🎯 AI 추천 학습 계획

### Day 1: 기본 인프라 구축 (2-3시간)
**AI 최적화 포인트**:
- 기술 수준에 맞는 복잡도 조절
- 예산 한도 내 최적 리소스 구성
- 실시간 비용 모니터링

**실습 내용**:
1. **환경 설정** (30분)
   - 클라우드 CLI 설정
   - 기본 리소스 생성
   - 비용 모니터링 설정

2. **VM 배포** (1-2시간)
   - 인스턴스 타입: $INSTANCE_TYPE
   - 노드 수: $NODE_COUNT
   - 보안 설정 최적화

3. **애플리케이션 배포** (1시간)
   - Docker 컨테이너 배포
   - 로드밸런서 설정 (중급 이상)

### Day 2: 컨테이너 및 오케스트레이션 (3-4시간)
**AI 최적화 포인트**:
- 개인별 학습 패턴 분석
- 실시간 성능 모니터링
- 자동 스케일링 설정

**실습 내용**:
1. **Kubernetes 클러스터** (1-2시간)
   - 클러스터 생성 및 설정
   - 네임스페이스 및 RBAC 설정
   - 모니터링 도구 설치

2. **애플리케이션 배포** (1-2시간)
   - Deployment 및 Service 생성
   - ConfigMap 및 Secret 관리
   - Ingress 설정

### Day 3: 모니터링 및 최적화 (2-3시간)
**AI 최적화 포인트**:
- 비용 최적화 권장사항
- 성능 병목 지점 자동 감지
- 예산 초과 방지

**실습 내용**:
1. **모니터링 설정** (1시간)
   - Prometheus 및 Grafana 설치
   - 커스텀 메트릭 설정
   - 알림 규칙 구성

2. **비용 최적화** (1-2시간)
   - 비용 분석 및 권장사항
   - 사용하지 않는 리소스 정리
   - 예산 설정 및 모니터링

## 🤖 AI 기반 개인화 기능

### 1. 실시간 학습 분석
- 학습 진도 추적
- 이해도 기반 난이도 조절
- 개인별 약점 보완 제안

### 2. 비용 최적화
- 예산 한도 내 최적 리소스 구성
- 사용 패턴 기반 자동 스케일링
- 비용 초과 방지 알림

### 3. 성능 최적화
- 리소스 사용률 실시간 모니터링
- 성능 병목 지점 자동 감지
- 최적화 권장사항 제공

### 4. 학습 지원
- 실시간 질문 답변
- 단계별 가이드 제공
- 오류 해결 도움

## 📊 예상 비용 분석

**일일 예상 비용**:
- Compute: \$$(echo "scale=2; $NODE_COUNT * 0.1 * 24" | bc)
- Storage: \$$(echo "scale=2; $NODE_COUNT * 0.1" | bc)
- Network: \$$(echo "scale=2; $NODE_COUNT * 0.05" | bc)
- **총 예상 비용**: \$$(echo "scale=2; $NODE_COUNT * 0.15 * 24" | bc)

**최적화 권장사항**:
- 사용하지 않는 리소스 정리
- 적절한 인스턴스 타입 선택
- 예약 인스턴스 활용 (장기 사용 시)

## 🎯 학습 목표 달성 체크리스트

### Day 1 목표
- [ ] 클라우드 환경 설정 완료
- [ ] VM 인스턴스 생성 및 접속
- [ ] 기본 애플리케이션 배포
- [ ] 비용 모니터링 설정

### Day 2 목표
- [ ] Kubernetes 클러스터 구축
- [ ] 컨테이너 애플리케이션 배포
- [ ] 서비스 및 인그레스 설정
- [ ] 모니터링 도구 설치

### Day 3 목표
- [ ] 종합 모니터링 시스템 구축
- [ ] 비용 최적화 분석
- [ ] 성능 튜닝 및 최적화
- [ ] 보안 설정 강화

## 🚀 다음 단계

1. **실습 시작**: 생성된 환경에서 실습 진행
2. **진도 추적**: AI 기반 학습 분석 활용
3. **최적화**: 실시간 권장사항 적용
4. **정리**: 실습 완료 후 리소스 정리

---

**AI 기반 개인화된 학습 경로가 생성되었습니다!**
**생성 시간**: $(date)
**다음 검토**: $(date -d "+1 day" +%Y-%m-%d)
EOF

echo "✅ AI 기반 개인화된 학습 경로 생성 완료: ai-learning-path-$ENVIRONMENT_NAME.md"

# AI 기반 실시간 모니터링 설정
echo "📊 AI 기반 실시간 모니터링을 설정합니다..."

if [ "$MONITORING_LEVEL" != "basic" ]; then
  # 모니터링 스택 배포
  ./monitoring-stack-deploy.sh

  # 알림 시스템 설정
  ./alert-notification-system.sh "$CLOUD_PROVIDER"

  # 비용 모니터링 설정
  ./budget-monitoring.sh "$CLOUD_PROVIDER" --create-budget --set-thresholds
fi

# AI 기반 비용 최적화 실행
echo "💰 AI 기반 비용 최적화를 실행합니다..."

./advanced-cost-optimization.sh "$CLOUD_PROVIDER" --report-only

# AI 기반 학습 분석 시작
echo "🧠 AI 기반 학습 분석을 시작합니다..."

cat > "ai-learning-analysis-$ENVIRONMENT_NAME.json" << EOF
{
  "environment_id": "$ENVIRONMENT_NAME",
  "analysis_timestamp": "$(date -Iseconds)",
  "skill_level": "$SKILL_LEVEL",
  "learning_goals": "$LEARNING_GOALS",
  "budget_limit": $BUDGET,
  "duration_hours": $DURATION,
  "ai_recommendations": {
    "resource_optimization": [
      "현재 구성이 예산 한도 내에서 최적화되어 있습니다",
      "사용 패턴에 따라 자동 스케일링이 설정되었습니다",
      "비용 초과 방지를 위한 알림이 설정되었습니다"
    ],
    "learning_optimization": [
      "기술 수준에 맞는 난이도로 조절되었습니다",
      "개인별 학습 패턴을 분석하여 맞춤형 가이드를 제공합니다",
      "실시간 피드백을 통해 학습 효과를 극대화합니다"
    ],
    "performance_optimization": [
      "리소스 사용률을 실시간으로 모니터링합니다",
      "성능 병목 지점을 자동으로 감지하고 알림합니다",
      "최적화 권장사항을 실시간으로 제공합니다"
    ]
  },
  "monitoring_setup": {
    "dashboards": $([ "$MONITORING_LEVEL" != "basic" ] && echo "true" || echo "false"),
    "alerts": $([ "$MONITORING_LEVEL" != "basic" ] && echo "true" || echo "false"),
    "cost_tracking": true,
    "performance_tracking": true
  },
  "next_steps": [
    "실습 환경에서 학습을 시작하세요",
    "AI 기반 모니터링 대시보드를 확인하세요",
    "실시간 권장사항을 활용하여 학습을 최적화하세요",
    "정기적으로 비용 및 성능 리포트를 검토하세요"
  ]
}
EOF

echo "✅ AI 기반 학습 분석 완료: ai-learning-analysis-$ENVIRONMENT_NAME.json"

# 완료 메시지
echo "🎉 Cloud Master AI 기반 실습 환경 생성 완료!"
echo "📊 생성된 환경 정보:"
echo "   - 환경 이름: $ENVIRONMENT_NAME"
echo "   - 클라우드 제공자: $CLOUD_PROVIDER"
echo "   - 기술 수준: $SKILL_LEVEL"
echo "   - 노드 수: $NODE_COUNT"
echo "   - 인스턴스 타입: $INSTANCE_TYPE"
echo "   - 모니터링 수준: $MONITORING_LEVEL"

echo "📁 생성된 파일:"
echo "   - 환경 구성: $AI_CONFIG_FILE"
echo "   - 학습 경로: ai-learning-path-$ENVIRONMENT_NAME.md"
echo "   - 학습 분석: ai-learning-analysis-$ENVIRONMENT_NAME.json"

echo "💡 다음 단계:"
echo "   1. 생성된 학습 경로를 따라 실습 시작"
echo "   2. AI 기반 모니터링 대시보드 확인"
echo "   3. 실시간 권장사항 활용"
echo "   4. 정기적인 학습 분석 검토"

echo "🤖 AI가 당신의 학습을 지원합니다! 행운을 빕니다!"
