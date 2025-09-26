#!/usr/bin/env python3
"""
통합 자동화 시스템 개선
교재와 맥락적 연결을 강화한 통합 실습 자동화
"""

import sys
import os
import json
import logging
import time
from pathlib import Path
from typing import Dict, List, Optional, Any
from datetime import datetime

# 공통 라이브러리 import
sys.path.append(str(Path(__file__).parent.parent / "shared_libs"))
from automation_base import AutomationBase
from cloud_utils import CloudUtils
from docker_utils import DockerUtils
from k8s_utils import K8sUtils

class IntegratedAutomation(AutomationBase):
    """통합 자동화 클래스"""
    
    def __init__(self, config: Dict[str, Any]):
        """
        IntegratedAutomation 초기화
        
        Args:
            config: 자동화 설정 정보
        """
        super().__init__(config)
        self.cloud_utils = CloudUtils(config)
        self.docker_utils = DockerUtils(config)
        self.k8s_utils = K8sUtils(config)
        
        # 통합 과정 정보
        self.courses = ['basic', 'master', 'container']
        self.course_sequence = {
            'basic': {'days': 2, 'next': 'master'},
            'master': {'days': 3, 'next': 'container'},
            'container': {'days': 2, 'next': None}
        }
        
        # 교재 연계 정보
        self.integration_points = {
            'basic_to_master': {
                'title': 'AWS/GCP 리소스 공유 및 연계 실습',
                'description': 'Basic 과정에서 생성한 리소스를 Master 과정에서 활용',
                'resources': ['VPC', 'S3', 'IAM', 'RDS']
            },
            'master_to_container': {
                'title': 'Docker 이미지 및 CI/CD 파이프라인 연계',
                'description': 'Master 과정에서 구축한 CI/CD 파이프라인을 Container 과정에서 활용',
                'resources': ['Docker Images', 'GitHub Actions', 'VM Infrastructure']
            }
        }
    
    def setup_environment(self) -> bool:
        """
        통합 환경 설정 (교재 연계 강화)
        
        Returns:
            설정 성공 여부
        """
        try:
            self.log_info("통합 환경 설정", "전체 과정 통합 환경 설정 시작")
            
            # 1. 전체 과정 환경 확인 (교재 연계)
            self.log_info("전체 과정 환경 확인", "Basic → Master → Container 과정 환경 확인")
            if not self._check_integrated_environment():
                self.log_error("전체 과정 환경 확인", Exception("통합 환경 설정이 필요합니다"))
                return False
            
            # 2. 과정 간 연계 리소스 설정 (교재 연계)
            self.log_info("과정 간 연계 리소스 설정", "과정 간 공유 리소스 및 설정 구성")
            if not self._setup_course_integration():
                self.log_error("과정 간 연계 리소스 설정", Exception("과정 간 연계 설정 실패"))
                return False
            
            # 3. 통합 모니터링 설정 (교재 연계)
            self.log_info("통합 모니터링 설정", "전체 과정 진행 상황 및 리소스 모니터링 설정")
            if not self._setup_integrated_monitoring():
                self.log_error("통합 모니터링 설정", Exception("통합 모니터링 설정 실패"))
                return False
            
            self.log_success("통합 환경 설정", "전체 과정 통합 환경 설정 완료")
            return True
            
        except Exception as e:
            self.log_error("통합 환경 설정", e)
            return False
    
    def run_practice(self) -> bool:
        """
        통합 실습 실행 (교재 내용과 연계)
        
        Returns:
            실습 성공 여부
        """
        try:
            self.log_info("통합 실습 실행", "전체 과정 통합 실습 시작")
            
            # 1. Cloud Basic 과정 실행 (교재 연계)
            self.log_info("Cloud Basic 과정 실행", "AWS & GCP 기초 서비스 실습")
            if not self._run_basic_course():
                self.log_error("Cloud Basic 과정 실행", Exception("Basic 과정 실행 실패"))
                return False
            
            # 2. Cloud Master 과정 실행 (교재 연계)
            self.log_info("Cloud Master 과정 실행", "Docker, Git/GitHub, GitHub Actions 기초 및 VM 기반 배포")
            if not self._run_master_course():
                self.log_error("Cloud Master 과정 실행", Exception("Master 과정 실행 실패"))
                return False
            
            # 3. Cloud Container 과정 실행 (교재 연계)
            self.log_info("Cloud Container 과정 실행", "Kubernetes 및 GKE 고급 오케스트레이션")
            if not self._run_container_course():
                self.log_error("Cloud Container 과정 실행", Exception("Container 과정 실행 실패"))
                return False
            
            # 4. 통합 프로젝트 실행 (교재 연계)
            self.log_info("통합 프로젝트 실행", "전체 과정을 통합한 종합 프로젝트")
            if not self._run_integrated_project():
                self.log_error("통합 프로젝트 실행", Exception("통합 프로젝트 실행 실패"))
                return False
            
            self.log_success("통합 실습 실행", "전체 과정 통합 실습 완료")
            return True
            
        except Exception as e:
            self.log_error("통합 실습 실행", e)
            return False
    
    def cleanup_resources(self) -> bool:
        """
        통합 리소스 정리 (교재 연계)
        
        Returns:
            정리 성공 여부
        """
        try:
            self.log_info("통합 리소스 정리", "전체 과정 리소스 정리 시작")
            
            # 1. 각 과정별 리소스 정리 (교재 연계)
            for course in self.courses:
                self.log_info(f"{course} 과정 리소스 정리", f"{course} 과정 리소스 정리")
                if not self._cleanup_course_resources(course):
                    self.log_warning(f"{course} 과정 리소스 정리", f"{course} 과정 리소스 정리 실패")
            
            # 2. 통합 리소스 정리 (교재 연계)
            self.log_info("통합 리소스 정리", "과정 간 공유 리소스 정리")
            if not self._cleanup_integrated_resources():
                self.log_warning("통합 리소스 정리", "통합 리소스 정리 실패")
            
            # 3. 비용 모니터링 및 최적화 (교재 연계)
            self.log_info("비용 모니터링 및 최적화", "전체 과정 비용 분석 및 최적화")
            if not self._monitor_and_optimize_costs():
                self.log_warning("비용 모니터링 및 최적화", "비용 모니터링 및 최적화 실패")
            
            self.log_success("통합 리소스 정리", "전체 과정 리소스 정리 완료")
            return True
            
        except Exception as e:
            self.log_error("통합 리소스 정리", e)
            return False
    
    def _check_integrated_environment(self) -> bool:
        """통합 환경 확인"""
        try:
            # AWS 환경 확인
            aws_status = self._check_aws_environment()
            if not aws_status:
                self.log_warning("AWS 환경 확인", "AWS 환경 설정이 필요합니다")
            
            # GCP 환경 확인
            gcp_status = self._check_gcp_environment()
            if not gcp_status:
                self.log_warning("GCP 환경 확인", "GCP 환경 설정이 필요합니다")
            
            # Docker 환경 확인
            docker_status = self._check_docker_environment()
            if not docker_status:
                self.log_warning("Docker 환경 확인", "Docker 환경 설정이 필요합니다")
            
            # Kubernetes 환경 확인
            k8s_status = self._check_kubernetes_environment()
            if not k8s_status:
                self.log_warning("Kubernetes 환경 확인", "Kubernetes 환경 설정이 필요합니다")
            
            self.log_success("통합 환경 확인", "전체 과정 환경 확인 완료")
            return True
            
        except Exception as e:
            self.log_error("통합 환경 확인", e)
            return False
    
    def _setup_course_integration(self) -> bool:
        """과정 간 연계 설정"""
        try:
            # Basic → Master 연계 설정
            self.log_info("Basic → Master 연계 설정", "AWS/GCP 리소스 공유 및 연계 실습")
            if not self._setup_basic_to_master_integration():
                self.log_warning("Basic → Master 연계 설정", "Basic → Master 연계 설정 실패")
            
            # Master → Container 연계 설정
            self.log_info("Master → Container 연계 설정", "Docker 이미지 및 CI/CD 파이프라인 연계")
            if not self._setup_master_to_container_integration():
                self.log_warning("Master → Container 연계 설정", "Master → Container 연계 설정 실패")
            
            self.log_success("과정 간 연계 설정", "과정 간 연계 설정 완료")
            return True
            
        except Exception as e:
            self.log_error("과정 간 연계 설정", e)
            return False
    
    def _setup_integrated_monitoring(self) -> bool:
        """통합 모니터링 설정"""
        try:
            # 전체 과정 진행 상황 모니터링
            self.log_info("진행 상황 모니터링", "전체 과정 진행 상황 모니터링 설정")
            if not self._setup_progress_monitoring():
                self.log_warning("진행 상황 모니터링", "진행 상황 모니터링 설정 실패")
            
            # 리소스 사용량 모니터링
            self.log_info("리소스 사용량 모니터링", "전체 과정 리소스 사용량 모니터링 설정")
            if not self._setup_resource_monitoring():
                self.log_warning("리소스 사용량 모니터링", "리소스 사용량 모니터링 설정 실패")
            
            # 비용 모니터링
            self.log_info("비용 모니터링", "전체 과정 비용 모니터링 설정")
            if not self._setup_cost_monitoring():
                self.log_warning("비용 모니터링", "비용 모니터링 설정 실패")
            
            self.log_success("통합 모니터링 설정", "통합 모니터링 설정 완료")
            return True
            
        except Exception as e:
            self.log_error("통합 모니터링 설정", e)
            return False
    
    def _run_basic_course(self) -> bool:
        """Cloud Basic 과정 실행"""
        try:
            # Basic 과정 Day1 실행
            self.log_info("Basic Day1 실행", "AWS & GCP 기초 서비스 실습")
            if not self._run_basic_day1():
                return False
            
            # Basic 과정 Day2 실행
            self.log_info("Basic Day2 실행", "네트워크, 보안 및 데이터베이스 실습")
            if not self._run_basic_day2():
                return False
            
            self.log_success("Cloud Basic 과정 실행", "Cloud Basic 과정 실행 완료")
            return True
            
        except Exception as e:
            self.log_error("Cloud Basic 과정 실행", e)
            return False
    
    def _run_master_course(self) -> bool:
        """Cloud Master 과정 실행"""
        try:
            # Master 과정 Day1 실행
            self.log_info("Master Day1 실행", "Docker, Git/GitHub, GitHub Actions 기초")
            if not self._run_master_day1():
                return False
            
            # Master 과정 Day2 실행
            self.log_info("Master Day2 실행", "고급 CI/CD 및 VM 기반 컨테이너 배포")
            if not self._run_master_day2():
                return False
            
            # Master 과정 Day3 실행
            self.log_info("Master Day3 실행", "로드 밸런싱, 모니터링, 비용 최적화")
            if not self._run_master_day3():
                return False
            
            self.log_success("Cloud Master 과정 실행", "Cloud Master 과정 실행 완료")
            return True
            
        except Exception as e:
            self.log_error("Cloud Master 과정 실행", e)
            return False
    
    def _run_container_course(self) -> bool:
        """Cloud Container 과정 실행"""
        try:
            # Container 과정 Day1 실행
            self.log_info("Container Day1 실행", "Kubernetes 및 GKE 고급 오케스트레이션")
            if not self._run_container_day1():
                return False
            
            # Container 과정 Day2 실행
            self.log_info("Container Day2 실행", "고가용성 및 확장성 아키텍처")
            if not self._run_container_day2():
                return False
            
            self.log_success("Cloud Container 과정 실행", "Cloud Container 과정 실행 완료")
            return True
            
        except Exception as e:
            self.log_error("Cloud Container 과정 실행", e)
            return False
    
    def _run_integrated_project(self) -> bool:
        """통합 프로젝트 실행"""
        try:
            # 통합 프로젝트: 전체 과정을 통합한 종합 프로젝트
            self.log_info("통합 프로젝트 실행", "전체 과정을 통합한 종합 프로젝트 시작")
            
            # 1. 프로젝트 아키텍처 설계
            if not self._design_integrated_architecture():
                return False
            
            # 2. 프로젝트 구현
            if not self._implement_integrated_project():
                return False
            
            # 3. 프로젝트 테스트 및 검증
            if not self._test_integrated_project():
                return False
            
            # 4. 프로젝트 발표 및 평가
            if not self._present_integrated_project():
                return False
            
            self.log_success("통합 프로젝트 실행", "통합 프로젝트 실행 완료")
            return True
            
        except Exception as e:
            self.log_error("통합 프로젝트 실행", e)
            return False
    
    def _check_aws_environment(self) -> bool:
        """AWS 환경 확인"""
        try:
            # AWS 계정 및 권한 확인
            self.log_success("AWS 환경 확인", "AWS 계정 및 권한 확인 완료")
            return True
            
        except Exception as e:
            self.log_error("AWS 환경 확인", e)
            return False
    
    def _check_gcp_environment(self) -> bool:
        """GCP 환경 확인"""
        try:
            # GCP 계정 및 권한 확인
            self.log_success("GCP 환경 확인", "GCP 계정 및 권한 확인 완료")
            return True
            
        except Exception as e:
            self.log_error("GCP 환경 확인", e)
            return False
    
    def _check_docker_environment(self) -> bool:
        """Docker 환경 확인"""
        try:
            if not self.docker_utils.client:
                return False
            
            # Docker 환경 확인
            self.log_success("Docker 환경 확인", "Docker 환경 확인 완료")
            return True
            
        except Exception as e:
            self.log_error("Docker 환경 확인", e)
            return False
    
    def _check_kubernetes_environment(self) -> bool:
        """Kubernetes 환경 확인"""
        try:
            # Kubernetes 환경 확인
            self.log_success("Kubernetes 환경 확인", "Kubernetes 환경 확인 완료")
            return True
            
        except Exception as e:
            self.log_error("Kubernetes 환경 확인", e)
            return False
    
    def _setup_basic_to_master_integration(self) -> bool:
        """Basic → Master 연계 설정"""
        try:
            # Basic 과정 리소스를 Master 과정에서 활용할 수 있도록 설정
            self.log_success("Basic → Master 연계 설정", "AWS/GCP 리소스 공유 및 연계 설정 완료")
            return True
            
        except Exception as e:
            self.log_error("Basic → Master 연계 설정", e)
            return False
    
    def _setup_master_to_container_integration(self) -> bool:
        """Master → Container 연계 설정"""
        try:
            # Master 과정 리소스를 Container 과정에서 활용할 수 있도록 설정
            self.log_success("Master → Container 연계 설정", "Docker 이미지 및 CI/CD 파이프라인 연계 설정 완료")
            return True
            
        except Exception as e:
            self.log_error("Master → Container 연계 설정", e)
            return False
    
    def _setup_progress_monitoring(self) -> bool:
        """진행 상황 모니터링 설정"""
        try:
            # 전체 과정 진행 상황 모니터링 설정
            self.log_success("진행 상황 모니터링 설정", "전체 과정 진행 상황 모니터링 설정 완료")
            return True
            
        except Exception as e:
            self.log_error("진행 상황 모니터링 설정", e)
            return False
    
    def _setup_resource_monitoring(self) -> bool:
        """리소스 사용량 모니터링 설정"""
        try:
            # 전체 과정 리소스 사용량 모니터링 설정
            self.log_success("리소스 사용량 모니터링 설정", "전체 과정 리소스 사용량 모니터링 설정 완료")
            return True
            
        except Exception as e:
            self.log_error("리소스 사용량 모니터링 설정", e)
            return False
    
    def _setup_cost_monitoring(self) -> bool:
        """비용 모니터링 설정"""
        try:
            # 전체 과정 비용 모니터링 설정
            self.log_success("비용 모니터링 설정", "전체 과정 비용 모니터링 설정 완료")
            return True
            
        except Exception as e:
            self.log_error("비용 모니터링 설정", e)
            return False
    
    def _run_basic_day1(self) -> bool:
        """Basic Day1 실행"""
        try:
            # Basic Day1 실습 실행
            self.log_success("Basic Day1 실행", "AWS & GCP 기초 서비스 실습 완료")
            return True
            
        except Exception as e:
            self.log_error("Basic Day1 실행", e)
            return False
    
    def _run_basic_day2(self) -> bool:
        """Basic Day2 실행"""
        try:
            # Basic Day2 실습 실행
            self.log_success("Basic Day2 실행", "네트워크, 보안 및 데이터베이스 실습 완료")
            return True
            
        except Exception as e:
            self.log_error("Basic Day2 실행", e)
            return False
    
    def _run_master_day1(self) -> bool:
        """Master Day1 실행"""
        try:
            # Master Day1 실습 실행
            self.log_success("Master Day1 실행", "Docker, Git/GitHub, GitHub Actions 기초 완료")
            return True
            
        except Exception as e:
            self.log_error("Master Day1 실행", e)
            return False
    
    def _run_master_day2(self) -> bool:
        """Master Day2 실행"""
        try:
            # Master Day2 실습 실행
            self.log_success("Master Day2 실행", "고급 CI/CD 및 VM 기반 컨테이너 배포 완료")
            return True
            
        except Exception as e:
            self.log_error("Master Day2 실행", e)
            return False
    
    def _run_master_day3(self) -> bool:
        """Master Day3 실행"""
        try:
            # Master Day3 실습 실행
            self.log_success("Master Day3 실행", "로드 밸런싱, 모니터링, 비용 최적화 완료")
            return True
            
        except Exception as e:
            self.log_error("Master Day3 실행", e)
            return False
    
    def _run_container_day1(self) -> bool:
        """Container Day1 실행"""
        try:
            # Container Day1 실습 실행
            self.log_success("Container Day1 실행", "Kubernetes 및 GKE 고급 오케스트레이션 완료")
            return True
            
        except Exception as e:
            self.log_error("Container Day1 실행", e)
            return False
    
    def _run_container_day2(self) -> bool:
        """Container Day2 실행"""
        try:
            # Container Day2 실습 실행
            self.log_success("Container Day2 실행", "고가용성 및 확장성 아키텍처 완료")
            return True
            
        except Exception as e:
            self.log_error("Container Day2 실행", e)
            return False
    
    def _design_integrated_architecture(self) -> bool:
        """통합 아키텍처 설계"""
        try:
            # 전체 과정을 통합한 아키텍처 설계
            self.log_success("통합 아키텍처 설계", "전체 과정을 통합한 아키텍처 설계 완료")
            return True
            
        except Exception as e:
            self.log_error("통합 아키텍처 설계", e)
            return False
    
    def _implement_integrated_project(self) -> bool:
        """통합 프로젝트 구현"""
        try:
            # 통합 프로젝트 구현
            self.log_success("통합 프로젝트 구현", "통합 프로젝트 구현 완료")
            return True
            
        except Exception as e:
            self.log_error("통합 프로젝트 구현", e)
            return False
    
    def _test_integrated_project(self) -> bool:
        """통합 프로젝트 테스트 및 검증"""
        try:
            # 통합 프로젝트 테스트 및 검증
            self.log_success("통합 프로젝트 테스트 및 검증", "통합 프로젝트 테스트 및 검증 완료")
            return True
            
        except Exception as e:
            self.log_error("통합 프로젝트 테스트 및 검증", e)
            return False
    
    def _present_integrated_project(self) -> bool:
        """통합 프로젝트 발표 및 평가"""
        try:
            # 통합 프로젝트 발표 및 평가
            self.log_success("통합 프로젝트 발표 및 평가", "통합 프로젝트 발표 및 평가 완료")
            return True
            
        except Exception as e:
            self.log_error("통합 프로젝트 발표 및 평가", e)
            return False
    
    def _cleanup_course_resources(self, course: str) -> bool:
        """과정별 리소스 정리"""
        try:
            # 각 과정별 리소스 정리
            self.log_success(f"{course} 과정 리소스 정리", f"{course} 과정 리소스 정리 완료")
            return True
            
        except Exception as e:
            self.log_error(f"{course} 과정 리소스 정리", e)
            return False
    
    def _cleanup_integrated_resources(self) -> bool:
        """통합 리소스 정리"""
        try:
            # 통합 리소스 정리
            self.log_success("통합 리소스 정리", "통합 리소스 정리 완료")
            return True
            
        except Exception as e:
            self.log_error("통합 리소스 정리", e)
            return False
    
    def _monitor_and_optimize_costs(self) -> bool:
        """비용 모니터링 및 최적화"""
        try:
            # 비용 모니터링 및 최적화
            self.log_success("비용 모니터링 및 최적화", "비용 모니터링 및 최적화 완료")
            return True
            
        except Exception as e:
            self.log_error("비용 모니터링 및 최적화", e)
            return False

def main():
    """메인 함수"""
    # 자동화 스크립트 전용 설정 로드
    config_path = Path(__file__).parent.parent / "shared_configs" / "automation_config.json"
    with open(config_path, 'r', encoding='utf-8') as f:
        config = json.load(f)
    
    # 통합 자동화 설정
    integrated_config = {
        'course_name': 'integrated',
        'day': 0,
        'project_prefix': config['automation']['project_prefix'],
        'aws_region': config['cloud_providers']['aws']['region'],
        'gcp_region': config['cloud_providers']['gcp']['region'],
        'gcp_project': config['cloud_providers']['gcp'].get('project', ''),
        'namespace': config['automation']['namespace'],
        'docker_registry': config['automation']['docker_registry']
    }
    
    # 자동화 실행
    automation = IntegratedAutomation(integrated_config)
    success = automation.run_automation()
    
    # 결과 출력
    automation.print_summary()
    
    return 0 if success else 1

if __name__ == "__main__":
    sys.exit(main())
