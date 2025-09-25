#!/bin/bash
set -e

echo "==== Git 설치 스크립트 시작 ===="

# Amazon Linux 버전 확인
OS_VERSION=$(cat /etc/os-release | grep ^VERSION_ID | cut -d= -f2 | tr -d '"')

echo "Amazon Linux 버전: $OS_VERSION"

# Amazon Linux 2
if [[ "$OS_VERSION" == "2" ]]; then
    echo "Amazon Linux 2에서 Git 설치..."
    sudo yum update -y
    sudo yum install -y git

# Amazon Linux 2023
elif [[ "$OS_VERSION" == "2023" ]]; then
    echo "Amazon Linux 2023에서 Git 설치..."
    sudo dnf update -y
    sudo dnf install -y git

else
    echo "지원되지 않는 Amazon Linux 버전입니다: $OS_VERSION"
    exit 1
fi

echo "==== Git 설치 완료 ===="
git --version

