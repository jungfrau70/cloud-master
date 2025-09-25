# 통합 자동화 시스템 사용 가이드

## 🚀 빠른 시작

### 1. 환경 설정
```bash
# 의존성 설치
pip install -r requirements.txt

# AWS CLI 설정
aws configure

# GCP CLI 설정
gcloud auth login
gcloud config set project YOUR_PROJECT_ID

# Docker 시작
docker --version
```

### 2. 기본 실행
```bash
# 전체 과정 실행 [Basic → Master → Container]
python run_integrated_automation.py

# 특정 과정부터 시작
python run_integrated_automation.py --start-from master

# 검증만 실행
python run_integrated_automation.py --validate-only
```

## 🔍 검증 도구 사용법

### 통합 시스템 검증
```bash
# 전체 시스템 검증
python validate_integration.py

# JSON 형식으로 결과 출력
python validate_integration.py --output-format json
```

### 과정 간 연결 검증
```bash
# 과정 간 연결성 검증
python validate_course_connections.py

# 연결성 검증 후 자동화 실행
python run_integrated_automation.py --validate-connections
```

## ⚙️ 설정 파일 관리

### 통합 설정 [integrated_config.json]
```json
{
  "total_duration_days": 7,
  "cloud_providers": ["aws", "gcp"],
  "required_tools": [
    "aws-cli", "gcloud-cli", "docker", "git", 
    "github-cli", "kubectl", "helm", "terraform"
  ],
  "environment_setup": {
    "aws_region": "us-west-2",
    "gcp_region": "us-central1",
    "project_prefix": "cloud-training",
    "shared_resources": true,
    "enable_monitoring": true,
    "enable_logging": true
  }
}
```

### 사용자 정의 설정
```bash
# 사용자 정의 설정으로 실행
python run_integrated_automation.py --config custom_config.json
```

## 🔧 과정별 실행

### Cloud Basic 과정
```bash
# Basic 과정만 실행
cd ../cloud_basic/automation_tests
python basic_course_automation.py

# Basic → Master 연계 설정
cd ../../integrated_automation
./bridge_scripts/basic_to_master_bridge.sh
```

### Cloud Master 과정
```bash
# Master 과정만 실행
cd ../cloud_master/automation_tests
source ../../integrated_automation/shared_resources/master_course_config.env
python master_course_automation.py

# Master → Container 연계 설정
cd ../../integrated_automation
./bridge_scripts/master_to_container_bridge.sh
```

### Cloud Container 과정
```bash
# Container 과정만 실행
cd ../cloud_container/automation_tests
source ../../integrated_automation/shared_resources/container_course_config.env
python container_course_automation.py
```

## 📊 모니터링 및 로그

### 실시간 모니터링
```bash
# 통합 자동화 로그
tail -f integrated_course_automation.log

# 특정 과정 로그
tail -f ../cloud_basic/automation_tests/basic_course_automation.log
tail -f ../cloud_master/automation_tests/master_course_automation.log
tail -f ../cloud_container/automation_tests/container_course_automation.log
```

### 결과 확인
```bash
# 검증 보고서 확인
ls results/validation_report_*.md
ls results/connection_validation_report_*.md

# 공유 리소스 상태 확인
cat shared_resources/shared_state.json
cat shared_resources/shared_resources.json
```

## 🛠️ 문제 해결

### 일반적인 문제

#### 1. 도구 누락
```bash
# AWS CLI 설치
pip install awscli

# GCP CLI 설치
curl https:///sdk.cloud.google.com | bash

# Docker 설치
# Windows: Docker Desktop
# macOS: Docker Desktop
# Linux: docker.io 패키지

# kubectl 설치
curl -LO "https:///dl.k8s.io/release/$[curl -L -s https:///dl.k8s.io/release/stable.txt]/bin/linux/amd64/kubectl"
```

#### 2. 권한 문제
```bash
# AWS 권한 확인
aws sts get-caller-identity

# GCP 권한 확인
gcloud auth list

# Docker 권한 확인
docker ps
```

#### 3. 네트워크 문제
```bash
# 인터넷 연결 확인
ping google.com

# AWS 연결 확인
aws s3 ls

# GCP 연결 확인
gcloud projects list
```

### 로그 분석

#### 오류 로그 확인
```bash
# 최근 오류 확인
grep -i error integrated_course_automation.log | tail -10

# 특정 과정 오류 확인
grep -i error ../cloud_basic/automation_tests/basic_course_automation.log
```

#### 성능 분석
```bash
# 실행 시간 분석
grep "completed" integrated_course_automation.log

# 리소스 사용량 확인
grep "resource" shared_resources/shared_state.json
```

## 🔄 백업 및 복구

### 백업 생성
```bash
# 전체 설정 백업
tar -czf integrated_automation_backup_$[date +%Y%m%d].tar.gz .

# 공유 리소스만 백업
tar -czf shared_resources_backup_$[date +%Y%m%d].tar.gz shared_resources/
```

### 복구
```bash
# 전체 복구
tar -xzf integrated_automation_backup_YYYYMMDD.tar.gz

# 특정 과정만 복구
python run_integrated_automation.py --start-from basic
```

## 📈 성능 최적화

### 병렬 실행
```bash
# 독립적인 과정 병렬 실행
python run_integrated_automation.py --parallel

# 리소스 생성 배치 처리
python run_integrated_automation.py --batch-size 10
```

### 캐싱 활용
```bash
# 생성된 스크립트 캐싱
python run_integrated_automation.py --enable-cache

# 공유 리소스 상태 캐싱
python run_integrated_automation.py --cache-resources
```

## 🤝 기여하기

### 새로운 과정 추가
1. `integrated_course_automation.py`의 `courses` 딕셔너리 업데이트
2. 새로운 브리지 스크립트 생성
3. 공유 리소스 타입 추가
4. 테스트 케이스 추가

### 공유 리소스 확장
1. `shared_resource_manager.py`에 새로운 리소스 타입 추가
2. 브리지 스크립트 업데이트
3. 설정 파일 확장

### 테스트 케이스 추가
1. `test_integrated_automation.py`에 새로운 테스트 추가
2. 모의 객체[Mock] 활용
3. 통합 테스트 시나리오 작성

## 📞 지원 및 문의

### 문제 신고
- GitHub Issues 사용
- 상세한 로그와 함께 신고
- 재현 단계 명시

### 문서 참조
- 각 과정별 README.md
- 통합 자동화 시스템 README.md
- 검증 보고서

### 커뮤니티
- 클라우드 학습 커뮤니티 참여
- 기술 블로그 및 포럼
- 정기 워크샵 참석

---

**🎉 통합 자동화 시스템으로 효율적인 클라우드 학습을 시작하세요!**


---



---



---



---

<div align="center">

 현재 위치
**통합 자동화**

## 🔗 관련 과정
["Cloud Basic 1일차"][README.md] | ["Cloud Master 1일차"][README.md] | ["Cloud Container 1일차"][README.md]

</div>

---

<div align="center">

["🏠 홈"][index.md] | ["📚 전체 커리큘럼"][curriculum.md] | ["🔗 학습 경로"][learning-path.md]

</div>
