# 마스터 과정 자동화 시스템

## 🎯 학습 목표

### 핵심 학습 목표
- **Cloud Master 기초** 클라우드 서비스 이해 및 활용
- **Cloud Master 실무** 실제 프로젝트 적용 능력 향상

### 실습 후 달성할 수 있는 능력
- ✅ 클라우드 서비스 기본 개념 이해
- ✅ 실제 환경에서 서비스 배포 및 관리
- ✅ 문제 해결 및 최적화 능력

### 예상 소요 시간
- **기초 학습**: 90-120분
- **실습 진행**: 60-90분
- **전체 과정**: 3-4시간


## 개요
클라우드 마스터 과정의 3일간 실습을 자동화하는 시스템입니다. Docker, Git/GitHub, CI/CD, 로드 밸런싱, 모니터링, 비용 최적화 등의 실습 스크립트를 자동으로 생성합니다.

## 주요 기능
- **3일간의 실습 스크립트 자동 생성**
- **AWS/GCP 멀티클라우드 지원**
- **환경 설정 및 도구 검증**
- **포괄적인 테스트 시스템**
- **Windows/Linux/macOS 호환**

## 파일 구조
```
automation_tests/
├── master_course_automation.py      # 메인 자동화 스크립트
├── master_course_day2_scripts.py    # Day 2 스크립트 생성
├── master_course_day3_scripts.py    # Day 3 스크립트 생성
├── test_master_course_automation.py # 단위/통합 테스트
├── run_master_course_tests.py       # 테스트 실행기
└── README.md                        # 사용자 안내서
```

## 설치 및 실행

### 1. 필수 도구 설치
다음 도구들이 설치되어 있어야 합니다:
- Python 3.8+
- Docker
- Git
- GitHub CLI
- AWS CLI
- GCP CLI

### 2. 의존성 설치
```bash
pip install pytest
```

### 3. 자동화 실행
```bash
# 메인 자동화 스크립트 실행
python automation_tests/master_course_automation.py

# 테스트 실행
python automation_tests/run_master_course_tests.py
```

## 생성되는 스크립트들

### Day 1: 기초 실습
- **`docker_basics.sh`** - Docker 기초 실습
- **`git_github_basics.sh`** - Git/GitHub 기초 실습
- **`github_actions.sh`** - GitHub Actions CI/CD 파이프라인
- **`vm_deployment.sh`** - VM 기반 웹 애플리케이션 배포

### Day 2: 고급 실습
- **`docker_advanced.sh`** - Docker 고급 기법 ["멀티스테이지 빌드, 최적화"]
- **`advanced_cicd.sh`** - 고급 CI/CD 파이프라인 ["Matrix 빌드, 보안 스캔"]
- **`container_orchestration.sh`** - 컨테이너 오케스트레이션 [Docker Swarm, Kubernetes]

### Day 3: 운영 실습
- **`load_balancing.sh`** - 로드 밸런싱 및 Auto Scaling
- **`monitoring.sh`** - 모니터링 및 로깅 [Prometheus, Grafana]
- **`cost_optimization.sh`** - 비용 최적화 및 분석

## 사용법

### 1. 기본 실행
```bash
cd automation_tests
python master_course_automation.py
```

### 2. 테스트 실행
```bash
python run_master_course_tests.py
```

### 3. 개별 스크립트 실행
생성된 스크립트들은 `mcp_knowledge_base/cloud_master/automation/` 디렉토리에 저장됩니다.

```bash
# Day 1 스크립트 실행 예시
cd mcp_knowledge_base/cloud_master/automation/day1
chmod +x *.sh
./docker_basics.sh
```

## 환경 변수 설정

자동화 스크립트는 다음 환경 변수를 자동으로 설정합니다:
- `COURSE_NAME=Cloud Master Course`
- `COURSE_DURATION=3`
- `COURSE_START_TIME=09:00`
- `COURSE_END_TIME=17:00`

## 테스트 시스템

### 단위 테스트
- 설정 클래스 테스트
- 디렉토리 생성 테스트
- 환경 변수 설정 테스트
- 도구 검증 테스트

### 통합 테스트
- 전체 자동화 프로세스 테스트
- 스크립트 생성 검증
- 파일 존재 여부 확인

### 테스트 실행
```bash
# 모든 테스트 실행
python run_master_course_tests.py

# 개별 테스트 실행
pytest test_master_course_automation.py -v
```

## 문제 해결

### 1. 인코딩 문제
Windows 환경에서 한글 인코딩 문제가 발생할 수 있습니다. 모든 파일은 UTF-8로 저장되어 있습니다.

### 2. 도구 누락
일부 도구가 누락되어도 자동화는 계속 진행됩니다. 누락된 도구는 경고 메시지로 표시됩니다.

### 3. 권한 문제
생성된 스크립트 파일에 실행 권한이 필요할 수 있습니다:
```bash
chmod +x *.sh
```

## 지원되는 클라우드 플랫폼

- **AWS**: EC2, ELB, Auto Scaling Group, CloudWatch
- **GCP**: Compute Engine, Cloud LB, Managed Instance Group, Cloud Monitoring

## 라이선스
이 프로젝트는 교육 목적으로 제작되었습니다.

## 문의사항
문제가 발생하거나 개선 사항이 있으면 이슈를 등록해 주세요.

---


---



<div align="center">

["📚 전체 커리큘럼"](curriculum.md) | ["🏠 학습 경로로 돌아가기"](index.md) | ["📋 학습 경로"](learning-path.md)

</div>