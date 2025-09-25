#!/bin/bash

# GKE 인증 플러그인 수동 설치 스크립트
# WSL 환경에서 GCP GKE 클러스터 연결 문제 해결

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 로그 함수
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

echo "=== GKE 인증 플러그인 수동 설치 ==="
echo ""

# 1. 현재 환경 확인
log_info "현재 환경 확인 중..."
echo "OS: $(uname -a)"

# WSL, MINGW64, MSYS2 환경 감지
if grep -q Microsoft /proc/version 2>/dev/null; then
    echo "WSL 버전: $(cat /proc/version)"
    ENVIRONMENT="WSL"
elif [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" || "$MSYSTEM" == "MINGW64" || "$MSYSTEM" == "MINGW32" ]]; then
    echo "Windows 환경: Git Bash/MSYS2"
    ENVIRONMENT="WINDOWS"
else
    echo "Linux/macOS 환경"
    ENVIRONMENT="LINUX"
fi
echo ""

# 2. gcloud CLI 버전 확인
log_info "gcloud CLI 버전 확인 중..."
if command -v gcloud &> /dev/null; then
    gcloud version
else
    log_error "gcloud CLI가 설치되지 않았습니다."
    exit 1
fi
echo ""

# 3. GKE 인증 플러그인 다운로드 및 설치
log_info "GKE 인증 플러그인 다운로드 중..."

# Google Cloud 공식 설치 방법 사용
log_info "Google Cloud 공식 설치 방법 사용 중..."

# 1. gcloud components를 통한 설치 시도
log_info "gcloud components를 통한 설치 시도 중..."
if gcloud components install gke-gcloud-auth-plugin --quiet 2>/dev/null; then
    log_success "gcloud components를 통한 설치 성공"
    
    # 설치 확인
    if command -v gke-gcloud-auth-plugin &> /dev/null; then
        log_success "✅ gke-gcloud-auth-plugin 설치 완료"
        log_info "플러그인 버전: $(gke-gcloud-auth-plugin --version 2>/dev/null || echo '버전 확인 불가')"
        exit 0
    else
        log_warning "플러그인이 설치되었지만 PATH에서 찾을 수 없습니다"
    fi
else
    log_warning "gcloud components 설치 실패. 권한 문제일 수 있습니다."
    log_info "해결 방법:"
    log_info "1. WSL을 관리자 권한으로 실행"
    log_info "2. sudo gcloud components install gke-gcloud-auth-plugin 실행"
    log_info "3. PC 재시작 후 다시 시도"
    
    # 수동 설치를 위한 고정 버전 사용
    PLUGIN_VERSION="v0.5.9"
    log_info "수동 설치 버전: $PLUGIN_VERSION"
fi

log_info "다운로드할 버전: $PLUGIN_VERSION"

# 아키텍처 확인 (환경별 처리)
ARCH=$(uname -m)
case $ENVIRONMENT in
    WINDOWS)
        case $ARCH in
            x86_64)
                PLUGIN_ARCH="windows_amd64"
                PLUGIN_EXT=".exe"
                ;;
            *)
                log_error "Windows에서 지원되지 않는 아키텍처: $ARCH"
                exit 1
                ;;
        esac
        ;;
    WSL|LINUX)
        case $ARCH in
            x86_64)
                PLUGIN_ARCH="linux_amd64"
                PLUGIN_EXT=""
                ;;
            aarch64|arm64)
                PLUGIN_ARCH="linux_arm64"
                PLUGIN_EXT=""
                ;;
            *)
                log_error "지원되지 않는 아키텍처: $ARCH"
                exit 1
                ;;
        esac
        ;;
    *)
        log_error "지원되지 않는 환경: $ENVIRONMENT"
        exit 1
        ;;
esac

# Google Cloud Storage에서 직접 다운로드
case $ENVIRONMENT in
    WINDOWS)
        DOWNLOAD_URL="https://storage.googleapis.com/gke-release/gke-gcloud-auth-plugin/v0.5.9/windows/amd64/gke-gcloud-auth-plugin.exe"
        ;;
    WSL|LINUX)
        DOWNLOAD_URL="https://storage.googleapis.com/gke-release/gke-gcloud-auth-plugin/v0.5.9/linux/amd64/gke-gcloud-auth-plugin"
        ;;
esac

log_info "다운로드 URL: $DOWNLOAD_URL"
log_info "환경: $ENVIRONMENT, 아키텍처: $PLUGIN_ARCH, 확장자: $PLUGIN_EXT"

# 임시 디렉토리 생성
TEMP_DIR=$(mktemp -d)
cd "$TEMP_DIR"

# 플러그인 다운로드 (재시도 로직 포함)
log_info "플러그인 다운로드 중..."
DOWNLOAD_SUCCESS=false
for attempt in 1 2 3; do
    log_info "다운로드 시도 $attempt/3..."
    if curl -L -o gke-gcloud-auth-plugin "$DOWNLOAD_URL" --fail --silent --show-error; then
        # 파일 크기 확인 (최소 1MB 이상이어야 함)
        FILE_SIZE=$(stat -c%s gke-gcloud-auth-plugin 2>/dev/null || echo "0")
        if [ "$FILE_SIZE" -gt 1048576 ]; then  # 1MB = 1048576 bytes
            log_success "다운로드 완료 (크기: $FILE_SIZE bytes)"
            DOWNLOAD_SUCCESS=true
            break
        else
            log_warning "다운로드된 파일이 너무 작습니다 ($FILE_SIZE bytes). 재시도 중..."
            rm -f gke-gcloud-auth-plugin
        fi
    else
        log_warning "다운로드 실패 (시도 $attempt/3)"
    fi
    sleep 2
done

if [ "$DOWNLOAD_SUCCESS" = false ]; then
    log_error "Google Cloud Storage에서 다운로드 실패"
    log_info "수동 설치 방법:"
    log_info "1. https://cloud.google.com/kubernetes-engine/docs/how-to/cluster-access-for-kubectl#install_plugin 방문"
    log_info "2. 환경에 맞는 바이너리를 다운로드하여 PATH에 추가"
    exit 1
fi

# 실행 권한 부여 (Linux/WSL 환경에서만)
if [[ "$ENVIRONMENT" != "WINDOWS" ]]; then
    chmod +x gke-gcloud-auth-plugin*
fi

# 4. kubectl 플러그인 디렉토리 확인 및 생성
log_info "kubectl 플러그인 디렉토리 확인 중..."

# 환경별 플러그인 디렉토리 설정
case $ENVIRONMENT in
    WINDOWS)
        # Windows 환경에서는 PATH에 추가할 수 있는 디렉토리 사용
        KUBECTL_PLUGIN_DIR="$HOME/.local/bin"
        mkdir -p "$KUBECTL_PLUGIN_DIR"
        PLUGIN_NAME="gke-gcloud-auth-plugin.exe"
        ;;
    WSL|LINUX)
        KUBECTL_PLUGIN_DIR="$HOME/.kubectl/plugins"
        mkdir -p "$KUBECTL_PLUGIN_DIR"
        PLUGIN_NAME="gke-gcloud-auth-plugin"
        ;;
esac

# 플러그인 설치
log_info "플러그인 설치 중... ($KUBECTL_PLUGIN_DIR/$PLUGIN_NAME)"
if cp gke-gcloud-auth-plugin* "$KUBECTL_PLUGIN_DIR/$PLUGIN_NAME"; then
    log_success "플러그인 설치 완료"
else
    log_error "플러그인 설치 실패"
    exit 1
fi

# 5. PATH에 플러그인 디렉토리 추가
log_info "PATH 설정 중..."
if ! echo "$PATH" | grep -q "$KUBECTL_PLUGIN_DIR"; then
    # 현재 세션에 PATH 추가
    export PATH="$PATH:$KUBECTL_PLUGIN_DIR"
    
    # 영구적으로 PATH 추가
    case $ENVIRONMENT in
        WINDOWS)
            # Windows 환경에서는 .bashrc에 추가
            echo "export PATH=\"\$PATH:$KUBECTL_PLUGIN_DIR\"" >> ~/.bashrc
            ;;
        WSL|LINUX)
            echo "export PATH=\"\$PATH:$KUBECTL_PLUGIN_DIR\"" >> ~/.bashrc
            ;;
    esac
    log_success "PATH에 플러그인 디렉토리 추가됨"
else
    log_info "PATH에 이미 플러그인 디렉토리가 포함되어 있습니다"
fi

# 6. 임시 파일 정리
cd /
rm -rf "$TEMP_DIR"

# 7. 설치 확인
log_info "설치 확인 중..."
if command -v gke-gcloud-auth-plugin &> /dev/null; then
    log_success "✅ gke-gcloud-auth-plugin 설치 완료"
    gke-gcloud-auth-plugin --version
else
    log_error "❌ gke-gcloud-auth-plugin 설치 실패"
    exit 1
fi

echo ""
log_success "=== GKE 인증 플러그인 설치 완료 ==="
echo ""
log_info "다음 단계:"
echo "1. 새 터미널 세션을 시작하거나 'source ~/.bashrc' 실행"
echo "2. 'kubectl get nodes' 명령어로 클러스터 연결 확인"
echo "3. 필요시 'gcloud container clusters get-credentials cloud-master-cluster --zone=asia-northeast3-a' 실행"
