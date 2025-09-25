#!/bin/bash

# Cloud Master 통합 Helper 스크립트
# WSL 히스토리 분석을 바탕으로 개선된 Interactive 스크립트

# 오류 처리 설정
set -e  # 오류 발생 시 스크립트 종료
set -u  # 정의되지 않은 변수 사용 시 오류
set -o pipefail  # 파이프라인에서 오류 발생 시 종료

# 스크립트 종료 시 정리 함수
cleanup() {
    echo "스크립트가 종료됩니다. 정리 작업을 수행합니다..."
    # 필요한 정리 작업 추가
}

# 신호 트랩 설정
trap cleanup EXIT INT TERM

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 로그 함수들
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_header() { echo -e "${PURPLE}=== $1 ===${NC}"; }

# 진행 상태 표시
show_progress() {
    local current=$1
    local total=$2
    local description=$3
    local percent=$((current * 100 / total))
    printf "\r${CYAN}[%d/%d] %s... %d%%${NC}" "$current" "$total" "$description" "$percent"
}

# 환경 체크 함수
check_environment() {
    log_header "환경 체크"
    
    local checks=0
    local total_checks=6
    
    # AWS CLI 체크
    show_progress 1 $total_checks "AWS CLI 체크"
    if command -v aws &> /dev/null; then
        if aws sts get-caller-identity &> /dev/null; then
            log_success "✅ AWS CLI 설정됨"
        else
            log_warning "⚠️ AWS CLI 설치됨, 계정 설정 필요"
        fi
    else
        log_error "❌ AWS CLI 설치 필요"
    fi
    ((checks++))
    
    # GCP CLI 체크
    show_progress 2 $total_checks "GCP CLI 체크"
    if command -v gcloud &> /dev/null; then
        if gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q .; then
            log_success "✅ GCP CLI 설정됨"
        else
            log_warning "⚠️ GCP CLI 설치됨, 계정 설정 필요"
        fi
    else
        log_error "❌ GCP CLI 설치 필요"
    fi
    ((checks++))
    
    # Docker 체크
    show_progress 3 $total_checks "Docker 체크"
    if command -v docker &> /dev/null; then
        if docker ps &> /dev/null; then
            log_success "✅ Docker 실행 중"
        else
            log_warning "⚠️ Docker 설치됨, 서비스 시작 필요"
        fi
    else
        log_error "❌ Docker 설치 필요"
    fi
    ((checks++))
    
    # Git 체크
    show_progress 4 $total_checks "Git 체크"
    if command -v git &> /dev/null; then
        log_success "✅ Git 설치됨"
    else
        log_error "❌ Git 설치 필요"
    fi
    ((checks++))
    
    # jq 체크
    show_progress 5 $total_checks "jq 체크"
    if command -v jq &> /dev/null; then
        log_success "✅ jq 설치됨"
    else
        log_warning "⚠️ jq 설치 권장 (JSON 처리용)"
    fi
    ((checks++))
    
    # GitHub CLI 체크
    show_progress 6 $total_checks "GitHub CLI 체크"
    if command -v gh &> /dev/null; then
        if gh auth status &> /dev/null; then
            log_success "✅ GitHub CLI 설정됨"
        else
            log_warning "⚠️ GitHub CLI 설치됨, 인증 필요"
        fi
    else
        log_warning "⚠️ GitHub CLI 설치 권장"
    fi
    
    echo ""
    log_info "환경 체크 완료"
}

# AWS 리소스 상태 확인
check_aws_resources() {
    log_header "AWS 리소스 상태"
    
    # 실행 중인 EC2 인스턴스
    log_info "실행 중인 EC2 인스턴스:"
    aws ec2 describe-instances \
        --filters "Name=instance-state-name,Values=running" \
        --query 'Reservations[*].Instances[*].[InstanceId,Tags[?Key==`Name`].Value|[0],PublicIpAddress,PrivateIpAddress]' \
        --output table 2>/dev/null || log_warning "AWS 리소스 조회 실패"
    
    # 로드 밸런서
    log_info "로드 밸런서:"
    aws elbv2 describe-load-balancers \
        --query 'LoadBalancers[*].[LoadBalancerName,DNSName,State]' \
        --output table 2>/dev/null || log_warning "로드 밸런서 조회 실패"
    
    # Auto Scaling 그룹
    log_info "Auto Scaling 그룹:"
    aws autoscaling describe-auto-scaling-groups \
        --query 'AutoScalingGroups[*].[AutoScalingGroupName,DesiredCapacity,MinSize,MaxSize]' \
        --output table 2>/dev/null || log_warning "Auto Scaling 그룹 조회 실패"
}

# GCP 리소스 상태 확인
check_gcp_resources() {
    log_header "GCP 리소스 상태"
    
    # 실행 중인 인스턴스
    log_info "실행 중인 인스턴스:"
    gcloud compute instances list \
        --format="table(name,zone,status,EXTERNAL_IP,INTERNAL_IP)" 2>/dev/null || log_warning "GCP 리소스 조회 실패"
    
    # 로드 밸런서
    log_info "로드 밸런서:"
    gcloud compute forwarding-rules list \
        --format="table(name,region,IPAddress,target)" 2>/dev/null || log_warning "로드 밸런서 조회 실패"
}

# Docker 컨테이너 상태 확인
check_docker_status() {
    log_header "Docker 컨테이너 상태"
    
    log_info "실행 중인 컨테이너:"
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null || log_warning "Docker 상태 조회 실패"
    
    log_info "모든 컨테이너:"
    docker ps -a --format "table {{.Names}}\t{{.Status}}\t{{.CreatedAt}}" 2>/dev/null || log_warning "Docker 컨테이너 조회 실패"
}

# 메인 메뉴
show_main_menu() {
    clear
    log_header "Cloud Master Helper"
    echo "1. 환경 체크"
    echo "2. AWS 리소스 상태 확인"
    echo "3. GCP 리소스 상태 확인"
    echo "4. Docker 상태 확인"
    echo "5. 전체 상태 확인"
    echo "6. Day1 실습 도구"
    echo "7. Day2 실습 도구"
    echo "8. Day3 실습 도구"
    echo "9. 종료"
    echo ""
}

# Day1 실습 도구 메뉴
show_day1_menu() {
    clear
    log_header "Day1 실습 도구"
    echo "1. WSL 환경 설정"
    echo "2. AWS EC2 인스턴스 생성"
    echo "3. GCP Compute 인스턴스 생성"
    echo "4. Docker 기본 실습"
    echo "5. GitHub Actions 설정"
    echo "6. 뒤로 가기"
    echo ""
}

# Day2 실습 도구 메뉴
show_day2_menu() {
    clear
    log_header "Day2 실습 도구"
    echo "1. Docker Compose 실습"
    echo "2. Kubernetes 기본 실습"
    echo "3. CI/CD 파이프라인 설정"
    echo "4. 컨테이너 오케스트레이션"
    echo "5. 뒤로 가기"
    echo ""
}

# Day3 실습 도구 메뉴
show_day3_menu() {
    clear
    log_header "Day3 실습 도구"
    echo "1. AWS 로드 밸런싱"
    echo "2. GCP 로드 밸런싱"
    echo "3. 모니터링 스택 설정"
    echo "4. Auto Scaling 설정"
    echo "5. 비용 최적화"
    echo "6. 통합 테스트"
    echo "7. 뒤로 가기"
    echo ""
}

# AWS EC2 인스턴스 생성 (WSL 히스토리 기반 개선)
create_aws_ec2() {
    log_header "AWS EC2 인스턴스 생성"
    
    # 보안 그룹 확인
    log_info "기존 보안 그룹 확인 중..."
    aws ec2 describe-security-groups \
        --filters "Name=group-name,Values=*default*" \
        --query 'SecurityGroups[0].GroupId' \
        --output text 2>/dev/null
    
    if [ $? -eq 0 ]; then
        SECURITY_GROUP=$(aws ec2 describe-security-groups \
            --filters "Name=group-name,Values=*default*" \
            --query 'SecurityGroups[0].GroupId' \
            --output text)
        log_success "보안 그룹: $SECURITY_GROUP"
    else
        log_error "보안 그룹을 찾을 수 없습니다"
        return 1
    fi
    
    # 인스턴스 생성
    log_info "EC2 인스턴스 생성 중..."
    INSTANCE_ID=$(aws ec2 run-instances \
        --image-id ami-077ad873396d76f6a \
        --count 1 \
        --instance-type t2.micro \
        --security-group-ids $SECURITY_GROUP \
        --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=cloud-master-practice}]' \
        --query 'Instances[0].InstanceId' \
        --output text)
    
    if [ $? -eq 0 ]; then
        log_success "인스턴스 생성됨: $INSTANCE_ID"
        
        # 인스턴스 상태 확인
        log_info "인스턴스 상태 확인 중..."
        aws ec2 wait instance-running --instance-ids $INSTANCE_ID
        log_success "인스턴스 실행 중"
        
        # Public IP 확인
        PUBLIC_IP=$(aws ec2 describe-instances \
            --instance-ids $INSTANCE_ID \
            --query 'Reservations[0].Instances[0].PublicIpAddress' \
            --output text)
        log_success "Public IP: $PUBLIC_IP"
    else
        log_error "인스턴스 생성 실패"
        return 1
    fi
}

# GCP Compute 인스턴스 생성 (WSL 히스토리 기반 개선)
create_gcp_compute() {
    log_header "GCP Compute 인스턴스 생성"
    
    log_info "GCP 인스턴스 생성 중..."
    gcloud compute instances create cloud-master-practice \
        --image-family=ubuntu-2004-lts \
        --image-project=ubuntu-os-cloud \
        --machine-type=e2-micro \
        --zone=asia-northeast3-a \
        --tags=http-server \
        --boot-disk-size=10GB
    
    if [ $? -eq 0 ]; then
        log_success "GCP 인스턴스 생성됨"
        
        # 인스턴스 정보 확인
        log_info "인스턴스 정보:"
        gcloud compute instances describe cloud-master-practice \
            --zone=asia-northeast3-a \
            --format="table(name,status,networkInterfaces[0].accessConfigs[0].natIP)"
    else
        log_error "GCP 인스턴스 생성 실패"
        return 1
    fi
}

# Docker 기본 실습
docker_basics() {
    log_header "Docker 기본 실습"
    
    log_info "Docker 버전 확인:"
    docker --version
    
    log_info "Docker 이미지 목록:"
    docker images
    
    log_info "실행 중인 컨테이너:"
    docker ps
    
    log_info "모든 컨테이너:"
    docker ps -a
}

# 전체 상태 확인
check_all_status() {
    log_header "전체 상태 확인"
    
    check_environment
    echo ""
    check_aws_resources
    echo ""
    check_gcp_resources
    echo ""
    check_docker_status
}

# 메인 실행 함수
main() {
    while true; do
        show_main_menu
        read -p "선택하세요 (1-9): " choice
        
        case $choice in
            1)
                check_environment
                read -p "계속하려면 Enter를 누르세요..."
                ;;
            2)
                check_aws_resources
                read -p "계속하려면 Enter를 누르세요..."
                ;;
            3)
                check_gcp_resources
                read -p "계속하려면 Enter를 누르세요..."
                ;;
            4)
                check_docker_status
                read -p "계속하려면 Enter를 누르세요..."
                ;;
            5)
                check_all_status
                read -p "계속하려면 Enter를 누르세요..."
                ;;
            6)
                day1_menu
                ;;
            7)
                day2_menu
                ;;
            8)
                day3_menu
                ;;
            9)
                log_info "Cloud Master Helper를 종료합니다."
                exit 0
                ;;
            *)
                log_error "잘못된 선택입니다. 1-9 중에서 선택하세요."
                sleep 2
                ;;
        esac
    done
}

# Day1 메뉴 처리
day1_menu() {
    while true; do
        show_day1_menu
        read -p "선택하세요 (1-6): " choice
        
        case $choice in
            1)
                log_info "WSL 환경 설정 도구 실행..."
                # WSL 환경 설정 로직
                read -p "계속하려면 Enter를 누르세요..."
                ;;
            2)
                create_aws_ec2
                read -p "계속하려면 Enter를 누르세요..."
                ;;
            3)
                create_gcp_compute
                read -p "계속하려면 Enter를 누르세요..."
                ;;
            4)
                docker_basics
                read -p "계속하려면 Enter를 누르세요..."
                ;;
            5)
                log_info "GitHub Actions 설정 도구 실행..."
                # GitHub Actions 설정 로직
                read -p "계속하려면 Enter를 누르세요..."
                ;;
            6)
                break
                ;;
            *)
                log_error "잘못된 선택입니다. 1-6 중에서 선택하세요."
                sleep 2
                ;;
        esac
    done
}

# Day2 메뉴 처리
day2_menu() {
    while true; do
        show_day2_menu
        read -p "선택하세요 (1-5): " choice
        
        case $choice in
            1)
                log_info "Docker Compose 실습 도구 실행..."
                # Docker Compose 실습 로직
                read -p "계속하려면 Enter를 누르세요..."
                ;;
            2)
                log_info "Kubernetes 기본 실습 도구 실행..."
                # Kubernetes 실습 로직
                read -p "계속하려면 Enter를 누르세요..."
                ;;
            3)
                log_info "CI/CD 파이프라인 설정 도구 실행..."
                # CI/CD 설정 로직
                read -p "계속하려면 Enter를 누르세요..."
                ;;
            4)
                log_info "컨테이너 오케스트레이션 도구 실행..."
                # 오케스트레이션 로직
                read -p "계속하려면 Enter를 누르세요..."
                ;;
            5)
                break
                ;;
            *)
                log_error "잘못된 선택입니다. 1-5 중에서 선택하세요."
                sleep 2
                ;;
        esac
    done
}

# Day3 메뉴 처리
day3_menu() {
    while true; do
        show_day3_menu
        read -p "선택하세요 (1-7): " choice
        
        case $choice in
            1)
                log_info "AWS 로드 밸런싱 도구 실행..."
                # AWS 로드 밸런싱 로직
                read -p "계속하려면 Enter를 누르세요..."
                ;;
            2)
                log_info "GCP 로드 밸런싱 도구 실행..."
                # GCP 로드 밸런싱 로직
                read -p "계속하려면 Enter를 누르세요..."
                ;;
            3)
                log_info "모니터링 스택 설정 도구 실행..."
                # 모니터링 설정 로직
                read -p "계속하려면 Enter를 누르세요..."
                ;;
            4)
                log_info "Auto Scaling 설정 도구 실행..."
                # Auto Scaling 설정 로직
                read -p "계속하려면 Enter를 누르세요..."
                ;;
            5)
                log_info "비용 최적화 도구 실행..."
                # 비용 최적화 로직
                read -p "계속하려면 Enter를 누르세요..."
                ;;
            6)
                log_info "통합 테스트 도구 실행..."
                # 통합 테스트 로직
                read -p "계속하려면 Enter를 누르세요..."
                ;;
            7)
                break
                ;;
            *)
                log_error "잘못된 선택입니다. 1-7 중에서 선택하세요."
                sleep 2
                ;;
        esac
    done
}

# 스크립트 실행
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
