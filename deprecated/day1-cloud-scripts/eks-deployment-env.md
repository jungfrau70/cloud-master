## 🛠️ 작업 환경 및 기초 명령어 정리

### **현재 작업 환경**
- **OS**: Windows 11 + WSL2 [Ubuntu]
- **사용자**: `jih`
- **호스트명**: `DESKTOP-0TCBR9U`
- **리눅스 커널**: `5.15.153.1-microsoft-standard-WSL2`
- **아키텍처**: `x86_64`

### **프로젝트 구조**
```
C:\Users\JIH\githubs\mcp_cloud\                    # Windows 경로
└── mcp_knowledge_base\
    └── cloud_master\
        └── repos\
            └── cloud-scripts\                     # 현재 작업 디렉토리
                ├── k8s-cluster-create.sh          # GCP GKE 클러스터 생성
                ├── eks-cluster-create.sh          # AWS EKS 클러스터 생성
                ├── cleanup-all-clusters.sh        # 통합 클러스터 정리
                ├── cleanup-vpcs.sh                # VPC 정리
                ├── diagnose-vpc.sh                # VPC 진단
                └── README.md                      # 사용 가이드
```

### **WSL 환경 명령어**

#### **기본 네비게이션**
```bash
# 현재 위치 확인
pwd

# 디렉토리 이동
cd /path/to/directory

# 상위 디렉토리로 이동
cd ..

# 홈 디렉토리로 이동
cd ~

# 이전 디렉토리로 이동
cd -
```

#### **파일 및 디렉토리 관리**
```bash
# 파일 목록 보기
ls -la

# 디렉토리 생성
mkdir directory_name

# 파일 생성
touch filename

# 파일 복사
cp source destination

# 파일 이동/이름 변경
mv source destination

# 파일 삭제
rm filename

# 디렉토리 삭제
rm -rf directory_name
```

#### **텍스트 편집**
```bash
# nano 편집기
nano filename

# vim 편집기
vim filename

# 파일 내용 보기
cat filename

# 파일 내용 페이지별로 보기
less filename

# 파일 상위 10줄 보기
head filename

# 파일 하위 10줄 보기
tail filename
```

### **클라우드 명령어**

#### **AWS CLI**
```bash
# AWS 계정 정보 확인
aws sts get-caller-identity

# 리전 설정
aws configure set region ap-northeast-2

# EKS 클러스터 목록
eksctl get cluster --region ap-northeast-2

# kubectl context 설정
aws eks update-kubeconfig --region ap-northeast-2 --name cluster-name

# VPC 목록
aws ec2 describe-vpcs --query 'Vpcs[*].[VpcId,Tags[?Key==`Name`].Value|[0],CidrBlock]' --output table
```

#### **GCP CLI**
```bash
# GCP 계정 정보 확인
gcloud auth list

# 프로젝트 설정
gcloud config set project PROJECT_ID

# GKE 클러스터 목록
gcloud container clusters list

# kubectl context 설정
gcloud container clusters get-credentials CLUSTER_NAME --zone ZONE
```

#### **Kubernetes [kubectl]**
```bash
# 노드 상태 확인
kubectl get nodes

# 파드 목록
kubectl get pods -A

# 서비스 목록
kubectl get services

# 네임스페이스 목록
kubectl get namespaces

# 클러스터 정보
kubectl cluster-info

# 리소스 상세 정보
kubectl describe node NODE_NAME
kubectl describe pod POD_NAME
```

### **스크립트 실행**

#### **실행 권한 부여**
```bash
# 실행 권한 부여
chmod +x script_name.sh

# 모든 .sh 파일에 실행 권한 부여
chmod +x *.sh
```

#### **스크립트 실행**
```bash
# 스크립트 실행
./script_name.sh

# 백그라운드 실행
nohup ./script_name.sh &

# 로그와 함께 실행
./script_name.sh 2>&1 | tee output.log
```

### **환경 변수 및 설정**

#### **환경 변수 확인**
```bash
# 모든 환경 변수
env

# 특정 환경 변수
echo $VARIABLE_NAME

# PATH 확인
echo $PATH
```

#### **AWS 설정**
```bash
# AWS 자격 증명 확인
aws configure list

# AWS 프로필 설정
export AWS_PROFILE=profile_name

# AWS 리전 설정
export AWS_DEFAULT_REGION=ap-northeast-2
```

### **네트워크 및 연결**

#### **네트워크 상태 확인**
```bash
# 네트워크 인터페이스 확인
ip addr show

# 라우팅 테이블
ip route show

# DNS 설정 확인
cat /etc/resolv.conf

# 포트 사용 확인
netstat -tulpn
```

#### **원격 연결**
```bash
# SSH 연결
ssh user@hostname

# SCP 파일 전송
scp file user@hostname:/path/

# rsync 동기화
rsync -avz source/ user@hostname:/destination/
```

### **프로세스 관리**

#### **프로세스 확인 및 관리**
```bash
# 실행 중인 프로세스
ps aux

# 실시간 프로세스 모니터링
top

# 프로세스 종료
kill PID

# 강제 종료
kill -9 PID

# 백그라운드 작업
jobs

# 백그라운드 작업을 포그라운드로
fg %job_number
```

### **로그 및 모니터링**

#### **시스템 로그**
```bash
# 시스템 로그 확인
sudo journalctl -f

# 특정 서비스 로그
sudo journalctl -u service_name

# 로그 파일 확인
sudo tail -f /var/log/syslog
```

#### **리소스 사용량**
```bash
# 메모리 사용량
free -h

# 디스크 사용량
df -h

# CPU 사용량
htop
```

### **유용한 단축키**
```bash
# 명령어 히스토리
history

# 이전 명령어 실행
!!

# 마지막 명령어의 인수 사용
!$

# 명령어 검색
Ctrl + R

# 명령어 자동완성
Tab

# 명령어 중단
Ctrl + C

# 화면 정리
clear
```

### **현재 프로젝트 관련 명령어**

#### **클러스터 관리**
```bash
# EKS 클러스터 생성
./eks-cluster-create.sh

# GKE 클러스터 생성
./k8s-cluster-create.sh

# 모든 클러스터 정리
./cleanup-all-clusters.sh

# VPC 정리
./cleanup-vpcs.sh
```

#### **상태 확인**
```bash
# EKS 클러스터 상태
eksctl get cluster --region ap-northeast-2

# GKE 클러스터 상태
gcloud container clusters list

# Kubernetes 노드 상태
kubectl get nodes
```

kubectl config get-contexts
CURRENT   NAME                                                                       CLUSTER                                                          
          AUTHINFO                                                                   NAMESPACE
*         arn:aws:eks:ap-northeast-2:032068930526:cluster/cloud-master-eks-cluster   arn:aws:eks:ap-northeast-2:032068930526:cluster/cloud-master-eks-cluster   arn:aws:eks:ap-northeast-2:032068930526:cluster/cloud-master-eks-cluster
          gke_cloud-deployment-471606_asia-northeast3-a_cloud-master-cluster         gke_cloud-deployment-471606_asia-northeast3-a_cloud-master-cluster         gke_cloud-deployment-471606_asia-northeast3-a_cloud-master-cluster
jih@DESKTOP-0TCBR9U:~/mcp-cloud-workspace/mcp_knowledge_base/cloud_master/repos/cloud-scripts$ 


wsl kubectl config use-context gke_cloud-deployment-471606_asia-northeast3-a_cloud-master-cluster