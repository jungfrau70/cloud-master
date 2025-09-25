#!/bin/bash
set -e

echo "==== GCP Git 설치 스크립트 시작 ===="

# OS 정보 확인
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$NAME
    VER=$VERSION_ID
    echo "OS: $OS $VER"
else
    echo "OS 정보를 확인할 수 없습니다."
    exit 1
fi

# Ubuntu/Debian 계열
if [[ "$OS" == *"Ubuntu"* ]] || [[ "$OS" == *"Debian"* ]]; then
    echo "Ubuntu/Debian 계열에서 Git 설치..."
    sudo apt-get update -y
    sudo apt-get install -y git

# RHEL/CentOS/Rocky Linux 계열
elif [[ "$OS" == *"CentOS"* ]] || [[ "$OS" == *"Red Hat"* ]] || [[ "$OS" == *"Rocky"* ]]; then
    echo "RHEL/CentOS/Rocky Linux 계열에서 Git 설치..."
    
    if command -v dnf &> /dev/null; then
        sudo dnf update -y
        sudo dnf install -y git
    else
        sudo yum update -y
        sudo yum install -y git
    fi

# Container-Optimized OS (COS)
elif [[ "$OS" == *"Container-Optimized"* ]] || [[ "$OS" == *"COS"* ]]; then
    echo "Container-Optimized OS에서 Git 설치..."
    # COS에서는 toolbox를 사용하여 설치
    sudo toolbox --bind=/home:/home --bind=/var:/var --bind=/tmp:/tmp /bin/bash -c "
        if command -v apt-get &> /dev/null; then
            apt-get update && apt-get install -y git
        elif command -v dnf &> /dev/null; then
            dnf update -y && dnf install -y git
        elif command -v yum &> /dev/null; then
            yum update -y && yum install -y git
        fi
    "

# SUSE 계열
elif [[ "$OS" == *"SUSE"* ]] || [[ "$OS" == *"openSUSE"* ]]; then
    echo "SUSE/openSUSE 계열에서 Git 설치..."
    sudo zypper refresh
    sudo zypper install -y git

else
    echo "지원되지 않는 OS입니다: $OS"
    echo "Ubuntu, Debian, CentOS, RHEL, Rocky Linux, Container-Optimized OS, SUSE만 지원됩니다."
    exit 1
fi

echo "==== Git 설치 완료 ===="
git --version

# Git 기본 설정 안내
echo ""
echo "💡 Git 기본 설정을 위해 다음 명령어를 실행하세요:"
echo "git config --global user.name \"Your Name\""
echo "git config --global user.email \"your.email@example.com\""
