#!/bin/bash

# Cloud Master 비용 모니터링 및 예산 관리 스크립트

# 사용법 함수
usage() {
  echo "Usage: $0 [aws|gcp] [--create-budget] [--check-alerts] [--set-thresholds]"
  echo "  aws: AWS Budgets 및 Cost Explorer 설정"
  echo "  gcp: GCP Budgets 및 Billing 설정"
  echo "  --create-budget: 예산 생성"
  echo "  --check-alerts: 알림 확인"
  echo "  --set-thresholds: 임계값 설정"
  exit 1
}

# 인자 확인
if [ -z "$1" ]; then
  usage
fi

CLOUD_PROVIDER=$1
CREATE_BUDGET=false
CHECK_ALERTS=false
SET_THRESHOLDS=false

# 옵션 파싱
while [[ $# -gt 1 ]]; do
  case $2 in
    --create-budget)
      CREATE_BUDGET=true
      shift
      ;;
    --check-alerts)
      CHECK_ALERTS=true
      shift
      ;;
    --set-thresholds)
      SET_THRESHOLDS=true
      shift
      ;;
    *)
      shift
      ;;
  esac
done

BUDGET_NAME="Cloud-Master-Practice-Budget"
REGION="ap-northeast-2"  # AWS 기본 리전
GCP_REGION="asia-northeast3"  # GCP 기본 리전

echo "💰 Cloud Master 비용 모니터링 및 예산 관리를 시작합니다..."
echo "   클라우드 제공자: $CLOUD_PROVIDER"
echo "   예산 생성: $CREATE_BUDGET"
echo "   알림 확인: $CHECK_ALERTS"
echo "   임계값 설정: $SET_THRESHOLDS"

if [ "$CLOUD_PROVIDER" == "aws" ]; then
  echo "⚙️ AWS Budgets 및 Cost Explorer를 설정합니다..."

  if [ "$CREATE_BUDGET" == "true" ]; then
    echo "   - 예산 생성..."
    
    # 예산 JSON 생성
    cat > budget-config.json << EOF
{
  "BudgetName": "$BUDGET_NAME",
  "BudgetLimit": {
    "Amount": "100.00",
    "Unit": "USD"
  },
  "TimeUnit": "MONTHLY",
  "BudgetType": "COST",
  "CostFilters": {
    "Service": [
      "Amazon Elastic Compute Cloud - Compute",
      "Amazon Elastic Kubernetes Service",
      "Amazon Elastic Load Balancing",
      "Amazon CloudWatch"
    ]
  },
  "CalculatedSpend": {
    "ActualSpend": {
      "Amount": "0.00",
      "Unit": "USD"
    },
    "ForecastedSpend": {
      "Amount": "0.00",
      "Unit": "USD"
    }
  },
  "TimePeriod": {
    "Start": "$(date +%Y-%m-01T00:00:00Z)",
    "End": "$(date -d "+1 year" +%Y-%m-01T00:00:00Z)"
  }
}
EOF

    # 예산 생성
    aws budgets create-budget \
      --account-id $(aws sts get-caller-identity --query Account --output text) \
      --budget file://budget-config.json

    if [ $? -eq 0 ]; then
      echo "✅ 예산 생성 완료: $BUDGET_NAME"
    else
      echo "❌ 예산 생성 실패"
    fi

    # 예산 알림 생성
    echo "   - 예산 알림 생성..."
    
    # 50% 임계값 알림
    aws budgets create-notification \
      --account-id $(aws sts get-caller-identity --query Account --output text) \
      --budget-name "$BUDGET_NAME" \
      --notification '{
        "Notification": {
          "NotificationType": "ACTUAL",
          "ComparisonOperator": "GREATER_THAN",
          "Threshold": 50,
          "ThresholdType": "PERCENTAGE"
        },
        "Subscribers": [
          {
            "SubscriptionType": "EMAIL",
            "Address": "admin@example.com"
          }
        ]
      }'

    # 80% 임계값 알림
    aws budgets create-notification \
      --account-id $(aws sts get-caller-identity --query Account --output text) \
      --budget-name "$BUDGET_NAME" \
      --notification '{
        "Notification": {
          "NotificationType": "ACTUAL",
          "ComparisonOperator": "GREATER_THAN",
          "Threshold": 80,
          "ThresholdType": "PERCENTAGE"
        },
        "Subscribers": [
          {
            "SubscriptionType": "EMAIL",
            "Address": "admin@example.com"
          }
        ]
      }'

    # 100% 임계값 알림
    aws budgets create-notification \
      --account-id $(aws sts get-caller-identity --query Account --output text) \
      --budget-name "$BUDGET_NAME" \
      --notification '{
        "Notification": {
          "NotificationType": "ACTUAL",
          "ComparisonOperator": "GREATER_THAN",
          "Threshold": 100,
          "ThresholdType": "PERCENTAGE"
        },
        "Subscribers": [
          {
            "SubscriptionType": "EMAIL",
            "Address": "admin@example.com"
          }
        ]
      }'

    echo "✅ 예산 알림 생성 완료"
  fi

  if [ "$CHECK_ALERTS" == "true" ]; then
    echo "   - 예산 알림 확인..."
    
    # 예산 상태 확인
    aws budgets describe-budget \
      --account-id $(aws sts get-caller-identity --query Account --output text) \
      --budget-name "$BUDGET_NAME" \
      --query 'Budget.CalculatedSpend' \
      --output table

    # 알림 상태 확인
    aws budgets describe-notifications-for-budget \
      --account-id $(aws sts get-caller-identity --query Account --output text) \
      --budget-name "$BUDGET_NAME" \
      --query 'Notifications[*].[NotificationType,ComparisonOperator,Threshold,ThresholdType]' \
      --output table
  fi

  if [ "$SET_THRESHOLDS" == "true" ]; then
    echo "   - 임계값 설정..."
    
    # Cost Anomaly Detection 설정
    aws ce create-anomaly-detector \
      --anomaly-detector-name "Cloud-Master-Cost-Anomaly" \
      --anomaly-detector-type "DIMENSIONAL" \
      --anomaly-detector-specification '{
        "Dimension": "SERVICE",
        "MatchOptions": ["EQUALS"],
        "Values": ["Amazon Elastic Compute Cloud - Compute", "Amazon Elastic Kubernetes Service"]
      }'

    echo "✅ 비용 이상 탐지 설정 완료"
  fi

elif [ "$CLOUD_PROVIDER" == "gcp" ]; then
  echo "⚙️ GCP Budgets 및 Billing을 설정합니다..."

  if [ "$CREATE_BUDGET" == "true" ]; then
    echo "   - 예산 생성..."
    
    # 예산 JSON 생성
    cat > gcp-budget-config.json << EOF
{
  "displayName": "$BUDGET_NAME",
  "budgetFilter": {
    "projects": ["projects/$(gcloud config get-value project)"],
    "services": ["services/6F81-5844-456A", "services/25E0-4A2D-9D30", "services/27E2-3F2F-3F2F"]
  },
  "amount": {
    "specifiedAmount": {
      "currencyCode": "USD",
      "units": "100"
    }
  },
  "thresholdRules": [
    {
      "thresholdPercent": 0.5,
      "spendBasis": "CURRENT_SPEND"
    },
    {
      "thresholdPercent": 0.8,
      "spendBasis": "CURRENT_SPEND"
    },
    {
      "thresholdPercent": 1.0,
      "spendBasis": "CURRENT_SPEND"
    }
  ],
  "notificationsRule": {
    "pubsubTopic": "projects/$(gcloud config get-value project)/topics/budget-notifications",
    "schemaVersion": "1.0"
  }
}
EOF

    # 예산 생성
    gcloud billing budgets create \
      --billing-account=$(gcloud billing accounts list --format="value(name)" | head -n 1) \
      --budget-file=gcp-budget-config.json

    if [ $? -eq 0 ]; then
      echo "✅ 예산 생성 완료: $BUDGET_NAME"
    else
      echo "❌ 예산 생성 실패"
    fi

    # Pub/Sub 토픽 생성 (알림용)
    gcloud pubsub topics create budget-notifications

    # Cloud Functions 생성 (알림 처리용)
    cat > budget-notification-function.py << EOF
import json
import base64
from google.cloud import pubsub_v1

def process_budget_notification(event, context):
    # Pub/Sub 메시지 파싱
    if 'data' in event:
        message = base64.b64decode(event['data']).decode('utf-8')
        budget_data = json.loads(message)
        
        # 예산 초과 알림 처리
        if budget_data.get('budgetAmount') and budget_data.get('costAmount'):
            budget_amount = float(budget_data['budgetAmount'])
            cost_amount = float(budget_data['costAmount'])
            
            if cost_amount > budget_amount:
                print(f"🚨 예산 초과! 예산: ${budget_amount}, 사용: ${cost_amount}")
                
                # 여기에 알림 로직 추가 (이메일, Slack 등)
                # 예: Slack 웹훅 호출, 이메일 전송 등
            else:
                print(f"✅ 예산 내 사용 중. 예산: ${budget_amount}, 사용: ${cost_amount}")
    
    return 'OK'
EOF

    # Cloud Functions 배포
    gcloud functions deploy budget-notification-processor \
      --runtime python39 \
      --trigger-topic budget-notifications \
      --source . \
      --entry-point process_budget_notification

    echo "✅ 예산 알림 시스템 설정 완료"
  fi

  if [ "$CHECK_ALERTS" == "true" ]; then
    echo "   - 예산 상태 확인..."
    
    # 예산 목록 확인
    gcloud billing budgets list \
      --billing-account=$(gcloud billing accounts list --format="value(name)" | head -n 1) \
      --format="table(displayName,amount.specifiedAmount.units,amount.specifiedAmount.currencyCode,thresholdRules[].thresholdPercent)"

    # 현재 비용 확인 (BigQuery 필요)
    echo "   - 현재 비용 확인 (BigQuery Billing Export 필요)..."
    echo "     BigQuery에 청구 내역이 익스포트되어 있어야 합니다."
  fi

  if [ "$SET_THRESHOLDS" == "true" ]; then
    echo "   - 임계값 설정..."
    
    # 커스텀 메트릭 설정 (비용 기반)
    cat > cost-metric-descriptor.json << EOF
{
  "type": "custom.googleapis.com/cloud_master/cost_anomaly",
  "displayName": "Cloud Master Cost Anomaly",
  "description": "Detects unusual cost patterns in Cloud Master practice environment",
  "metricKind": "GAUGE",
  "valueType": "DOUBLE",
  "unit": "USD"
}
EOF

    gcloud alpha monitoring metric-descriptors create \
      --config-from-file=cost-metric-descriptor.json

    echo "✅ 커스텀 비용 메트릭 설정 완료"
  fi

else
  usage
fi

# 정리
rm -f budget-config.json gcp-budget-config.json
rm -f budget-notification-function.py cost-metric-descriptor.json

echo "🎉 Cloud Master 비용 모니터링 및 예산 관리 설정 완료!"
echo "💡 다음 단계:"
echo "   1. 예산 설정 확인 및 조정"
echo "   2. 알림 채널 설정 (이메일, Slack 등)"
echo "   3. 정기적인 비용 검토 일정 설정"
echo "   4. 팀과의 비용 관리 프로세스 공유"
