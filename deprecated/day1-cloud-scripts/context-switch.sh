#!/bin/bash

# kubectl Context 전환 스크립트
# Cloud Master Day2용 - Kubernetes Context 관리

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# 로그 함수
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# 현재 context 확인
show_current_context() {
    local current_context=$(kubectl config current-context 2>/dev/null)
    if [ $? -eq 0 ]; then
        log_info "현재 활성 Context: $current_context"
    else
        log_error "kubectl이 설치되지 않았거나 설정되지 않았습니다."
        return 1
    fi
}

# 모든 context 목록 표시
list_contexts() {
    log_info "사용 가능한 Context 목록:"
    kubectl config get-contexts
}

# Context 전환
switch_context() {
    local context_name="$1"
    
    if [ -z "$context_name" ]; then
        log_error "Context 이름을 지정해주세요."
        return 1
    fi
    
    log_info "Context 전환 중: $context_name"
    
    if kubectl config use-context "$context_name" 2>/dev/null; then
        log_success "Context 전환 완료: $context_name"
        show_current_context
    else
        log_error "Context 전환 실패: $context_name"
        log_info "사용 가능한 Context 목록:"
        kubectl config get-contexts
        return 1
    fi
}

# Context 연결 테스트
test_context() {
    local context_name="$1"
    
    if [ -z "$context_name" ]; then
        context_name=$(kubectl config current-context 2>/dev/null)
    fi
    
    log_info "Context 연결 테스트: $context_name"
    
    # Context 전환
    if ! kubectl config use-context "$context_name" 2>/dev/null; then
        log_error "Context 전환 실패: $context_name"
        return 1
    fi
    
    # 클러스터 정보 확인
    log_info "클러스터 정보 확인 중..."
    if kubectl cluster-info 2>/dev/null; then
        log_success "클러스터 연결 성공"
    else
        log_warning "클러스터 연결 실패 (인증 문제일 수 있음)"
    fi
    
    # 노드 상태 확인
    log_info "노드 상태 확인 중..."
    if kubectl get nodes 2>/dev/null; then
        log_success "노드 상태 확인 성공"
    else
        log_warning "노드 상태 확인 실패"
    fi
    
    # 네임스페이스 확인
    log_info "네임스페이스 확인 중..."
    if kubectl get namespaces 2>/dev/null; then
        log_success "네임스페이스 확인 성공"
    else
        log_warning "네임스페이스 확인 실패"
    fi
}

# GKE 클러스터 자격 증명 설정
setup_gke_context() {
    local cluster_name="$1"
    local zone="$2"
    local project_id="$3"
    
    if [ -z "$cluster_name" ] || [ -z "$zone" ] || [ -z "$project_id" ]; then
        log_error "GKE 클러스터 정보가 부족합니다."
        log_info "사용법: $0 setup-gke <cluster-name> <zone> <project-id>"
        return 1
    fi
    
    log_info "GKE 클러스터 자격 증명 설정 중..."
    log_info "클러스터: $cluster_name"
    log_info "존: $zone"
    log_info "프로젝트: $project_id"
    
    if gcloud container clusters get-credentials "$cluster_name" --zone "$zone" --project "$project_id" 2>/dev/null; then
        log_success "GKE 클러스터 자격 증명 설정 완료"
        
        # Context 이름을 간단하게 변경
        local new_context_name="gke-$cluster_name"
        if kubectl config rename-context "gke_${project_id}_${zone}_${cluster_name}" "$new_context_name" 2>/dev/null; then
            log_success "Context 이름 변경 완료: $new_context_name"
        fi
        
        # 연결 테스트
        test_context "$new_context_name"
    else
        log_error "GKE 클러스터 자격 증명 설정 실패"
        return 1
    fi
}

# Context 삭제
delete_context() {
    local context_name="$1"
    
    if [ -z "$context_name" ]; then
        log_error "삭제할 Context 이름을 지정해주세요."
        return 1
    fi
    
    log_warning "Context 삭제: $context_name"
    read -p "정말로 삭제하시겠습니까? (y/N): " confirm
    
    if [[ $confirm =~ ^[Yy]$ ]]; then
        if kubectl config delete-context "$context_name" 2>/dev/null; then
            log_success "Context 삭제 완료: $context_name"
        else
            log_error "Context 삭제 실패: $context_name"
            return 1
        fi
    else
        log_info "Context 삭제 취소됨"
    fi
}

# 도움말 표시
show_help() {
    echo "kubectl Context 관리 스크립트"
    echo ""
    echo "사용법: $0 <명령어> [옵션]"
    echo ""
    echo "명령어:"
    echo "  current                 현재 활성 context 표시"
    echo "  list                    모든 context 목록 표시"
    echo "  switch <context-name>   context 전환"
    echo "  test [context-name]     context 연결 테스트"
    echo "  setup-gke <cluster> <zone> <project>  GKE 클러스터 자격 증명 설정"
    echo "  delete <context-name>   context 삭제"
    echo "  help                    이 도움말 표시"
    echo ""
    echo "예시:"
    echo "  $0 current"
    echo "  $0 list"
    echo "  $0 switch gke-cloud-master"
    echo "  $0 test gke-cloud-master"
    echo "  $0 setup-gke cloud-master-cluster asia-northeast3-a cloud-deployment-471606"
    echo "  $0 delete old-context"
}

# 메인 함수
main() {
    case "$1" in
        "current")
            show_current_context
            ;;
        "list")
            list_contexts
            ;;
        "switch")
            switch_context "$2"
            ;;
        "test")
            test_context "$2"
            ;;
        "setup-gke")
            setup_gke_context "$2" "$3" "$4"
            ;;
        "delete")
            delete_context "$2"
            ;;
        "help"|"--help"|"-h")
            show_help
            ;;
        "")
            log_info "현재 상태:"
            show_current_context
            echo ""
            log_info "사용 가능한 명령어:"
            show_help
            ;;
        *)
            log_error "알 수 없는 명령어: $1"
            show_help
            exit 1
            ;;
    esac
}

# 스크립트 실행
if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    main "$@"
fi
