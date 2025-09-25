@echo off
REM kubectl Context 전환 스크립트 (Windows 배치 파일)
REM Cloud Master Day2용 - Kubernetes Context 관리

setlocal enabledelayedexpansion

REM 색상 정의 (Windows에서는 제한적)
set "INFO=[INFO]"
set "SUCCESS=[SUCCESS]"
set "WARNING=[WARNING]"
set "ERROR=[ERROR]"

REM 현재 context 확인
:show_current_context
kubectl config current-context >nul 2>&1
if %errorlevel% neq 0 (
    echo %ERROR% kubectl이 설치되지 않았거나 설정되지 않았습니다.
    exit /b 1
)
for /f "tokens=*" %%i in ('kubectl config current-context 2^>nul') do set current_context=%%i
echo %INFO% 현재 활성 Context: !current_context!
goto :eof

REM 모든 context 목록 표시
:list_contexts
echo %INFO% 사용 가능한 Context 목록:
kubectl config get-contexts
goto :eof

REM Context 전환
:switch_context
set context_name=%1
if "%context_name%"=="" (
    echo %ERROR% Context 이름을 지정해주세요.
    exit /b 1
)

echo %INFO% Context 전환 중: %context_name%
kubectl config use-context "%context_name%" >nul 2>&1
if %errorlevel% equ 0 (
    echo %SUCCESS% Context 전환 완료: %context_name%
    call :show_current_context
) else (
    echo %ERROR% Context 전환 실패: %context_name%
    echo %INFO% 사용 가능한 Context 목록:
    kubectl config get-contexts
    exit /b 1
)
goto :eof

REM Context 연결 테스트
:test_context
set context_name=%1
if "%context_name%"=="" (
    for /f "tokens=*" %%i in ('kubectl config current-context 2^>nul') do set context_name=%%i
)

echo %INFO% Context 연결 테스트: %context_name%

REM Context 전환
kubectl config use-context "%context_name%" >nul 2>&1
if %errorlevel% neq 0 (
    echo %ERROR% Context 전환 실패: %context_name%
    exit /b 1
)

REM 클러스터 정보 확인
echo %INFO% 클러스터 정보 확인 중...
kubectl cluster-info >nul 2>&1
if %errorlevel% equ 0 (
    echo %SUCCESS% 클러스터 연결 성공
) else (
    echo %WARNING% 클러스터 연결 실패 (인증 문제일 수 있음)
)

REM 노드 상태 확인
echo %INFO% 노드 상태 확인 중...
kubectl get nodes >nul 2>&1
if %errorlevel% equ 0 (
    echo %SUCCESS% 노드 상태 확인 성공
) else (
    echo %WARNING% 노드 상태 확인 실패
)

REM 네임스페이스 확인
echo %INFO% 네임스페이스 확인 중...
kubectl get namespaces >nul 2>&1
if %errorlevel% equ 0 (
    echo %SUCCESS% 네임스페이스 확인 성공
) else (
    echo %WARNING% 네임스페이스 확인 실패
)
goto :eof

REM GKE 클러스터 자격 증명 설정
:setup_gke_context
set cluster_name=%1
set zone=%2
set project_id=%3

if "%cluster_name%"=="" (
    echo %ERROR% GKE 클러스터 정보가 부족합니다.
    echo %INFO% 사용법: %0 setup-gke ^<cluster-name^> ^<zone^> ^<project-id^>
    exit /b 1
)

echo %INFO% GKE 클러스터 자격 증명 설정 중...
echo %INFO% 클러스터: %cluster_name%
echo %INFO% 존: %zone%
echo %INFO% 프로젝트: %project_id%

gcloud container clusters get-credentials "%cluster_name%" --zone "%zone%" --project "%project_id%" >nul 2>&1
if %errorlevel% equ 0 (
    echo %SUCCESS% GKE 클러스터 자격 증명 설정 완료
    
    REM Context 이름을 간단하게 변경
    set new_context_name=gke-%cluster_name%
    kubectl config rename-context "gke_%project_id%_%zone%_%cluster_name%" "%new_context_name%" >nul 2>&1
    if %errorlevel% equ 0 (
        echo %SUCCESS% Context 이름 변경 완료: %new_context_name%
    )
    
    REM 연결 테스트
    call :test_context "%new_context_name%"
) else (
    echo %ERROR% GKE 클러스터 자격 증명 설정 실패
    exit /b 1
)
goto :eof

REM Context 삭제
:delete_context
set context_name=%1
if "%context_name%"=="" (
    echo %ERROR% 삭제할 Context 이름을 지정해주세요.
    exit /b 1
)

echo %WARNING% Context 삭제: %context_name%
set /p confirm="정말로 삭제하시겠습니까? (y/N): "
if /i "%confirm%"=="y" (
    kubectl config delete-context "%context_name%" >nul 2>&1
    if %errorlevel% equ 0 (
        echo %SUCCESS% Context 삭제 완료: %context_name%
    ) else (
        echo %ERROR% Context 삭제 실패: %context_name%
        exit /b 1
    )
) else (
    echo %INFO% Context 삭제 취소됨
)
goto :eof

REM 도움말 표시
:show_help
echo kubectl Context 관리 스크립트 (Windows)
echo.
echo 사용법: %0 ^<명령어^> [옵션]
echo.
echo 명령어:
echo   current                 현재 활성 context 표시
echo   list                    모든 context 목록 표시
echo   switch ^<context-name^>   context 전환
echo   test [context-name]     context 연결 테스트
echo   setup-gke ^<cluster^> ^<zone^> ^<project^>  GKE 클러스터 자격 증명 설정
echo   delete ^<context-name^>   context 삭제
echo   help                    이 도움말 표시
echo.
echo 예시:
echo   %0 current
echo   %0 list
echo   %0 switch gke-cloud-master
echo   %0 test gke-cloud-master
echo   %0 setup-gke cloud-master-cluster asia-northeast3-a cloud-deployment-471606
echo   %0 delete old-context
goto :eof

REM 메인 함수
:main
if "%1"=="current" (
    call :show_current_context
) else if "%1"=="list" (
    call :list_contexts
) else if "%1"=="switch" (
    call :switch_context %2
) else if "%1"=="test" (
    call :test_context %2
) else if "%1"=="setup-gke" (
    call :setup_gke_context %2 %3 %4
) else if "%1"=="delete" (
    call :delete_context %2
) else if "%1"=="help" (
    call :show_help
) else if "%1"=="--help" (
    call :show_help
) else if "%1"=="-h" (
    call :show_help
) else if "%1"=="" (
    echo %INFO% 현재 상태:
    call :show_current_context
    echo.
    echo %INFO% 사용 가능한 명령어:
    call :show_help
) else (
    echo %ERROR% 알 수 없는 명령어: %1
    call :show_help
    exit /b 1
)
goto :eof

REM 스크립트 실행
call :main %*
