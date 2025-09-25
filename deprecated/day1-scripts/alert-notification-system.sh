#!/bin/bash

# Cloud Master 실시간 알림 시스템 설정 스크립트

# 사용법 함수
usage() {
  echo "Usage: $0 [aws|gcp] [--slack-webhook URL] [--email EMAIL]"
  echo "  aws: AWS SNS를 사용한 알림 시스템 설정"
  echo "  gcp: GCP Pub/Sub를 사용한 알림 시스템 설정"
  echo "  --slack-webhook URL: Slack 웹훅 URL 설정"
  echo "  --email EMAIL: 이메일 주소 설정"
  exit 1
}

# 인자 확인
if [ -z "$1" ]; then
  usage
fi

CLOUD_PROVIDER=$1
SLACK_WEBHOOK=""
EMAIL=""

# 옵션 파싱
while [[ $# -gt 1 ]]; do
  case $2 in
    --slack-webhook)
      SLACK_WEBHOOK="$3"
      shift 2
      ;;
    --email)
      EMAIL="$3"
      shift 2
      ;;
    *)
      shift
      ;;
  esac
done

TOPIC_NAME="cloud-master-alerts"
REGION="ap-northeast-2"  # AWS 기본 리전
GCP_REGION="asia-northeast3"  # GCP 기본 리전

echo "🔔 Cloud Master 실시간 알림 시스템을 설정합니다..."
echo "   클라우드 제공자: $CLOUD_PROVIDER"
echo "   토픽 이름: $TOPIC_NAME"
echo "   Slack 웹훅: ${SLACK_WEBHOOK:-'설정되지 않음'}"
echo "   이메일: ${EMAIL:-'설정되지 않음'}"

if [ "$CLOUD_PROVIDER" == "aws" ]; then
  echo "⚙️ AWS SNS 알림 시스템을 설정합니다..."

  # SNS 토픽 생성
  echo "   - SNS 토픽 생성..."
  TOPIC_ARN=$(aws sns create-topic \
    --name "$TOPIC_NAME" \
    --region "$REGION" \
    --query 'TopicArn' \
    --output text)

  if [ $? -eq 0 ]; then
    echo "✅ SNS 토픽 생성 완료: $TOPIC_ARN"
  else
    echo "❌ SNS 토픽 생성 실패"
    exit 1
  fi

  # 이메일 구독 (이메일이 제공된 경우)
  if [ -n "$EMAIL" ]; then
    echo "   - 이메일 구독 설정..."
    SUBSCRIPTION_ARN=$(aws sns subscribe \
      --topic-arn "$TOPIC_ARN" \
      --protocol email \
      --endpoint "$EMAIL" \
      --query 'SubscriptionArn' \
      --output text)

    if [ $? -eq 0 ]; then
      echo "✅ 이메일 구독 설정 완료: $SUBSCRIPTION_ARN"
      echo "   확인 이메일을 확인하여 구독을 활성화하세요."
    else
      echo "❌ 이메일 구독 설정 실패"
    fi
  fi

  # Slack 웹훅 구독 (웹훅이 제공된 경우)
  if [ -n "$SLACK_WEBHOOK" ]; then
    echo "   - Slack 웹훅 구독 설정..."
    
    # Lambda 함수 생성 (Slack 웹훅 호출용)
    cat > slack-notification-lambda.py << EOF
import json
import urllib3
import os

def lambda_handler(event, context):
    webhook_url = os.environ['SLACK_WEBHOOK_URL']
    
    # SNS 메시지 파싱
    message = json.loads(event['Records'][0]['Sns']['Message'])
    
    # Slack 메시지 포맷
    slack_message = {
        "text": f"🚨 Cloud Master 알림",
        "attachments": [
            {
                "color": "danger",
                "fields": [
                    {
                        "title": "알림 유형",
                        "value": message.get('AlarmName', 'Unknown'),
                        "short": True
                    },
                    {
                        "title": "상태",
                        "value": message.get('NewStateValue', 'Unknown'),
                        "short": True
                    },
                    {
                        "title": "리전",
                        "value": message.get('Region', 'Unknown'),
                        "short": True
                    },
                    {
                        "title": "설명",
                        "value": message.get('AlarmDescription', 'No description'),
                        "short": False
                    }
                ]
            }
        ]
    }
    
    # Slack으로 전송
    http = urllib3.PoolManager()
    response = http.request('POST', webhook_url, 
                          body=json.dumps(slack_message),
                          headers={'Content-Type': 'application/json'})
    
    return {
        'statusCode': 200,
        'body': json.dumps('Slack notification sent')
    }
EOF

    # Lambda 함수 배포
    zip slack-notification-lambda.zip slack-notification-lambda.py
    
    aws lambda create-function \
      --function-name cloud-master-slack-notification \
      --runtime python3.9 \
      --role arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):role/lambda-execution-role \
      --handler slack-notification-lambda.lambda_handler \
      --zip-file fileb://slack-notification-lambda.zip \
      --environment Variables="{SLACK_WEBHOOK_URL=$SLACK_WEBHOOK}"

    # SNS에서 Lambda로 메시지 전송 설정
    aws lambda add-permission \
      --function-name cloud-master-slack-notification \
      --statement-id sns-trigger \
      --action lambda:InvokeFunction \
      --principal sns.amazonaws.com \
      --source-arn "$TOPIC_ARN"

    aws sns subscribe \
      --topic-arn "$TOPIC_ARN" \
      --protocol lambda \
      --endpoint arn:aws:lambda:$REGION:$(aws sts get-caller-identity --query Account --output text):function:cloud-master-slack-notification

    echo "✅ Slack 웹훅 구독 설정 완료"
  fi

  # CloudWatch 알람에 SNS 토픽 연결
  echo "   - CloudWatch 알람에 SNS 토픽 연결..."
  
  # 기존 알람에 SNS 액션 추가
  aws cloudwatch put-metric-alarm \
    --alarm-name "Cloud-Master-EC2-High-CPU" \
    --alarm-description "EC2 인스턴스 CPU 사용률이 80%를 초과" \
    --metric-name CPUUtilization \
    --namespace AWS/EC2 \
    --statistic Average \
    --period 300 \
    --threshold 80 \
    --comparison-operator GreaterThanThreshold \
    --evaluation-periods 2 \
    --alarm-actions "$TOPIC_ARN"

  aws cloudwatch put-metric-alarm \
    --alarm-name "Cloud-Master-EC2-High-Memory" \
    --alarm-description "EC2 인스턴스 메모리 사용률이 80%를 초과" \
    --metric-name MemoryUtilization \
    --namespace System/Linux \
    --statistic Average \
    --period 300 \
    --threshold 80 \
    --comparison-operator GreaterThanThreshold \
    --evaluation-periods 2 \
    --alarm-actions "$TOPIC_ARN"

  echo "✅ CloudWatch 알람에 SNS 토픽 연결 완료"

elif [ "$CLOUD_PROVIDER" == "gcp" ]; then
  echo "⚙️ GCP Pub/Sub 알림 시스템을 설정합니다..."

  # Pub/Sub 토픽 생성
  echo "   - Pub/Sub 토픽 생성..."
  gcloud pubsub topics create "$TOPIC_NAME"

  if [ $? -eq 0 ]; then
    echo "✅ Pub/Sub 토픽 생성 완료: projects/$(gcloud config get-value project)/topics/$TOPIC_NAME"
  else
    echo "❌ Pub/Sub 토픽 생성 실패"
    exit 1
  fi

  # 이메일 구독 (이메일이 제공된 경우)
  if [ -n "$EMAIL" ]; then
    echo "   - 이메일 구독 설정..."
    
    # Cloud Functions 생성 (이메일 전송용)
    cat > email-notification-function.py << EOF
import json
import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
import os

def send_email_notification(event, context):
    # Pub/Sub 메시지 파싱
    message = json.loads(event['data'].decode('utf-8'))
    
    # 이메일 설정
    smtp_server = "smtp.gmail.com"
    smtp_port = 587
    sender_email = os.environ.get('SENDER_EMAIL', 'noreply@example.com')
    sender_password = os.environ.get('SENDER_PASSWORD', '')
    recipient_email = os.environ.get('RECIPIENT_EMAIL', '$EMAIL')
    
    # 이메일 내용
    subject = f"🚨 Cloud Master 알림: {message.get('alert_name', 'Unknown')}"
    body = f"""
    Cloud Master 실습 환경에서 알림이 발생했습니다.
    
    알림 유형: {message.get('alert_name', 'Unknown')}
    상태: {message.get('state', 'Unknown')}
    리전: {message.get('region', 'Unknown')}
    설명: {message.get('description', 'No description')}
    시간: {message.get('timestamp', 'Unknown')}
    """
    
    # 이메일 전송
    msg = MIMEMultipart()
    msg['From'] = sender_email
    msg['To'] = recipient_email
    msg['Subject'] = subject
    msg.attach(MIMEText(body, 'plain'))
    
    try:
        server = smtplib.SMTP(smtp_server, smtp_port)
        server.starttls()
        server.login(sender_email, sender_password)
        server.send_message(msg)
        server.quit()
        print("이메일 알림 전송 완료")
    except Exception as e:
        print(f"이메일 전송 실패: {e}")
EOF

    # Cloud Functions 배포
    gcloud functions deploy cloud-master-email-notification \
      --runtime python39 \
      --trigger-topic "$TOPIC_NAME" \
      --source . \
      --entry-point send_email_notification \
      --set-env-vars RECIPIENT_EMAIL="$EMAIL"

    echo "✅ 이메일 구독 설정 완료"
  fi

  # Slack 웹훅 구독 (웹훅이 제공된 경우)
  if [ -n "$SLACK_WEBHOOK" ]; then
    echo "   - Slack 웹훅 구독 설정..."
    
    # Cloud Functions 생성 (Slack 웹훅 호출용)
    cat > slack-notification-function.py << EOF
import json
import urllib3
import os

def send_slack_notification(event, context):
    webhook_url = os.environ['SLACK_WEBHOOK_URL']
    
    # Pub/Sub 메시지 파싱
    message = json.loads(event['data'].decode('utf-8'))
    
    # Slack 메시지 포맷
    slack_message = {
        "text": f"🚨 Cloud Master 알림",
        "attachments": [
            {
                "color": "danger",
                "fields": [
                    {
                        "title": "알림 유형",
                        "value": message.get('alert_name', 'Unknown'),
                        "short": True
                    },
                    {
                        "title": "상태",
                        "value": message.get('state', 'Unknown'),
                        "short": True
                    },
                    {
                        "title": "리전",
                        "value": message.get('region', 'Unknown'),
                        "short": True
                    },
                    {
                        "title": "설명",
                        "value": message.get('description', 'No description'),
                        "short": False
                    }
                ]
            }
        ]
    }
    
    # Slack으로 전송
    http = urllib3.PoolManager()
    response = http.request('POST', webhook_url, 
                          body=json.dumps(slack_message),
                          headers={'Content-Type': 'application/json'})
    
    print("Slack 알림 전송 완료")
EOF

    # Cloud Functions 배포
    gcloud functions deploy cloud-master-slack-notification \
      --runtime python39 \
      --trigger-topic "$TOPIC_NAME" \
      --source . \
      --entry-point send_slack_notification \
      --set-env-vars SLACK_WEBHOOK_URL="$SLACK_WEBHOOK"

    echo "✅ Slack 웹훅 구독 설정 완료"
  fi

  # Monitoring 알림 정책에 Pub/Sub 토픽 연결
  echo "   - Monitoring 알림 정책에 Pub/Sub 토픽 연결..."
  
  # 알림 채널 생성
  cat > notification-channel.json << EOF
{
  "displayName": "Cloud Master Pub/Sub Channel",
  "type": "pubsub",
  "labels": {
    "topic": "projects/$(gcloud config get-value project)/topics/$TOPIC_NAME"
  }
}
EOF

  gcloud alpha monitoring channels create --channel-content-from-file=notification-channel.json

  echo "✅ Monitoring 알림 정책에 Pub/Sub 토픽 연결 완료"

else
  usage
fi

# 정리
rm -f slack-notification-lambda.py slack-notification-lambda.zip
rm -f email-notification-function.py slack-notification-function.py
rm -f notification-channel.json

echo "🎉 Cloud Master 실시간 알림 시스템 설정 완료!"
echo "💡 다음 단계:"
echo "   1. 알림 테스트 실행"
echo "   2. 알림 설정 확인"
echo "   3. 커스텀 알림 규칙 추가 (필요시)"
echo "   4. 알림 채널 추가 (필요시)"
