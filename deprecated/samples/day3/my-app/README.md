# Cloud Master Day3 - 모니터링 & 비용 최적화 실습

## 🎯 실습 목표
- 로드밸런싱 환경 구성 및 트래픽 분산
- 오토스케일링 정책 설정 및 자동 확장/축소
- Prometheus + Grafana 모니터링 시스템 구축
- 클라우드 비용 분석 및 최적화 전략 수립

## 🚀 빠른 시작

### 1. 클라우드 환경 설정
```bash
# AWS 환경 설정
chmod +x ../../../repos/cloud-scripts/aws-setup-helper.sh
./../../../repos/cloud-scripts/aws-setup-helper.sh

# GCP 환경 설정
chmod +x ../../../repos/cloud-scripts/gcp-setup-helper.sh
./../../../repos/cloud-scripts/gcp-setup-helper.sh
```

### 2. 로드밸런서 설정
```bash
# 로드밸런서 자동 설정
chmod +x ../../../repos/cloud-scripts/load-balancer-setup.sh
./../../../repos/cloud-scripts/load-balancer-setup.sh aws
./../../../repos/cloud-scripts/load-balancer-setup.sh gcp
```

### 3. 모니터링 스택 배포
```bash
# 모니터링 스택 자동 배포
chmod +x ../../../repos/cloud-scripts/monitoring-stack-deploy.sh
./../../../repos/cloud-scripts/monitoring-stack-deploy.sh
```

### 4. 비용 최적화 분석
```bash
# 비용 최적화 스크립트 실행
chmod +x ../../../repos/cloud-scripts/cost-optimization.sh
./../../../repos/cloud-scripts/cost-optimization.sh aws
./../../../repos/cloud-scripts/cost-optimization.sh gcp
```

## 📁 파일 구조
```
my-app/
├── README.md                    # 이 파일
├── app.js                      # Node.js 애플리케이션
├── package.json                # Node.js 의존성
├── Dockerfile                  # Docker 이미지
├── docker-compose.yml          # Docker Compose 설정
├── k8s/                        # Kubernetes 매니페스트
│   └── deployment.yaml
├── monitoring/                 # 모니터링 설정
│   └── prometheus/
│       └── prometheus.yml
└── scripts/                    # 배포 스크립트
    └── deploy-high-availability.sh
```

## 🔧 실습 단계

### 1단계: 로드밸런싱 설정
```bash
# AWS ALB 생성
aws elbv2 create-load-balancer \
  --name my-alb \
  --subnets subnet-12345678 subnet-87654321 \
  --security-groups sg-12345678

# GCP HTTP[S] Load Balancing 설정
gcloud compute backend-services create my-backend-service \
  --protocol=HTTP \
  --port-name=http \
  --health-checks=my-health-check \
  --global
```

### 2단계: 오토스케일링 설정
```bash
# AWS Auto Scaling Group 생성
aws autoscaling create-auto-scaling-group \
  --auto-scaling-group-name my-asg \
  --launch-template LaunchTemplateName=my-template,Version='$Latest' \
  --min-size 1 \
  --max-size 10 \
  --desired-capacity 2

# GCP Managed Instance Group 설정
gcloud compute instance-groups managed create my-mig \
  --template=my-template \
  --size=2 \
  --zone=us-central1-a
```

### 3단계: 모니터링 시스템 구축
```bash
# Prometheus 실행
docker run -d \
  --name prometheus \
  -p 9090:9090 \
  -v $[pwd]/monitoring/prometheus/prometheus.yml:/etc/prometheus/prometheus.yml \
  prom/prometheus

# Grafana 실행
docker run -d \
  --name grafana \
  -p 3000:3000 \
  grafana/grafana

# Node Exporter 실행
docker run -d \
  --name node-exporter \
  -p 9100:9100 \
  prom/node-exporter
```

### 4단계: 비용 최적화 분석
```bash
# AWS 비용 분석
aws ce get-cost-and-usage \
  --time-period Start=2024-01-01,End=2024-01-31 \
  --granularity MONTHLY \
  --metrics BlendedCost

# GCP 비용 분석
gcloud billing accounts list
gcloud billing budgets list --billing-account=123456789012
```

## 🧹 정리
```bash
# 모니터링 컨테이너 정리
docker stop prometheus grafana node-exporter alertmanager
docker rm prometheus grafana node-exporter alertmanager

# AWS 리소스 정리
chmod +x ../../../repos/cloud-scripts/aws-resource-cleanup.sh
./../../../repos/cloud-scripts/aws-resource-cleanup.sh

# GCP 리소스 정리
chmod +x ../../../repos/cloud-scripts/gcp-project-cleanup.sh
./../../../repos/cloud-scripts/gcp-project-cleanup.sh
```

## 📚 참고 자료
- ["Cloud Master Day3 가이드"](cloud_master/textbook/Day3/README.md)
- ["로드밸런싱 실습"](cloud_master/textbook/Day3/practices/load-balancing.md)
- ["모니터링 기초 실습"](cloud_master/textbook/Day3/practices/monitoring-basics.md)
- ["비용 최적화 실습"](cloud_master/textbook/Day3/practices/cost-optimization.md)
- ["cloud-scripts 가이드"](cloud_master/repos/cloud-scripts/README.md)