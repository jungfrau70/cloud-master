GitHub Repository의 Settings 페이지로 이동해야 합니다. 현재 개인 계정 설정 페이지에 있으시네요.

## �� GitHub Repository Settings로 이동하는 방법

### 1. Repository로 이동
1. **GitHub 메인 페이지**에서 `jungfrau70/github-actions-demo` 저장소로 이동
2. 또는 직접 URL 입력: `https://github.com/jungfrau70/github-actions-demo`

### 2. Settings 탭 클릭
Repository 페이지에서 상단 탭 중 **"Settings"**를 클릭하세요.

### 3. Secrets 설정
Settings 페이지에서:
1. 왼쪽 메뉴에서 **"Secrets and variables"** 클릭
2. **"Actions"** 클릭
3. **"New repository secret"** 버튼 클릭

## �� 설정해야 할 GitHub Secrets

### Secret 1: AWS_VM_HOST
- **Name**: `AWS_VM_HOST`
- **Secret**: AWS EC2 인스턴스의 Public IP 주소

### Secret 2: AWS_VM_USERNAME
- **Name**: `AWS_VM_USERNAME`  
- **Secret**: `ubuntu`

### Secret 3: AWS_VM_SSH_KEY
- **Name**: `AWS_VM_SSH_KEY`
- **Secret**: SSH 키 전체 내용 ["BEGIN부터 END까지"]

### Secret 4: DOCKER_USERNAME
- **Name**: `DOCKER_USERNAME`
- **Secret**: Docker Hub 사용자명

### Secret 5: DOCKER_PASSWORD
- **Name**: `DOCKER_PASSWORD`
- **Secret**: Docker Hub Personal Access Token

## 🚀 빠른 링크

직접 링크를 사용하세요:
- **Repository Settings**: `https://github.com/jungfrau70/github-actions-demo/settings`
- **Secrets 설정**: `https://github.com/jungfrau70/github-actions-demo/settings/secrets/actions`

이 링크들을 클릭하면 바로 Secrets 설정 페이지로 이동할 수 있습니다!