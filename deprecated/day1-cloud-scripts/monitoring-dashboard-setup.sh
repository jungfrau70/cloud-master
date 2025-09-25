#!/bin/bash

# Cloud Master 모니터링 대시보드 자동 설정 스크립트

# 사용법 함수
usage() {
  echo "Usage: $0 [aws|gcp] [--dashboard-url]"
  echo "  aws: AWS CloudWatch 대시보드 설정"
  echo "  gcp: GCP Monitoring 대시보드 설정"
  echo "  --dashboard-url: 대시보드 URL 출력"
  exit 1
}

# 인자 확인
if [ -z "$1" ]; then
  usage
fi

CLOUD_PROVIDER=$1
SHOW_URL=false

# --dashboard-url 옵션 확인
if [ "$2" == "--dashboard-url" ]; then
  SHOW_URL=true
fi

DASHBOARD_NAME="Cloud-Master-Practice-Dashboard"
REGION="ap-northeast-2"  # AWS 기본 리전
GCP_REGION="asia-northeast3"  # GCP 기본 리전

echo "📊 Cloud Master 모니터링 대시보드 설정을 시작합니다..."
echo "   클라우드 제공자: $CLOUD_PROVIDER"
echo "   대시보드 이름: $DASHBOARD_NAME"

if [ "$CLOUD_PROVIDER" == "aws" ]; then
  echo "⚙️ AWS CloudWatch 대시보드를 설정합니다..."

  # CloudWatch 대시보드 JSON 생성
  cat > cloudwatch-dashboard.json << EOF
{
  "widgets": [
    {
      "type": "metric",
      "x": 0,
      "y": 0,
      "width": 12,
      "height": 6,
      "properties": {
        "metrics": [
          [ "AWS/EC2", "CPUUtilization", "InstanceId", "i-1234567890abcdef0" ],
          [ ".", "NetworkIn", ".", "." ],
          [ ".", "NetworkOut", ".", "." ]
        ],
        "view": "timeSeries",
        "stacked": false,
        "region": "$REGION",
        "title": "EC2 인스턴스 메트릭",
        "period": 300,
        "stat": "Average"
      }
    },
    {
      "type": "metric",
      "x": 12,
      "y": 0,
      "width": 12,
      "height": 6,
      "properties": {
        "metrics": [
          [ "AWS/ApplicationELB", "RequestCount", "LoadBalancer", "app/my-alb/1234567890123456" ],
          [ ".", "TargetResponseTime", ".", "." ],
          [ ".", "HTTPCode_Target_2XX_Count", ".", "." ],
          [ ".", "HTTPCode_Target_4XX_Count", ".", "." ],
          [ ".", "HTTPCode_Target_5XX_Count", ".", "." ]
        ],
        "view": "timeSeries",
        "stacked": false,
        "region": "$REGION",
        "title": "Application Load Balancer 메트릭",
        "period": 300,
        "stat": "Sum"
      }
    },
    {
      "type": "metric",
      "x": 0,
      "y": 6,
      "width": 12,
      "height": 6,
      "properties": {
        "metrics": [
          [ "AWS/EKS", "cluster_cpu_utilization", "ClusterName", "cloud-master-practice-eks" ],
          [ ".", "cluster_memory_utilization", ".", "." ],
          [ ".", "pod_cpu_utilization", ".", "." ],
          [ ".", "pod_memory_utilization", ".", "." ]
        ],
        "view": "timeSeries",
        "stacked": false,
        "region": "$REGION",
        "title": "EKS 클러스터 메트릭",
        "period": 300,
        "stat": "Average"
      }
    },
    {
      "type": "metric",
      "x": 12,
      "y": 6,
      "width": 12,
      "height": 6,
      "properties": {
        "metrics": [
          [ "AWS/Billing", "EstimatedCharges", "Currency", "USD" ],
          [ ".", "EstimatedCharges", "ServiceName", "AmazonEC2" ],
          [ ".", "EstimatedCharges", "ServiceName", "AmazonEKS" ],
          [ ".", "EstimatedCharges", "ServiceName", "AmazonELB" ]
        ],
        "view": "timeSeries",
        "stacked": false,
        "region": "us-east-1",
        "title": "비용 모니터링",
        "period": 86400,
        "stat": "Maximum"
      }
    },
    {
      "type": "log",
      "x": 0,
      "y": 12,
      "width": 24,
      "height": 6,
      "properties": {
        "query": "SOURCE '/aws/eks/cloud-master-practice-eks/cluster' | fields @timestamp, @message\n| filter @message like /ERROR/\n| sort @timestamp desc\n| limit 100",
        "region": "$REGION",
        "title": "EKS 클러스터 로그 (ERROR)",
        "view": "table"
      }
    }
  ]
}
EOF

  # CloudWatch 대시보드 생성
  echo "   - CloudWatch 대시보드 생성..."
  aws cloudwatch put-dashboard \
    --dashboard-name "$DASHBOARD_NAME" \
    --dashboard-body file://cloudwatch-dashboard.json

  if [ $? -eq 0 ]; then
    echo "✅ CloudWatch 대시보드 생성 완료"
    
    if [ "$SHOW_URL" == "true" ]; then
      echo "🔗 대시보드 URL: https://console.aws.amazon.com/cloudwatch/home?region=$REGION#dashboards:name=$DASHBOARD_NAME"
    fi
  else
    echo "❌ CloudWatch 대시보드 생성 실패"
    exit 1
  fi

  # CloudWatch 알람 생성
  echo "   - CloudWatch 알람 생성..."
  
  # CPU 사용률 알람
  aws cloudwatch put-metric-alarm \
    --alarm-name "Cloud-Master-EC2-High-CPU" \
    --alarm-description "EC2 인스턴스 CPU 사용률이 80%를 초과" \
    --metric-name CPUUtilization \
    --namespace AWS/EC2 \
    --statistic Average \
    --period 300 \
    --threshold 80 \
    --comparison-operator GreaterThanThreshold \
    --evaluation-periods 2

  # 메모리 사용률 알람 (Custom 메트릭 필요)
  aws cloudwatch put-metric-alarm \
    --alarm-name "Cloud-Master-EC2-High-Memory" \
    --alarm-description "EC2 인스턴스 메모리 사용률이 80%를 초과" \
    --metric-name MemoryUtilization \
    --namespace System/Linux \
    --statistic Average \
    --period 300 \
    --threshold 80 \
    --comparison-operator GreaterThanThreshold \
    --evaluation-periods 2

  echo "✅ CloudWatch 알람 생성 완료"

elif [ "$CLOUD_PROVIDER" == "gcp" ]; then
  echo "⚙️ GCP Monitoring 대시보드를 설정합니다..."

  # GCP Monitoring 대시보드 JSON 생성
  cat > gcp-monitoring-dashboard.json << EOF
{
  "displayName": "$DASHBOARD_NAME",
  "mosaicLayout": {
    "tiles": [
      {
        "width": 6,
        "height": 4,
        "widget": {
          "title": "Compute Engine CPU 사용률",
          "xyChart": {
            "dataSets": [
              {
                "timeSeriesQuery": {
                  "timeSeriesFilter": {
                    "filter": "resource.type=\"gce_instance\" AND metric.type=\"compute.googleapis.com/instance/cpu/utilization\"",
                    "aggregation": {
                      "alignmentPeriod": "300s",
                      "perSeriesAligner": "ALIGN_MEAN",
                      "crossSeriesReducer": "REDUCE_MEAN"
                    }
                  }
                }
              }
            ],
            "timeshiftDuration": "0s",
            "yAxis": {
              "label": "CPU 사용률 (%)",
              "scale": "LINEAR"
            }
          }
        }
      },
      {
        "width": 6,
        "height": 4,
        "xPos": 6,
        "widget": {
          "title": "GKE 클러스터 메트릭",
          "xyChart": {
            "dataSets": [
              {
                "timeSeriesQuery": {
                  "timeSeriesFilter": {
                    "filter": "resource.type=\"k8s_cluster\" AND metric.type=\"kubernetes.io/container/cpu/core_usage\"",
                    "aggregation": {
                      "alignmentPeriod": "300s",
                      "perSeriesAligner": "ALIGN_MEAN",
                      "crossSeriesReducer": "REDUCE_MEAN"
                    }
                  }
                }
              }
            ],
            "timeshiftDuration": "0s",
            "yAxis": {
              "label": "CPU 코어 사용량",
              "scale": "LINEAR"
            }
          }
        }
      },
      {
        "width": 6,
        "height": 4,
        "yPos": 4,
        "widget": {
          "title": "HTTP(S) 로드밸런서 요청 수",
          "xyChart": {
            "dataSets": [
              {
                "timeSeriesQuery": {
                  "timeSeriesFilter": {
                    "filter": "resource.type=\"https_lb_rule\" AND metric.type=\"loadbalancing.googleapis.com/https/request_count\"",
                    "aggregation": {
                      "alignmentPeriod": "300s",
                      "perSeriesAligner": "ALIGN_RATE",
                      "crossSeriesReducer": "REDUCE_SUM"
                    }
                  }
                }
              }
            ],
            "timeshiftDuration": "0s",
            "yAxis": {
              "label": "요청 수/초",
              "scale": "LINEAR"
            }
          }
        }
      },
      {
        "width": 6,
        "height": 4,
        "xPos": 6,
        "yPos": 4,
        "widget": {
          "title": "비용 모니터링",
          "xyChart": {
            "dataSets": [
              {
                "timeSeriesQuery": {
                  "timeSeriesFilter": {
                    "filter": "resource.type=\"billing_account\" AND metric.type=\"billing.googleapis.com/billing/account/total_cost\"",
                    "aggregation": {
                      "alignmentPeriod": "86400s",
                      "perSeriesAligner": "ALIGN_MEAN",
                      "crossSeriesReducer": "REDUCE_SUM"
                    }
                  }
                }
              }
            ],
            "timeshiftDuration": "0s",
            "yAxis": {
              "label": "비용 (USD)",
              "scale": "LINEAR"
            }
          }
        }
      }
    ]
  }
}
EOF

  # GCP Monitoring 대시보드 생성
  echo "   - GCP Monitoring 대시보드 생성..."
  gcloud monitoring dashboards create --config-from-file=gcp-monitoring-dashboard.json

  if [ $? -eq 0 ]; then
    echo "✅ GCP Monitoring 대시보드 생성 완료"
    
    if [ "$SHOW_URL" == "true" ]; then
      echo "🔗 대시보드 URL: https://console.cloud.google.com/monitoring/dashboards?project=$(gcloud config get-value project)"
    fi
  else
    echo "❌ GCP Monitoring 대시보드 생성 실패"
    exit 1
  fi

  # GCP 알림 정책 생성
  echo "   - GCP 알림 정책 생성..."
  
  # CPU 사용률 알림 정책
  cat > cpu-alert-policy.json << EOF
{
  "displayName": "Cloud Master - High CPU Usage",
  "conditions": [
    {
      "displayName": "CPU usage is high",
      "conditionThreshold": {
        "filter": "resource.type=\"gce_instance\" AND metric.type=\"compute.googleapis.com/instance/cpu/utilization\"",
        "comparison": "COMPARISON_GREATER_THAN",
        "thresholdValue": 0.8,
        "duration": "300s",
        "aggregations": [
          {
            "alignmentPeriod": "300s",
            "perSeriesAligner": "ALIGN_MEAN",
            "crossSeriesReducer": "REDUCE_MEAN"
          }
        ]
      }
    }
  ],
  "combiner": "OR",
  "enabled": true,
  "notificationChannels": []
}
EOF

  gcloud alpha monitoring policies create --policy-from-file=cpu-alert-policy.json

  echo "✅ GCP 알림 정책 생성 완료"

else
  usage
fi

# 정리
rm -f cloudwatch-dashboard.json gcp-monitoring-dashboard.json cpu-alert-policy.json

echo "🎉 Cloud Master 모니터링 대시보드 설정 완료!"
echo "💡 다음 단계:"
echo "   1. 대시보드에서 실시간 메트릭 확인"
echo "   2. 알림 설정 확인 및 테스트"
echo "   3. 커스텀 메트릭 추가 (필요시)"
echo "   4. 로그 기반 알림 설정 (필요시)"
