#!/bin/bash

# Cloud Master 학습 진도 추적 시스템

# 사용법 함수
usage() {
  echo "Usage: $0 [--start-session] [--end-session] [--check-progress] [--generate-report]"
  echo "  --start-session: 학습 세션 시작"
  echo "  --end-session: 학습 세션 종료"
  echo "  --check-progress: 현재 진도 확인"
  echo "  --generate-report: 상세 진도 리포트 생성"
  exit 1
}

# 인자 확인
if [ $# -eq 0 ]; then
  usage
fi

TRACKING_DIR="$HOME/.cloud-master-tracking"
SESSION_FILE="$TRACKING_DIR/current-session.json"
PROGRESS_FILE="$TRACKING_DIR/learning-progress.json"
METRICS_FILE="$TRACKING_DIR/metrics.json"

# 추적 디렉토리 생성
mkdir -p "$TRACKING_DIR"

# 학습 세션 시작
start_session() {
  echo "🚀 Cloud Master 학습 세션을 시작합니다..."
  
  local session_id="session-$(date +%Y%m%d-%H%M%S)"
  local start_time=$(date +%s)
  
  cat > "$SESSION_FILE" << EOF
{
  "session_id": "$session_id",
  "start_time": $start_time,
  "start_timestamp": "$(date -Iseconds)",
  "status": "active"
}
EOF

  # 세션 시작 시간 기록
  echo "$start_time" > "$TRACKING_DIR/session-start"
  
  echo "✅ 학습 세션 시작: $session_id"
  echo "📊 진도 추적이 활성화되었습니다."
}

# 학습 세션 종료
end_session() {
  echo "🏁 Cloud Master 학습 세션을 종료합니다..."
  
  if [ ! -f "$SESSION_FILE" ]; then
    echo "❌ 활성 세션이 없습니다."
    return 1
  fi
  
  local end_time=$(date +%s)
  local start_time=$(jq -r '.start_time' "$SESSION_FILE")
  local session_duration=$((end_time - start_time))
  local hours=$((session_duration / 3600))
  local minutes=$(((session_duration % 3600) / 60))
  
  # 세션 데이터 업데이트
  jq --arg end_time "$end_time" --arg duration "$session_duration" \
     '. + {end_time: ($end_time | tonumber), duration: ($duration | tonumber), status: "completed"}' \
     "$SESSION_FILE" > "$SESSION_FILE.tmp" && mv "$SESSION_FILE.tmp" "$SESSION_FILE"
  
  echo "✅ 학습 세션 종료"
  echo "⏱️ 총 학습 시간: ${hours}시간 ${minutes}분"
  
  # 진도 데이터 저장
  save_progress_data
}

# 현재 진도 확인
check_progress() {
  echo "📊 현재 학습 진도를 확인합니다..."
  
  if [ ! -f "$PROGRESS_FILE" ]; then
    echo "❌ 진도 데이터가 없습니다. 먼저 학습을 시작하세요."
    return 1
  fi
  
  # 실시간 진도 계산
  local day1_progress=$(calculate_day1_progress)
  local day2_progress=$(calculate_day2_progress)
  local day3_progress=$(calculate_day3_progress)
  local overall_progress=$(( (day1_progress + day2_progress + day3_progress) / 3 ))
  
  echo "📈 학습 진도 현황:"
  echo "   Day 1 (VM 배포): $day1_progress%"
  echo "   Day 2 (Kubernetes): $day2_progress%"
  echo "   Day 3 (모니터링): $day3_progress%"
  echo "   전체 진도: $overall_progress%"
  
  # 현재 세션 정보
  if [ -f "$SESSION_FILE" ]; then
    local session_duration=$(get_current_session_duration)
    echo "   현재 세션 시간: $session_duration"
  fi
}

# Day 1 진도 계산
calculate_day1_progress() {
  local progress=0
  
  # AWS CLI 설정 확인
  if aws sts get-caller-identity >/dev/null 2>&1; then
    ((progress += 20))
  fi
  
  # GCP CLI 설정 확인
  if gcloud auth list --filter=status:ACTIVE --format="value(account)" | head -n 1 >/dev/null 2>&1; then
    ((progress += 20))
  fi
  
  # EC2 인스턴스 생성 확인
  local ec2_count=$(aws ec2 describe-instances --query 'Reservations[*].Instances[*].[InstanceId]' --output text | wc -l)
  if [ "$ec2_count" -gt 0 ]; then
    ((progress += 20))
  fi
  
  # GCE 인스턴스 생성 확인
  local gce_count=$(gcloud compute instances list --format="value(name)" | wc -l)
  if [ "$gce_count" -gt 0 ]; then
    ((progress += 20))
  fi
  
  # Docker 컨테이너 실행 확인
  local docker_count=$(docker ps -q | wc -l)
  if [ "$docker_count" -gt 0 ]; then
    ((progress += 20))
  fi
  
  echo $progress
}

# Day 2 진도 계산
calculate_day2_progress() {
  local progress=0
  
  # Kubernetes 클러스터 확인
  if kubectl cluster-info >/dev/null 2>&1; then
    ((progress += 30))
  fi
  
  # Kubernetes 리소스 확인
  local pod_count=$(kubectl get pods --all-namespaces --no-headers | wc -l)
  if [ "$pod_count" -gt 0 ]; then
    ((progress += 20))
  fi
  
  local service_count=$(kubectl get services --all-namespaces --no-headers | wc -l)
  if [ "$service_count" -gt 0 ]; then
    ((progress += 20))
  fi
  
  # Deployment 확인
  local deployment_count=$(kubectl get deployments --all-namespaces --no-headers | wc -l)
  if [ "$deployment_count" -gt 0 ]; then
    ((progress += 30))
  fi
  
  echo $progress
}

# Day 3 진도 계산
calculate_day3_progress() {
  local progress=0
  
  # Prometheus 확인
  if kubectl get pods --all-namespaces | grep -q prometheus; then
    ((progress += 25))
  fi
  
  # Grafana 확인
  if kubectl get pods --all-namespaces | grep -q grafana; then
    ((progress += 25))
  fi
  
  # 로드밸런서 확인
  local lb_count=$(kubectl get services --all-namespaces --field-selector spec.type=LoadBalancer --no-headers | wc -l)
  if [ "$lb_count" -gt 0 ]; then
    ((progress += 25))
  fi
  
  # 모니터링 대시보드 확인
  if [ -f "$HOME/.cloud-master-dashboard-created" ]; then
    ((progress += 25))
  fi
  
  echo $progress
}

# 현재 세션 시간 계산
get_current_session_duration() {
  if [ -f "$TRACKING_DIR/session-start" ]; then
    local start_time=$(cat "$TRACKING_DIR/session-start")
    local current_time=$(date +%s)
    local duration=$((current_time - start_time))
    local hours=$((duration / 3600))
    local minutes=$(((duration % 3600) / 60))
    echo "${hours}시간 ${minutes}분"
  else
    echo "세션 없음"
  fi
}

# 진도 데이터 저장
save_progress_data() {
  local day1_progress=$(calculate_day1_progress)
  local day2_progress=$(calculate_day2_progress)
  local day3_progress=$(calculate_day3_progress)
  local overall_progress=$(( (day1_progress + day2_progress + day3_progress) / 3 ))
  
  # 명령어 실행 횟수
  local aws_commands=$(grep -c "aws " ~/.bash_history 2>/dev/null || echo "0")
  local gcp_commands=$(grep -c "gcloud " ~/.bash_history 2>/dev/null || echo "0")
  local k8s_commands=$(grep -c "kubectl " ~/.bash_history 2>/dev/null || echo "0")
  local docker_commands=$(grep -c "docker " ~/.bash_history 2>/dev/null || echo "0")
  
  # 리소스 사용량
  local ec2_instances=$(aws ec2 describe-instances --query 'Reservations[*].Instances[*].[InstanceId]' --output text 2>/dev/null | wc -l || echo "0")
  local gce_instances=$(gcloud compute instances list --format="value(name)" 2>/dev/null | wc -l || echo "0")
  local k8s_pods=$(kubectl get pods --all-namespaces --no-headers 2>/dev/null | wc -l || echo "0")
  
  cat > "$PROGRESS_FILE" << EOF
{
  "last_updated": "$(date -Iseconds)",
  "progress": {
    "day1": $day1_progress,
    "day2": $day2_progress,
    "day3": $day3_progress,
    "overall": $overall_progress
  },
  "activity": {
    "aws_commands": $aws_commands,
    "gcp_commands": $gcp_commands,
    "k8s_commands": $k8s_commands,
    "docker_commands": $docker_commands
  },
  "resources": {
    "ec2_instances": $ec2_instances,
    "gce_instances": $gce_instances,
    "k8s_pods": $k8s_pods
  }
}
EOF
}

# 상세 진도 리포트 생성
generate_report() {
  echo "📊 Cloud Master 학습 진도 상세 리포트를 생성합니다..."
  
  if [ ! -f "$PROGRESS_FILE" ]; then
    echo "❌ 진도 데이터가 없습니다. 먼저 학습을 시작하세요."
    return 1
  fi
  
  local report_file="learning-progress-report-$(date +%Y%m%d-%H%M%S).md"
  
  cat > "$report_file" << EOF
# Cloud Master 학습 진도 상세 리포트

**생성 시간**: $(date)
**학습자**: $(whoami)

## 📈 진도 현황

### 전체 진도
- **Day 1 (VM 배포)**: $(jq -r '.progress.day1' "$PROGRESS_FILE")%
- **Day 2 (Kubernetes)**: $(jq -r '.progress.day2' "$PROGRESS_FILE")%
- **Day 3 (모니터링)**: $(jq -r '.progress.day3' "$PROGRESS_FILE")%
- **전체 진도**: $(jq -r '.progress.overall' "$PROGRESS_FILE")%

### 활동 통계
- **AWS 명령어 실행**: $(jq -r '.activity.aws_commands' "$PROGRESS_FILE")회
- **GCP 명령어 실행**: $(jq -r '.activity.gcp_commands' "$PROGRESS_FILE")회
- **Kubernetes 명령어 실행**: $(jq -r '.activity.k8s_commands' "$PROGRESS_FILE")회
- **Docker 명령어 실행**: $(jq -r '.activity.docker_commands' "$PROGRESS_FILE")회

### 리소스 현황
- **EC2 인스턴스**: $(jq -r '.resources.ec2_instances' "$PROGRESS_FILE")개
- **GCE 인스턴스**: $(jq -r '.resources.gce_instances' "$PROGRESS_FILE")개
- **Kubernetes Pods**: $(jq -r '.resources.k8s_pods' "$PROGRESS_FILE")개

## 🎯 다음 단계 권장사항

### Day 1 완료를 위한 권장사항
EOF

  # Day 1 권장사항
  local day1_progress=$(jq -r '.progress.day1' "$PROGRESS_FILE")
  if [ "$day1_progress" -lt 100 ]; then
    cat >> "$report_file" << EOF
- AWS CLI 설정 완료
- GCP CLI 설정 완료
- EC2 인스턴스 생성 및 관리
- GCE 인스턴스 생성 및 관리
- Docker 컨테이너 실행 및 관리
EOF
  else
    echo "- ✅ Day 1 모든 실습 완료" >> "$report_file"
  fi

  cat >> "$report_file" << EOF

### Day 2 완료를 위한 권장사항
EOF

  # Day 2 권장사항
  local day2_progress=$(jq -r '.progress.day2' "$PROGRESS_FILE")
  if [ "$day2_progress" -lt 100 ]; then
    cat >> "$report_file" << EOF
- Kubernetes 클러스터 구축
- Pod, Service, Deployment 생성
- 애플리케이션 배포 및 관리
- 네트워킹 및 서비스 설정
EOF
  else
    echo "- ✅ Day 2 모든 실습 완료" >> "$report_file"
  fi

  cat >> "$report_file" << EOF

### Day 3 완료를 위한 권장사항
EOF

  # Day 3 권장사항
  local day3_progress=$(jq -r '.progress.day3' "$PROGRESS_FILE")
  if [ "$day3_progress" -lt 100 ]; then
    cat >> "$report_file" << EOF
- Prometheus 및 Grafana 설치
- 모니터링 대시보드 구성
- 로드밸런서 설정
- 비용 최적화 분석
EOF
  else
    echo "- ✅ Day 3 모든 실습 완료" >> "$report_file"
  fi

  cat >> "$report_file" << EOF

## 📊 학습 패턴 분석

### 명령어 사용 패턴
- 가장 많이 사용한 도구: $(get_most_used_tool)
- 학습 집중도: $(calculate_learning_focus)
- 실습 복잡도: $(calculate_practice_complexity)

### 리소스 활용도
- 클라우드 리소스 활용도: $(calculate_resource_utilization)
- 비용 효율성: $(calculate_cost_efficiency)

---

**리포트 생성 완료**: $report_file
**다음 검토 예정**: $(date -d "+1 week" +%Y-%m-%d)
EOF

  echo "✅ 상세 진도 리포트 생성 완료: $report_file"
}

# 가장 많이 사용한 도구 확인
get_most_used_tool() {
  local aws_count=$(jq -r '.activity.aws_commands' "$PROGRESS_FILE")
  local gcp_count=$(jq -r '.activity.gcp_commands' "$PROGRESS_FILE")
  local k8s_count=$(jq -r '.activity.k8s_commands' "$PROGRESS_FILE")
  local docker_count=$(jq -r '.activity.docker_commands' "$PROGRESS_FILE")
  
  if [ "$aws_count" -ge "$gcp_count" ] && [ "$aws_count" -ge "$k8s_count" ] && [ "$aws_count" -ge "$docker_count" ]; then
    echo "AWS CLI"
  elif [ "$gcp_count" -ge "$k8s_count" ] && [ "$gcp_count" -ge "$docker_count" ]; then
    echo "GCP CLI"
  elif [ "$k8s_count" -ge "$docker_count" ]; then
    echo "Kubernetes"
  else
    echo "Docker"
  fi
}

# 학습 집중도 계산
calculate_learning_focus() {
  local total_commands=$(jq -r '.activity.aws_commands + .activity.gcp_commands + .activity.k8s_commands + .activity.docker_commands' "$PROGRESS_FILE")
  local unique_tools=0
  
  [ "$(jq -r '.activity.aws_commands' "$PROGRESS_FILE")" -gt 0 ] && ((unique_tools++))
  [ "$(jq -r '.activity.gcp_commands' "$PROGRESS_FILE")" -gt 0 ] && ((unique_tools++))
  [ "$(jq -r '.activity.k8s_commands' "$PROGRESS_FILE")" -gt 0 ] && ((unique_tools++))
  [ "$(jq -r '.activity.docker_commands' "$PROGRESS_FILE")" -gt 0 ] && ((unique_tools++))
  
  if [ "$unique_tools" -eq 1 ]; then
    echo "높음 (단일 도구 집중)"
  elif [ "$unique_tools" -eq 2 ]; then
    echo "중간 (2개 도구 사용)"
  else
    echo "낮음 (다양한 도구 사용)"
  fi
}

# 실습 복잡도 계산
calculate_practice_complexity() {
  local k8s_pods=$(jq -r '.resources.k8s_pods' "$PROGRESS_FILE")
  local total_instances=$(($(jq -r '.resources.ec2_instances' "$PROGRESS_FILE") + $(jq -r '.resources.gce_instances' "$PROGRESS_FILE")))
  
  if [ "$k8s_pods" -gt 5 ] || [ "$total_instances" -gt 3 ]; then
    echo "높음"
  elif [ "$k8s_pods" -gt 2 ] || [ "$total_instances" -gt 1 ]; then
    echo "중간"
  else
    echo "낮음"
  fi
}

# 리소스 활용도 계산
calculate_resource_utilization() {
  local total_resources=$(($(jq -r '.resources.ec2_instances' "$PROGRESS_FILE") + $(jq -r '.resources.gce_instances' "$PROGRESS_FILE") + $(jq -r '.resources.k8s_pods' "$PROGRESS_FILE")))
  
  if [ "$total_resources" -gt 10 ]; then
    echo "높음"
  elif [ "$total_resources" -gt 5 ]; then
    echo "중간"
  else
    echo "낮음"
  fi
}

# 비용 효율성 계산
calculate_cost_efficiency() {
  local total_commands=$(jq -r '.activity.aws_commands + .activity.gcp_commands + .activity.k8s_commands + .activity.docker_commands' "$PROGRESS_FILE")
  local total_resources=$(($(jq -r '.resources.ec2_instances' "$PROGRESS_FILE") + $(jq -r '.resources.gce_instances' "$PROGRESS_FILE") + $(jq -r '.resources.k8s_pods' "$PROGRESS_FILE")))
  
  if [ "$total_resources" -gt 0 ] && [ "$total_commands" -gt 0 ]; then
    local efficiency=$((total_commands / total_resources))
    if [ "$efficiency" -gt 10 ]; then
      echo "높음"
    elif [ "$efficiency" -gt 5 ]; then
      echo "중간"
    else
      echo "낮음"
    fi
  else
    echo "측정 불가"
  fi
}

# 메인 실행
case $1 in
  --start-session)
    start_session
    ;;
  --end-session)
    end_session
    ;;
  --check-progress)
    check_progress
    ;;
  --generate-report)
    generate_report
    ;;
  *)
    usage
    ;;
esac
