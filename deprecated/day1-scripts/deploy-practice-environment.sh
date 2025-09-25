#!/bin/bash

# Cloud Master 실습 환경 자동 배포 스크립트

# 사용법 함수
usage() {
  echo "Usage: $0 [aws|gcp] [--dry-run]"
  echo "  aws: AWS 환경에 실습 환경 배포"
  echo "  gcp: GCP 환경에 실습 환경 배포"
  echo "  --dry-run: 실제 배포 없이 검증만 수행"
  exit 1
}

# 인자 확인
if [ -z "$1" ]; then
  usage
fi

CLOUD_PROVIDER=$1
DRY_RUN=false

# --dry-run 옵션 확인
if [ "$2" == "--dry-run" ]; then
  DRY_RUN=true
fi

ENVIRONMENT_NAME="cloud-master-practice"
REGION="ap-northeast-2"  # AWS 기본 리전
GCP_REGION="asia-northeast3"  # GCP 기본 리전

echo "🚀 Cloud Master 실습 환경 배포를 시작합니다..."
echo "   클라우드 제공자: $CLOUD_PROVIDER"
echo "   환경 이름: $ENVIRONMENT_NAME"
echo "   드라이런 모드: $DRY_RUN"

if [ "$CLOUD_PROVIDER" == "aws" ]; then
  echo "⚙️ AWS 환경에 실습 환경을 배포합니다..."

  # 1. VPC 및 서브넷 생성
  echo "   - VPC 및 서브넷 생성..."
  if [ "$DRY_RUN" == "false" ]; then
    VPC_ID=$(aws ec2 create-vpc \
      --cidr-block 10.0.0.0/16 \
      --tag-specifications 'ResourceType=vpc,Tags=[{Key=Name,Value='$ENVIRONMENT_NAME'-vpc}]' \
      --query 'Vpc.VpcId' \
      --output text)
    
    # 서브넷 생성
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
    
    echo "     VPC ID: $VPC_ID"
    echo "     서브넷 1 ID: $SUBNET_1_ID"
    echo "     서브넷 2 ID: $SUBNET_2_ID"
  else
    echo "     [DRY RUN] VPC 및 서브넷 생성 명령어 출력"
    echo "     aws ec2 create-vpc --cidr-block 10.0.0.0/16 --tag-specifications 'ResourceType=vpc,Tags=[{Key=Name,Value='$ENVIRONMENT_NAME'-vpc}]'"
  fi

  # 2. 보안 그룹 생성
  echo "   - 보안 그룹 생성..."
  if [ "$DRY_RUN" == "false" ]; then
    SG_ID=$(aws ec2 create-security-group \
      --group-name $ENVIRONMENT_NAME-sg \
      --description "Security group for Cloud Master practice environment" \
      --vpc-id $VPC_ID \
      --query 'GroupId' \
      --output text)
    
    # 인바운드 규칙 추가
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
    
    echo "     보안 그룹 ID: $SG_ID"
  else
    echo "     [DRY RUN] 보안 그룹 생성 명령어 출력"
    echo "     aws ec2 create-security-group --group-name $ENVIRONMENT_NAME-sg --description 'Security group for Cloud Master practice environment' --vpc-id \$VPC_ID"
  fi

  # 3. EC2 인스턴스 생성 (Day 1 실습용)
  echo "   - EC2 인스턴스 생성 (Day 1 실습용)..."
  if [ "$DRY_RUN" == "false" ]; then
    INSTANCE_ID=$(aws ec2 run-instances \
      --image-id ami-0c9c942bd7bf113a2 \
      --count 1 \
      --instance-type t3.micro \
      --key-name $ENVIRONMENT_NAME-key \
      --security-group-ids $SG_ID \
      --subnet-id $SUBNET_1_ID \
      --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value='$ENVIRONMENT_NAME'-instance}]' \
      --query 'Instances[0].InstanceId' \
      --output text)
    
    echo "     인스턴스 ID: $INSTANCE_ID"
  else
    echo "     [DRY RUN] EC2 인스턴스 생성 명령어 출력"
    echo "     aws ec2 run-instances --image-id ami-0c9c942bd7bf113a2 --count 1 --instance-type t3.micro --key-name $ENVIRONMENT_NAME-key --security-group-ids \$SG_ID --subnet-id \$SUBNET_1_ID"
  fi

  # 4. EKS 클러스터 생성 (Day 2 실습용)
  echo "   - EKS 클러스터 생성 (Day 2 실습용)..."
  if [ "$DRY_RUN" == "false" ]; then
    # eksctl을 사용한 EKS 클러스터 생성
    eksctl create cluster \
      --name $ENVIRONMENT_NAME-eks \
      --region $REGION \
      --nodegroup-name workers \
      --node-type t3.medium \
      --nodes 2 \
      --nodes-min 1 \
      --nodes-max 3 \
      --managed
    
    echo "     EKS 클러스터: $ENVIRONMENT_NAME-eks"
  else
    echo "     [DRY RUN] EKS 클러스터 생성 명령어 출력"
    echo "     eksctl create cluster --name $ENVIRONMENT_NAME-eks --region $REGION --nodegroup-name workers --node-type t3.medium --nodes 2 --nodes-min 1 --nodes-max 3 --managed"
  fi

  # 5. ALB 생성 (Day 3 실습용)
  echo "   - ALB 생성 (Day 3 실습용)..."
  if [ "$DRY_RUN" == "false" ]; then
    # 타겟 그룹 생성
    TARGET_GROUP_ARN=$(aws elbv2 create-target-group \
      --name $ENVIRONMENT_NAME-tg \
      --protocol HTTP \
      --port 80 \
      --vpc-id $VPC_ID \
      --query 'TargetGroups[0].TargetGroupArn' \
      --output text)
    
    # ALB 생성
    ALB_ARN=$(aws elbv2 create-load-balancer \
      --name $ENVIRONMENT_NAME-alb \
      --subnets $SUBNET_1_ID $SUBNET_2_ID \
      --security-groups $SG_ID \
      --query 'LoadBalancers[0].LoadBalancerArn' \
      --output text)
    
    echo "     ALB ARN: $ALB_ARN"
    echo "     타겟 그룹 ARN: $TARGET_GROUP_ARN"
  else
    echo "     [DRY RUN] ALB 생성 명령어 출력"
    echo "     aws elbv2 create-load-balancer --name $ENVIRONMENT_NAME-alb --subnets \$SUBNET_1_ID \$SUBNET_2_ID --security-groups \$SG_ID"
  fi

elif [ "$CLOUD_PROVIDER" == "gcp" ]; then
  echo "⚙️ GCP 환경에 실습 환경을 배포합니다..."

  # 1. VPC 네트워크 생성
  echo "   - VPC 네트워크 생성..."
  if [ "$DRY_RUN" == "false" ]; then
    gcloud compute networks create $ENVIRONMENT_NAME-vpc \
      --subnet-mode custom \
      --bgp-routing-mode regional
    
    # 서브넷 생성
    gcloud compute networks subnets create $ENVIRONMENT_NAME-subnet-1 \
      --network $ENVIRONMENT_NAME-vpc \
      --range 10.0.1.0/24 \
      --region $GCP_REGION
    
    gcloud compute networks subnets create $ENVIRONMENT_NAME-subnet-2 \
      --network $ENVIRONMENT_NAME-vpc \
      --range 10.0.2.0/24 \
      --region $GCP_REGION
    
    echo "     VPC 네트워크: $ENVIRONMENT_NAME-vpc"
  else
    echo "     [DRY RUN] VPC 네트워크 생성 명령어 출력"
    echo "     gcloud compute networks create $ENVIRONMENT_NAME-vpc --subnet-mode custom --bgp-routing-mode regional"
  fi

  # 2. 방화벽 규칙 생성
  echo "   - 방화벽 규칙 생성..."
  if [ "$DRY_RUN" == "false" ]; then
    gcloud compute firewall-rules create $ENVIRONMENT_NAME-allow-ssh \
      --network $ENVIRONMENT_NAME-vpc \
      --allow tcp:22 \
      --source-ranges 0.0.0.0/0
    
    gcloud compute firewall-rules create $ENVIRONMENT_NAME-allow-http \
      --network $ENVIRONMENT_NAME-vpc \
      --allow tcp:80 \
      --source-ranges 0.0.0.0/0
    
    gcloud compute firewall-rules create $ENVIRONMENT_NAME-allow-https \
      --network $ENVIRONMENT_NAME-vpc \
      --allow tcp:443 \
      --source-ranges 0.0.0.0/0
    
    echo "     방화벽 규칙 생성 완료"
  else
    echo "     [DRY RUN] 방화벽 규칙 생성 명령어 출력"
    echo "     gcloud compute firewall-rules create $ENVIRONMENT_NAME-allow-ssh --network $ENVIRONMENT_NAME-vpc --allow tcp:22 --source-ranges 0.0.0.0/0"
  fi

  # 3. Compute Engine 인스턴스 생성 (Day 1 실습용)
  echo "   - Compute Engine 인스턴스 생성 (Day 1 실습용)..."
  if [ "$DRY_RUN" == "false" ]; then
    gcloud compute instances create $ENVIRONMENT_NAME-instance \
      --zone ${GCP_REGION}-a \
      --machine-type e2-micro \
      --network $ENVIRONMENT_NAME-vpc \
      --subnet $ENVIRONMENT_NAME-subnet-1 \
      --tags $ENVIRONMENT_NAME-tag
    
    echo "     인스턴스: $ENVIRONMENT_NAME-instance"
  else
    echo "     [DRY RUN] Compute Engine 인스턴스 생성 명령어 출력"
    echo "     gcloud compute instances create $ENVIRONMENT_NAME-instance --zone ${GCP_REGION}-a --machine-type e2-micro --network $ENVIRONMENT_NAME-vpc --subnet $ENVIRONMENT_NAME-subnet-1"
  fi

  # 4. GKE 클러스터 생성 (Day 2 실습용)
  echo "   - GKE 클러스터 생성 (Day 2 실습용)..."
  if [ "$DRY_RUN" == "false" ]; then
    gcloud container clusters create $ENVIRONMENT_NAME-gke \
      --zone ${GCP_REGION}-a \
      --num-nodes 2 \
      --machine-type e2-medium \
      --network $ENVIRONMENT_NAME-vpc \
      --subnetwork $ENVIRONMENT_NAME-subnet-1 \
      --enable-autoscaling \
      --min-nodes 1 \
      --max-nodes 3
    
    echo "     GKE 클러스터: $ENVIRONMENT_NAME-gke"
  else
    echo "     [DRY RUN] GKE 클러스터 생성 명령어 출력"
    echo "     gcloud container clusters create $ENVIRONMENT_NAME-gke --zone ${GCP_REGION}-a --num-nodes 2 --machine-type e2-medium --network $ENVIRONMENT_NAME-vpc --subnetwork $ENVIRONMENT_NAME-subnet-1"
  fi

  # 5. HTTP(S) 로드밸런서 생성 (Day 3 실습용)
  echo "   - HTTP(S) 로드밸런서 생성 (Day 3 실습용)..."
  if [ "$DRY_RUN" == "false" ]; then
    # 인스턴스 그룹 생성
    gcloud compute instance-groups managed create $ENVIRONMENT_NAME-mig \
      --zone ${GCP_REGION}-a \
      --template $ENVIRONMENT_NAME-template \
      --size 2
    
    # 백엔드 서비스 생성
    gcloud compute backend-services create $ENVIRONMENT_NAME-backend \
      --protocol HTTP \
      --port-name http \
      --health-checks $ENVIRONMENT_NAME-health-check \
      --global
    
    echo "     로드밸런서 구성 요소 생성 완료"
  else
    echo "     [DRY RUN] HTTP(S) 로드밸런서 생성 명령어 출력"
    echo "     gcloud compute backend-services create $ENVIRONMENT_NAME-backend --protocol HTTP --port-name http --health-checks $ENVIRONMENT_NAME-health-check --global"
  fi

else
  usage
fi

echo "✅ Cloud Master 실습 환경 배포 완료!"
echo "💡 다음 단계:"
echo "   1. 생성된 리소스 확인"
echo "   2. 실습 가이드에 따라 애플리케이션 배포"
echo "   3. 모니터링 및 비용 최적화 실습"
echo "   4. 실습 완료 후 리소스 정리"
