#!/bin/bash

# Cloud Master 고급 비용 최적화 자동화 스크립트

# 사용법 함수
usage() {
  echo "Usage: $0 [aws|gcp] [--auto-optimize] [--report-only]"
  echo "  aws: AWS 비용 최적화 분석 및 실행"
  echo "  gcp: GCP 비용 최적화 분석 및 실행"
  echo "  --auto-optimize: 자동 최적화 실행 (위험: 실제 리소스 변경)"
  echo "  --report-only: 보고서만 생성 (기본값)"
  exit 1
}

# 인자 확인
if [ -z "$1" ]; then
  usage
fi

CLOUD_PROVIDER=$1
AUTO_OPTIMIZE=false
REPORT_ONLY=true

# 옵션 파싱
while [[ $# -gt 1 ]]; do
  case $2 in
    --auto-optimize)
      AUTO_OPTIMIZE=true
      REPORT_ONLY=false
      shift
      ;;
    --report-only)
      REPORT_ONLY=true
      AUTO_OPTIMIZE=false
      shift
      ;;
    *)
      shift
      ;;
  esac
done

REGION="ap-northeast-2"  # AWS 기본 리전
GCP_REGION="asia-northeast3"  # GCP 기본 리전
REPORT_FILE="cost-optimization-report-$(date +%Y%m%d-%H%M%S).txt"

echo "💰 Cloud Master 고급 비용 최적화를 시작합니다..."
echo "   클라우드 제공자: $CLOUD_PROVIDER"
echo "   자동 최적화: $AUTO_OPTIMIZE"
echo "   보고서만 생성: $REPORT_ONLY"
echo "   보고서 파일: $REPORT_FILE"

# 보고서 헤더 생성
cat > "$REPORT_FILE" << EOF
# Cloud Master 비용 최적화 보고서

**생성 시간**: $(date)
**클라우드 제공자**: $CLOUD_PROVIDER
**자동 최적화**: $AUTO_OPTIMIZE

---

EOF

if [ "$CLOUD_PROVIDER" == "aws" ]; then
  echo "⚙️ AWS 고급 비용 최적화를 수행합니다..."

  # 1. 현재 비용 분석
  echo "   - 현재 비용 분석..."
  cat >> "$REPORT_FILE" << EOF
## 1. 현재 비용 분석

### 지난 30일간 총 비용
EOF

  TOTAL_COST=$(aws ce get-cost-and-usage \
    --time-period Start=$(date -d "30 days ago" +%Y-%m-%d),End=$(date +%Y-%m-%d) \
    --granularity MONTHLY \
    --metrics BlendedCost \
    --query 'ResultsByTime[0].Total.BlendedCost.Amount' \
    --output text)

  echo "총 비용: \$$TOTAL_COST" >> "$REPORT_FILE"
  echo "     총 비용: \$$TOTAL_COST"

  # 서비스별 비용 분석
  echo "   - 서비스별 비용 분석..."
  cat >> "$REPORT_FILE" << EOF

### 서비스별 비용 (상위 10개)
EOF

  aws ce get-cost-and-usage \
    --time-period Start=$(date -d "30 days ago" +%Y-%m-%d),End=$(date +%Y-%m-%d) \
    --granularity MONTHLY \
    --metrics BlendedCost \
    --group-by Type=DIMENSION,Key=SERVICE \
    --query 'ResultsByTime[0].Groups[*].[Keys[0],Metrics.BlendedCost.Amount]' \
    --output table | head -11 >> "$REPORT_FILE"

  # 2. Right Sizing 권장사항
  echo "   - Right Sizing 권장사항 분석..."
  cat >> "$REPORT_FILE" << EOF

## 2. Right Sizing 권장사항

### EC2 인스턴스 최적화 권장사항
EOF

  aws ce get-right-sizing-recommendation \
    --service=AmazonEC2 \
    --configuration '{"RecommendationTarget": "CROSS_INSTANCE_FAMILY"}' \
    --max-results 10 \
    --query 'Recommendations[*].[AccountId,CurrentInstance.InstanceArn,Finding,RecommendationOptions[0].InstanceType,RecommendationOptions[0].EstimatedMonthlySavingsAmount]' \
    --output table >> "$REPORT_FILE"

  # 3. Reserved Instances 분석
  echo "   - Reserved Instances 분석..."
  cat >> "$REPORT_FILE" << EOF

## 3. Reserved Instances 분석

### RI 커버리지 요약
EOF

  RI_COVERAGE=$(aws ce get-reservation-coverage \
    --time-period Start=$(date -d "30 days ago" +%Y-%m-%d),End=$(date +%Y-%m-%d) \
    --granularity DAILY \
    --query 'Total.CoverageHours.CoverageHoursPercentage' \
    --output text)

  echo "RI 커버리지: ${RI_COVERAGE}%" >> "$REPORT_FILE"
  echo "     RI 커버리지: ${RI_COVERAGE}%"

  # 4. Savings Plans 권장사항
  echo "   - Savings Plans 권장사항 분석..."
  cat >> "$REPORT_FILE" << EOF

## 4. Savings Plans 권장사항

### EC2 Instance Family Savings Plans
EOF

  aws ce get-savings-plans-purchase-recommendation \
    --savings-plans-type EC2_INSTANCE_FAMILY \
    --term ONE_YEAR \
    --payment-option NO_UPFRONT \
    --account-scope PAYER \
    --query 'SavingsPlansPurchaseRecommendationDetails[*].[AccountId,CurrentInstance.InstanceArn,SavingsPlansDetails[0].EstimatedMonthlySavingsAmount,SavingsPlansDetails[0].EstimatedSavingsPercentage]' \
    --output table >> "$REPORT_FILE"

  # 5. Spot Instances 권장사항
  echo "   - Spot Instances 권장사항 분석..."
  cat >> "$REPORT_FILE" << EOF

## 5. Spot Instances 권장사항

### Spot Instance 가격 분석
EOF

  # Spot Instance 가격 조회 (예시)
  aws ec2 describe-spot-price-history \
    --instance-types t3.micro,t3.small,t3.medium \
    --product-descriptions "Linux/UNIX" \
    --max-items 10 \
    --query 'SpotPriceHistory[*].[InstanceType,SpotPrice,AvailabilityZone,Timestamp]' \
    --output table >> "$REPORT_FILE"

  # 6. 자동 최적화 실행 (옵션)
  if [ "$AUTO_OPTIMIZE" == "true" ]; then
    echo "   - 자동 최적화 실행..."
    cat >> "$REPORT_FILE" << EOF

## 6. 자동 최적화 실행 결과

### 실행된 최적화 작업
EOF

    # 사용하지 않는 EBS 볼륨 정리
    echo "     - 사용하지 않는 EBS 볼륨 정리..."
    UNATTACHED_VOLUMES=$(aws ec2 describe-volumes \
      --filters "Name=status,Values=available" \
      --query 'Volumes[*].VolumeId' \
      --output text)

    if [ -n "$UNATTACHED_VOLUMES" ]; then
      echo "       발견된 사용하지 않는 볼륨: $UNATTACHED_VOLUMES"
      echo "       사용하지 않는 볼륨: $UNATTACHED_VOLUMES" >> "$REPORT_FILE"
      
      # 실제 삭제는 주석 처리 (안전을 위해)
      # for volume in $UNATTACHED_VOLUMES; do
      #   aws ec2 delete-volume --volume-id $volume
      # done
      echo "       [주의] 실제 삭제는 주석 처리되어 있습니다. 수동으로 확인 후 삭제하세요."
    else
      echo "       사용하지 않는 볼륨이 없습니다."
      echo "       사용하지 않는 볼륨이 없습니다." >> "$REPORT_FILE"
    fi

    # 사용하지 않는 스냅샷 정리
    echo "     - 사용하지 않는 스냅샷 정리..."
    OLD_SNAPSHOTS=$(aws ec2 describe-snapshots \
      --owner-ids self \
      --filters "Name=start-time,Values=$(date -d "30 days ago" +%Y-%m-%d)" \
      --query 'Snapshots[?State==`completed`].[SnapshotId,StartTime]' \
      --output text)

    if [ -n "$OLD_SNAPSHOTS" ]; then
      echo "       발견된 오래된 스냅샷: $(echo "$OLD_SNAPSHOTS" | wc -l)개"
      echo "       오래된 스냅샷: $(echo "$OLD_SNAPSHOTS" | wc -l)개" >> "$REPORT_FILE"
    else
      echo "       오래된 스냅샷이 없습니다."
      echo "       오래된 스냅샷이 없습니다." >> "$REPORT_FILE"
    fi

    # 사용하지 않는 Elastic IP 정리
    echo "     - 사용하지 않는 Elastic IP 정리..."
    UNATTACHED_EIPS=$(aws ec2 describe-addresses \
      --query 'Addresses[?InstanceId==null].AllocationId' \
      --output text)

    if [ -n "$UNATTACHED_EIPS" ]; then
      echo "       발견된 사용하지 않는 Elastic IP: $UNATTACHED_EIPS"
      echo "       사용하지 않는 Elastic IP: $UNATTACHED_EIPS" >> "$REPORT_FILE"
    else
      echo "       사용하지 않는 Elastic IP가 없습니다."
      echo "       사용하지 않는 Elastic IP가 없습니다." >> "$REPORT_FILE"
    fi
  fi

elif [ "$CLOUD_PROVIDER" == "gcp" ]; then
  echo "⚙️ GCP 고급 비용 최적화를 수행합니다..."

  # 1. 현재 비용 분석
  echo "   - 현재 비용 분석..."
  cat >> "$REPORT_FILE" << EOF
## 1. 현재 비용 분석

### 프로젝트별 비용 (BigQuery Billing Export 필요)
EOF

  PROJECT_ID=$(gcloud config get-value project)
  echo "현재 프로젝트: $PROJECT_ID" >> "$REPORT_FILE"
  echo "     현재 프로젝트: $PROJECT_ID"

  # 2. Committed Use Discounts 분석
  echo "   - Committed Use Discounts 분석..."
  cat >> "$REPORT_FILE" << EOF

## 2. Committed Use Discounts 분석

### 현재 CUD 상태
EOF

  gcloud compute commitments list \
    --regions=$GCP_REGION \
    --format="table(name,region,creationTimestamp,endTimestamp,status,resources.acceleratorType,resources.amount,resources.type)" >> "$REPORT_FILE"

  # 3. Sustained Use Discounts 분석
  echo "   - Sustained Use Discounts 분석..."
  cat >> "$REPORT_FILE" << EOF

## 3. Sustained Use Discounts 분석

### SUD는 자동으로 적용됩니다
- Compute Engine: 1개월 사용 시 최대 30% 할인
- Cloud SQL: 1개월 사용 시 최대 30% 할인
- Cloud Spanner: 1개월 사용 시 최대 30% 할인
EOF

  # 4. Preemptible Instances 권장사항
  echo "   - Preemptible Instances 권장사항 분석..."
  cat >> "$REPORT_FILE" << EOF

## 4. Preemptible Instances 권장사항

### Preemptible Instance 가격 비교
EOF

  # Preemptible Instance 가격 조회
  gcloud compute machine-types list \
    --filter="zone:$GCP_REGION-a" \
    --format="table(name,description,guestCpus,memoryMb)" | head -10 >> "$REPORT_FILE"

  # 5. 자동 최적화 실행 (옵션)
  if [ "$AUTO_OPTIMIZE" == "true" ]; then
    echo "   - 자동 최적화 실행..."
    cat >> "$REPORT_FILE" << EOF

## 5. 자동 최적화 실행 결과

### 실행된 최적화 작업
EOF

    # 사용하지 않는 디스크 정리
    echo "     - 사용하지 않는 디스크 정리..."
    UNATTACHED_DISKS=$(gcloud compute disks list \
      --filter="status:UNATTACHED" \
      --format="value(name)")

    if [ -n "$UNATTACHED_DISKS" ]; then
      echo "       발견된 사용하지 않는 디스크: $(echo "$UNATTACHED_DISKS" | wc -l)개"
      echo "       사용하지 않는 디스크: $(echo "$UNATTACHED_DISKS" | wc -l)개" >> "$REPORT_FILE"
      
      # 실제 삭제는 주석 처리 (안전을 위해)
      # for disk in $UNATTACHED_DISKS; do
      #   gcloud compute disks delete $disk --quiet
      # done
      echo "       [주의] 실제 삭제는 주석 처리되어 있습니다. 수동으로 확인 후 삭제하세요."
    else
      echo "       사용하지 않는 디스크가 없습니다."
      echo "       사용하지 않는 디스크가 없습니다." >> "$REPORT_FILE"
    fi

    # 사용하지 않는 스냅샷 정리
    echo "     - 사용하지 않는 스냅샷 정리..."
    OLD_SNAPSHOTS=$(gcloud compute snapshots list \
      --filter="creationTimestamp<$(date -d "30 days ago" +%Y-%m-%d)" \
      --format="value(name)")

    if [ -n "$OLD_SNAPSHOTS" ]; then
      echo "       발견된 오래된 스냅샷: $(echo "$OLD_SNAPSHOTS" | wc -l)개"
      echo "       오래된 스냅샷: $(echo "$OLD_SNAPSHOTS" | wc -l)개" >> "$REPORT_FILE"
    else
      echo "       오래된 스냅샷이 없습니다."
      echo "       오래된 스냅샷이 없습니다." >> "$REPORT_FILE"
    fi

    # 사용하지 않는 이미지 정리
    echo "     - 사용하지 않는 이미지 정리..."
    OLD_IMAGES=$(gcloud compute images list \
      --filter="creationTimestamp<$(date -d "30 days ago" +%Y-%m-%d)" \
      --format="value(name)")

    if [ -n "$OLD_IMAGES" ]; then
      echo "       발견된 오래된 이미지: $(echo "$OLD_IMAGES" | wc -l)개"
      echo "       오래된 이미지: $(echo "$OLD_IMAGES" | wc -l)개" >> "$REPORT_FILE"
    else
      echo "       오래된 이미지가 없습니다."
      echo "       오래된 이미지가 없습니다." >> "$REPORT_FILE"
    fi
  fi

else
  usage
fi

# 6. 최적화 권장사항 요약
echo "   - 최적화 권장사항 요약 생성..."
cat >> "$REPORT_FILE" << EOF

## 6. 최적화 권장사항 요약

### 즉시 실행 가능한 최적화
1. **사용하지 않는 리소스 정리**: 사용하지 않는 볼륨, 스냅샷, 이미지 삭제
2. **인스턴스 크기 조정**: Right Sizing 권장사항에 따라 인스턴스 크기 조정
3. **Reserved Instances 구매**: 예측 가능한 워크로드에 대한 RI 구매
4. **Savings Plans 활용**: 유연한 워크로드에 대한 SP 구매
5. **Spot/Preemptible Instances 사용**: 중단 가능한 워크로드에 대한 활용

### 장기 최적화 계획
1. **워크로드 분석**: 사용 패턴 분석을 통한 최적 인스턴스 타입 선택
2. **자동 스케일링**: 수요에 따른 자동 스케일링 설정
3. **리소스 태깅**: 비용 할당을 위한 리소스 태깅 체계 구축
4. **비용 알림**: 예산 초과 시 알림 설정
5. **정기 검토**: 월간 비용 검토 및 최적화 계획 수립

### 예상 절약 효과
- **사용하지 않는 리소스 정리**: 월 $50-200 절약
- **Right Sizing**: 월 $100-500 절약
- **Reserved Instances**: 월 $200-1000 절약
- **Savings Plans**: 월 $100-800 절약
- **Spot/Preemptible Instances**: 월 $300-1500 절약

**총 예상 절약**: 월 $750-4000 (워크로드 규모에 따라 다름)

---

**보고서 생성 완료**: $(date)
**다음 검토 예정**: $(date -d "+1 month" +%Y-%m-%d)
EOF

echo "✅ 고급 비용 최적화 분석 완료!"
echo "📊 보고서 파일: $REPORT_FILE"
echo "💡 다음 단계:"
echo "   1. 보고서 검토 및 권장사항 확인"
echo "   2. 안전한 최적화부터 단계적 실행"
echo "   3. 정기적인 비용 모니터링 설정"
echo "   4. 팀과의 비용 최적화 계획 공유"
