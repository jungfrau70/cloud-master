#!/bin/bash

# Day1 실습 개선 스크립트
# WSL 히스토리 분석을 바탕으로 명령어 오류 수정 및 개선

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_header() { echo -e "${PURPLE}=== $1 ===${NC}"; }

# 실습 1: WSL 환경 설정
practice_wsl_setup() {
    log_header "실습 1: WSL 환경 설정"
    
    log_info "WSL 버전 확인:"
    wsl --version 2>/dev/null || log_warning "WSL 2가 설치되지 않았을 수 있습니다"
    
    log_info "현재 사용자 확인:"
    whoami
    
    log_info "현재 디렉토리 확인:"
    pwd
    
    log_info "시스템 정보 확인:"
    cat /etc/os-release 2>/dev/null || log_warning "OS 정보를 확인할 수 없습니다"
    
    log_success "WSL 환경 설정 확인 완료"
}

# 실습 2: AWS CLI 설정 및 EC2 인스턴스 생성
practice_aws_ec2() {
    log_header "실습 2: AWS EC2 인스턴스 생성"
    
    # AWS CLI 설치 확인
    log_info "AWS CLI 버전 확인:"
    aws --version 2>/dev/null || {
        log_error "AWS CLI가 설치되지 않았습니다"
        log_info "설치 방법: curl 'https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip' -o 'awscliv2.zip' && unzip awscliv2.zip && sudo ./aws/install"
        return 1
    }
    
    # AWS 계정 설정 확인
    log_info "AWS 계정 설정 확인:"
    aws sts get-caller-identity 2>/dev/null || {
        log_error "AWS 계정이 설정되지 않았습니다"
        log_info "설정 방법: aws configure"
        return 1
    }
    
    # 보안 그룹 확인
    log_info "기본 보안 그룹 확인:"
    SECURITY_GROUP=$(aws ec2 describe-security-groups \
        --filters "Name=group-name,Values=*default*" \
        --query 'SecurityGroups[0].GroupId' \
        --output text 2>/dev/null)
    
    if [ ! -z "$SECURITY_GROUP" ]; then
        log_success "보안 그룹: $SECURITY_GROUP"
    else
        log_error "기본 보안 그룹을 찾을 수 없습니다"
        return 1
    fi
    
    # EC2 인스턴스 생성
    log_info "EC2 인스턴스 생성 중..."
    INSTANCE_ID=$(aws ec2 run-instances \
        --image-id ami-077ad873396d76f6a \
        --count 1 \
        --instance-type t2.micro \
        --security-group-ids $SECURITY_GROUP \
        --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=cloud-master-day1-practice}]' \
        --query 'Instances[0].InstanceId' \
        --output text 2>/dev/null)
    
    if [ $? -eq 0 ] && [ ! -z "$INSTANCE_ID" ]; then
        log_success "EC2 인스턴스 생성됨: $INSTANCE_ID"
        
        # 인스턴스 상태 확인
        log_info "인스턴스 상태 확인 중..."
        aws ec2 wait instance-running --instance-ids $INSTANCE_ID 2>/dev/null
        log_success "인스턴스 실행 중"
        
        # Public IP 확인
        PUBLIC_IP=$(aws ec2 describe-instances \
            --instance-ids $INSTANCE_ID \
            --query 'Reservations[0].Instances[0].PublicIpAddress' \
            --output text 2>/dev/null)
        log_success "Public IP: $PUBLIC_IP"
        
        # 인스턴스 정보 저장
        echo "INSTANCE_ID=$INSTANCE_ID" > day1-aws-instance.env
        echo "PUBLIC_IP=$PUBLIC_IP" >> day1-aws-instance.env
        log_info "인스턴스 정보가 day1-aws-instance.env에 저장되었습니다"
    else
        log_error "EC2 인스턴스 생성 실패"
        return 1
    fi
}

# 실습 3: GCP CLI 설정 및 Compute 인스턴스 생성
practice_gcp_compute() {
    log_header "실습 3: GCP Compute 인스턴스 생성"
    
    # GCP CLI 설치 확인
    log_info "GCP CLI 버전 확인:"
    gcloud --version 2>/dev/null || {
        log_error "GCP CLI가 설치되지 않았습니다"
        log_info "설치 방법: curl https://sdk.cloud.google.com | bash"
        return 1
    }
    
    # GCP 계정 설정 확인
    log_info "GCP 계정 설정 확인:"
    gcloud auth list --filter=status:ACTIVE --format="value(account)" 2>/dev/null || {
        log_error "GCP 계정이 설정되지 않았습니다"
        log_info "설정 방법: gcloud auth login"
        return 1
    }
    
    # 프로젝트 설정 확인
    log_info "현재 프로젝트 확인:"
    gcloud config get-value project 2>/dev/null || {
        log_error "GCP 프로젝트가 설정되지 않았습니다"
        log_info "설정 방법: gcloud config set project YOUR_PROJECT_ID"
        return 1
    }
    
    # Compute 인스턴스 생성
    log_info "GCP Compute 인스턴스 생성 중..."
    gcloud compute instances create cloud-master-day1-practice \
        --image-family=ubuntu-2004-lts \
        --image-project=ubuntu-os-cloud \
        --machine-type=e2-micro \
        --zone=asia-northeast3-a \
        --tags=http-server \
        --boot-disk-size=10GB 2>/dev/null
    
    if [ $? -eq 0 ]; then
        log_success "GCP Compute 인스턴스 생성됨"
        
        # 인스턴스 정보 확인
        log_info "인스턴스 정보:"
        gcloud compute instances describe cloud-master-day1-practice \
            --zone=asia-northeast3-a \
            --format="table(name,status,networkInterfaces[0].accessConfigs[0].natIP)" 2>/dev/null
        
        # 인스턴스 정보 저장
        echo "INSTANCE_NAME=cloud-master-day1-practice" > day1-gcp-instance.env
        echo "ZONE=asia-northeast3-a" >> day1-gcp-instance.env
        log_info "인스턴스 정보가 day1-gcp-instance.env에 저장되었습니다"
    else
        log_error "GCP Compute 인스턴스 생성 실패"
        return 1
    fi
}

# 실습 4: Docker 기본 실습
practice_docker_basics() {
    log_header "실습 4: Docker 기본 실습"
    
    # Docker 설치 확인
    log_info "Docker 버전 확인:"
    docker --version 2>/dev/null || {
        log_error "Docker가 설치되지 않았습니다"
        log_info "설치 방법: curl -fsSL https://get.docker.com -o get-docker.sh && sh get-docker.sh"
        return 1
    }
    
    # Docker 서비스 상태 확인
    log_info "Docker 서비스 상태 확인:"
    docker ps 2>/dev/null || {
        log_error "Docker 서비스가 실행되지 않았습니다"
        log_info "시작 방법: sudo systemctl start docker"
        return 1
    }
    
    # Docker 이미지 목록
    log_info "Docker 이미지 목록:"
    docker images 2>/dev/null || log_warning "Docker 이미지가 없습니다"
    
    # 실행 중인 컨테이너
    log_info "실행 중인 컨테이너:"
    docker ps 2>/dev/null || log_warning "실행 중인 컨테이너가 없습니다"
    
    # 모든 컨테이너
    log_info "모든 컨테이너:"
    docker ps -a 2>/dev/null || log_warning "컨테이너가 없습니다"
    
    # 간단한 Docker 컨테이너 실행 테스트
    log_info "Docker 컨테이너 실행 테스트:"
    docker run --rm hello-world 2>/dev/null || {
        log_error "Docker 컨테이너 실행 테스트 실패"
        return 1
    }
    
    log_success "Docker 기본 실습 완료"
}

# 실습 5: GitHub Actions 설정
practice_github_actions() {
    log_header "실습 5: GitHub Actions 설정"
    
    # Git 설치 확인
    log_info "Git 버전 확인:"
    git --version 2>/dev/null || {
        log_error "Git이 설치되지 않았습니다"
        log_info "설치 방법: sudo apt update && sudo apt install git"
        return 1
    }
    
    # GitHub CLI 설치 확인
    log_info "GitHub CLI 버전 확인:"
    gh --version 2>/dev/null || {
        log_warning "GitHub CLI가 설치되지 않았습니다"
        log_info "설치 방법: curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg"
    }
    
    # GitHub 인증 확인
    log_info "GitHub 인증 확인:"
    gh auth status 2>/dev/null || {
        log_warning "GitHub 인증이 필요합니다"
        log_info "인증 방법: gh auth login"
    }
    
    # Git 설정 확인
    log_info "Git 설정 확인:"
    git config --global user.name 2>/dev/null || log_warning "Git 사용자 이름이 설정되지 않았습니다"
    git config --global user.email 2>/dev/null || log_warning "Git 이메일이 설정되지 않았습니다"
    
    log_success "GitHub Actions 설정 확인 완료"
}

# 실습 정리
cleanup_practice() {
    log_header "실습 정리"
    
    # AWS 인스턴스 정리
    if [ -f "day1-aws-instance.env" ]; then
        source day1-aws-instance.env
        if [ ! -z "$INSTANCE_ID" ]; then
            log_info "AWS 인스턴스 종료 중: $INSTANCE_ID"
            aws ec2 terminate-instances --instance-ids $INSTANCE_ID 2>/dev/null
            log_success "AWS 인스턴스 종료됨"
        fi
    fi
    
    # GCP 인스턴스 정리
    if [ -f "day1-gcp-instance.env" ]; then
        source day1-gcp-instance.env
        if [ ! -z "$INSTANCE_NAME" ]; then
            log_info "GCP 인스턴스 삭제 중: $INSTANCE_NAME"
            gcloud compute instances delete $INSTANCE_NAME --zone=$ZONE --quiet 2>/dev/null
            log_success "GCP 인스턴스 삭제됨"
        fi
    fi
    
    # 환경 파일 정리
    rm -f day1-aws-instance.env day1-gcp-instance.env 2>/dev/null
    
    log_success "실습 정리 완료"
}

# 메뉴 표시
show_menu() {
    echo ""
    log_info "Day1 실습 도구"
    echo "1. WSL 환경 설정"
    echo "2. AWS EC2 인스턴스 생성"
    echo "3. GCP Compute 인스턴스 생성"
    echo "4. Docker 기본 실습"
    echo "5. GitHub Actions 설정"
    echo "6. 실습 정리"
    echo "7. 전체 실습 실행"
    echo "8. 종료"
    echo ""
}

# 전체 실습 실행
run_all_practices() {
    log_header "Day1 전체 실습 실행"
    
    practice_wsl_setup
    echo ""
    practice_aws_ec2
    echo ""
    practice_gcp_compute
    echo ""
    practice_docker_basics
    echo ""
    practice_github_actions
    echo ""
    
    log_success "Day1 전체 실습 완료"
}

# 메인 실행 함수
main() {
    while true; do
        show_menu
        read -p "선택하세요 (1-8): " choice
        
        case $choice in
            1)
                practice_wsl_setup
                read -p "계속하려면 Enter를 누르세요..."
                ;;
            2)
                practice_aws_ec2
                read -p "계속하려면 Enter를 누르세요..."
                ;;
            3)
                practice_gcp_compute
                read -p "계속하려면 Enter를 누르세요..."
                ;;
            4)
                practice_docker_basics
                read -p "계속하려면 Enter를 누르세요..."
                ;;
            5)
                practice_github_actions
                read -p "계속하려면 Enter를 누르세요..."
                ;;
            6)
                cleanup_practice
                read -p "계속하려면 Enter를 누르세요..."
                ;;
            7)
                run_all_practices
                read -p "계속하려면 Enter를 누르세요..."
                ;;
            8)
                log_info "Day1 실습 도구를 종료합니다."
                exit 0
                ;;
            *)
                log_error "잘못된 선택입니다. 1-8 중에서 선택하세요."
                sleep 2
                ;;
        esac
    done
}

# 스크립트 실행
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
