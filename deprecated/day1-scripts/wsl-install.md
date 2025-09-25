# WSL 설치 및 기본 설정 가이드

WSL[Windows Subsystem for Linux]는 Windows에서 리눅스 환경을 실행할 수 있게 해주는 도구입니다. 이 가이드에서는 WSL을 설치하고 기본 설정을 완료하는 방법을 단계별로 설명합니다.

## 📋 목차

- ["WSL 설치 및 기본 설정 가이드"]["#wsl-설치-및-기본-설정-가이드"]
  - ["📋 목차"]["#-목차"]
  - ["1. WSL 설치"]["#1-wsl-설치"]
    - ["1.1 Windows 기능 켜기"]["#11-windows-기능-켜기"]
    - ["1.2 Windows 버전 확인"]["#12-windows-버전-확인"]
    - ["1.3 WSL 2 설치 및 설정"]["#13-wsl-2-설치-및-설정"]
    - ["1.4 Linux 배포판 설치"]["#14-linux-배포판-설치"]
      - ["방법 1: Microsoft Store를 통한 설치"]["#방법-1-microsoft-store를-통한-설치"]
      - ["방법 2: 명령어를 통한 설치"]["#방법-2-명령어를-통한-설치"]
      - ["방법 3: 한 번에 WSL과 Ubuntu 설치"]["#방법-3-한-번에-wsl과-ubuntu-설치"]
    - ["1.5 리눅스 배포판 초기화"]["#15-리눅스-배포판-초기화"]
      - ["초기 사용자 계정 설정"]["#초기-사용자-계정-설정"]
      - ["Root 암호 설정"]["#root-암호-설정"]
      - ["Root 사용자로 직접 로그인"]["#root-사용자로-직접-로그인"]
      - ["Root 암호 확인 및 변경"]["#root-암호-확인-및-변경"]
  - ["2. WSL 실행 방법"]["#2-wsl-실행-방법"]
    - ["2.1 시작 메뉴에서 실행"]["#21-시작-메뉴에서-실행"]
    - ["2.2 명령어로 실행"]["#22-명령어로-실행"]
    - ["2.3 Windows Terminal에서 실행"]["#23-windows-terminal에서-실행"]
    - ["2.4 VS Code에서 실행"]["#24-vs-code에서-실행"]
  - ["3. WSL 구성"]["#3-wsl-구성"]
    - ["3.1 기본 배포판 변경"]["#31-기본-배포판-변경"]
    - ["3.2 WSL 2 사용 여부 확인"]["#32-wsl-2-사용-여부-확인"]
    - ["3.3 파일 시스템 간 접근"]["#33-파일-시스템-간-접근"]
  - ["4. Cloud Master 환경 설정"]["#4-cloud-master-환경-설정"]
    - ["4.1 필수 도구 설치"]["#41-필수-도구-설치"]
      - ["자동 설치 스크립트 실행"]["#자동-설치-스크립트-실행"]
      - ["설치 후 확인"]["#설치-후-확인"]
    - ["4.2 환경 설정 확인"]["#42-환경-설정-확인"]
      - ["환경 변수 확인"]["#환경-변수-확인"]
      - ["작업 디렉토리 확인"]["#작업-디렉토리-확인"]
  - ["5. 문제 해결"]["#5-문제-해결"]
    - ["5.1 일반적인 문제들"]["#51-일반적인-문제들"]
      - ["WSL이 시작되지 않는 경우"]["#wsl이-시작되지-않는-경우"]
      - ["배포판이 보이지 않는 경우"]["#배포판이-보이지-않는-경우"]
      - ["권한 문제가 발생하는 경우"]["#권한-문제가-발생하는-경우"]
    - ["5.2 Docker 관련 문제"]["#52-docker-관련-문제"]
      - ["Docker Desktop WSL2 통합"]["#docker-desktop-wsl2-통합"]
      - ["WSL에서 Docker Engine 사용"]["#wsl에서-docker-engine-사용"]
    - ["5.3 성능 최적화"]["#53-성능-최적화"]
      - ["WSL 2 메모리 제한 설정"]["#wsl-2-메모리-제한-설정"]
      - ["Windows Defender 예외 추가"]["#windows-defender-예외-추가"]
  - ["📚 다음 단계"]["#-다음-단계"]
  - ["🔗 관련 문서"]["#-관련-문서"]

---

## 1. WSL 설치

### 1.1 Windows 기능 켜기

1. 시작 메뉴에서 **"Windows 기능 켜기/끄기"**를 검색하여 엽니다.
2. 목록에서 다음 두 기능을 체크합니다:
   - **"Windows Subsystem for Linux"**
   - **"가상 머신 플랫폼"** [Virtual Machine Platform]
3. **"확인"**을 클릭한 후, 시스템이 요구하는 경우 재부팅합니다.

> **💡 참고**: 이 두 기능은 WSL2를 사용하기 위해 필수입니다.

### 1.2 Windows 버전 확인

- **Windows 11**: WSL2가 기본적으로 지원되며, 별도 설치가 필요하지 않습니다.
- **Windows 10**: 버전 1903 이상에서 WSL2를 지원하므로, 시스템 업데이트가 필요한 경우 최신 버전으로 업데이트합니다.

Windows 버전 확인 방법:
```cmd
winver
```

### 1.3 WSL 2 설치 및 설정

PowerShell을 **관리자 권한**으로 실행하고 다음 명령어를 입력합니다:

```powershell
# WSL 도움말 확인
wsl --help

# WSL 버전 확인
wsl -v

# WSL2를 기본 버전으로 설정
wsl --set-default-version 2
```

### 1.4 Linux 배포판 설치

#### 방법 1: Microsoft Store를 통한 설치
1. Microsoft Store를 열고 원하는 리눅스 배포판을 검색합니다.
2. 지원되는 배포판: **Ubuntu**, **Debian**, **Kali Linux** 등
3. 배포판을 선택하고 **"설치"** 버튼을 클릭합니다.

#### 방법 2: 명령어를 통한 설치
PowerShell을 **관리자 권한**으로 실행하고 다음 명령어를 사용합니다:

```powershell
# 사용 가능한 배포판 목록 확인
wsl --list --online

# Ubuntu 설치 ["가장 인기 있는 배포판"]
wsl --install -d Ubuntu

# 특정 배포판 설치
wsl --install -d Ubuntu-22.04
wsl --install -d Debian
wsl --install -d kali-linux
```

#### 방법 3: 한 번에 WSL과 Ubuntu 설치
```powershell
# WSL과 기본 Ubuntu를 한 번에 설치
wsl --install
```

### 1.5 리눅스 배포판 초기화

#### 초기 사용자 계정 설정
1. 설치가 완료되면 **시작 메뉴**에서 설치한 배포판을 실행합니다.
2. 첫 실행 시 사용자명과 비밀번호를 입력하라는 프롬프트가 나타납니다.
3. 이 사용자는 sudo 권한을 가진 일반 사용자입니다.
4. **중요**: 이 사용자는 root가 아닙니다!

#### Root 암호 설정
```bash
# WSL에서 root 사용자로 전환
sudo su -

# root 암호 설정
passwd

# 또는 현재 사용자에서 root 암호 설정
sudo passwd root
```

#### Root 사용자로 직접 로그인
```powershell
# PowerShell에서 root로 WSL 실행
wsl -u root

# 특정 배포판의 root로 실행
wsl -d Ubuntu -u root
```

#### Root 암호 확인 및 변경
```bash
# root 암호 상태 확인
sudo passwd -S root

# root 암호 변경
sudo passwd root
```

---

## 2. WSL 실행 방법

### 2.1 시작 메뉴에서 실행
- Windows 시작 메뉴에서 설치한 배포판 이름을 검색하여 실행
- 예: "Ubuntu", "Debian", "Kali Linux" 등

### 2.2 명령어로 실행
```powershell
# 기본 배포판 실행
wsl

# 특정 배포판 실행
wsl -d Ubuntu
wsl -d Debian
wsl -d kali-linux

# 배포판 목록 확인
wsl --list --verbose
```

### 2.3 Windows Terminal에서 실행
- Windows Terminal을 설치하면 탭으로 여러 배포판을 동시에 실행 가능
- 각 탭에서 다른 Linux 배포판 사용 가능

### 2.4 VS Code에서 실행
1. VS Code에서 `Ctrl + Shift + P`를 누릅니다.
2. "WSL: Connect to WSL"을 선택합니다.
3. WSL 환경에서 직접 코드 편집 및 실행이 가능합니다.

---

## 3. WSL 구성

### 3.1 기본 배포판 변경
여러 개의 배포판을 설치한 경우, 기본 배포판을 변경할 수 있습니다:

```powershell
wsl --setdefault <배포판 이름>
```

### 3.2 WSL 2 사용 여부 확인
WSL 2로 잘 설정되었는지 확인하려면 다음 명령어를 입력합니다:

```powershell
wsl --list --verbose
```

이 명령어는 각 배포판의 버전["WSL 1 또는 WSL 2"]을 보여줍니다.

### 3.3 파일 시스템 간 접근
- **WSL에서 Windows 파일 시스템 접근**: `/mnt/c/`, `/mnt/d/`와 같은 경로로 접근 가능
- **Windows에서 WSL 파일 시스템 접근**: `\\wsl$`를 통해 Windows 탐색기에서 접근 가능

---

## 4. Cloud Master 환경 설정

### 4.1 필수 도구 설치

WSL 설치가 완료되면 Cloud Master 과정을 위한 필수 도구들을 설치해야 합니다.

#### 자동 설치 스크립트 실행
```bash
# WSL 환경에서 실행
cd /mnt/c/Users/JIH/githubs/mcp_cloud/mcp_knowledge_base/cloud_master/repos/install
chmod +x install-all-wsl.sh
./install-all-wsl.sh
```

이 스크립트는 다음 도구들을 자동으로 설치합니다:
- **AWS CLI v2**: AWS 서비스 관리
- **GCP CLI**: Google Cloud 서비스 관리
- **Docker**: 컨테이너 실행 환경
- **Kubernetes [kubectl]**: 쿠버네티스 클러스터 관리
- **Terraform**: 인프라 자동화
- **Node.js**: JavaScript 런타임
- **Python 3**: Python 개발 환경
- **Helm**: 쿠버네티스 패키지 관리자

#### 설치 후 확인
```bash
# 설치된 도구들 버전 확인
aws --version
gcloud --version
docker --version
kubectl version --client
terraform --version
node --version
python3 --version
helm version --short
```

### 4.2 환경 설정 확인

#### 환경 변수 확인
```bash
# MCP Cloud 환경 변수 확인
echo $MCP_CLOUD_HOME
echo $MCP_KNOWLEDGE_BASE

# PATH 확인
echo $PATH
```

#### 작업 디렉토리 확인
```bash
# 작업 디렉토리로 이동
cd ~/mcp-cloud-workspace

# MCP Knowledge Base 링크 확인
ls -la ~/mcp_knowledge_base
```

---

## 5. 문제 해결

### 5.1 일반적인 문제들

#### WSL이 시작되지 않는 경우
```powershell
# WSL 서비스 재시작
wsl --shutdown
wsl
```

#### 배포판이 보이지 않는 경우
```powershell
# 설치된 배포판 목록 확인
wsl --list --all

# 특정 배포판 등록
wsl --import <배포판 이름> <경로> <파일>
```

#### 권한 문제가 발생하는 경우
```bash
# 사용자 권한 확인
whoami
groups

# sudo 권한 확인
sudo -l
```

### 5.2 Docker 관련 문제

#### Docker Desktop WSL2 통합
1. Docker Desktop 실행
2. Settings → Resources → WSL Integration
3. 'Enable integration with my default WSL distro' 체크
4. 현재 WSL 배포판 활성화
5. Docker Desktop 재시작

#### WSL에서 Docker Engine 사용
```bash
# Docker 시작 스크립트 사용
start-docker

# 또는 수동으로 시작
sudo dockerd &

# Docker 그룹에 사용자 추가
sudo usermod -aG docker $USER
newgrp docker
```

### 5.3 성능 최적화

#### WSL 2 메모리 제한 설정
`%USERPROFILE%\.wslconfig` 파일을 생성하고 다음 내용을 추가:

```ini
[wsl2]
memory=4GB
processors=2
```

#### Windows Defender 예외 추가
WSL 디렉토리를 Windows Defender 실시간 보호에서 제외하여 성능을 향상시킬 수 있습니다.

---

## 📚 다음 단계

WSL 설치 및 기본 설정이 완료되면 다음 단계를 진행하세요:

1. **고급 WSL 설정**: `wsl-setup-guide.md` 참조
2. **Cloud Master 실습 시작**: `execuise-guide.md` 참조
3. **AWS/GCP 계정 설정**: `accounts/` 디렉토리 참조

---

## 🔗 관련 문서

- ["WSL 고급 설정 가이드"][wsl-setup-guide.md]
- ["Cloud Master 실습 가이드"][cloud_master/execuise-guide.md]
- ["AWS 계정 가입 가이드"]["cloud_master/accounts/AWS계정가입.md"]
- ["GCP 계정 가입 가이드"]["cloud_master/accounts/GCP_개인계정가입.md"]

---

이제 WSL 환경이 준비되었습니다! Cloud Master 과정의 실습을 시작할 수 있습니다. 🚀✨