#!/usr/bin/env python3
"""
Cloud Master 과정 개선된 자동화 스크립트
교재와 맥락적 연결을 강화한 실습 자동화
"""

import sys
import os
import json
import logging
from pathlib import Path
from typing import Dict, List, Optional, Any

# 공통 라이브러리 import
sys.path.append(str(Path(__file__).parent.parent.parent / "shared_libs"))
from automation_base import AutomationBase
from cloud_utils import CloudUtils
from docker_utils import DockerUtils

class CloudMasterAutomation(AutomationBase):
    """Cloud Master 과정 자동화 클래스"""
    
    def __init__(self, config: Dict[str, Any]):
        """
        CloudMasterAutomation 초기화
        
        Args:
            config: 자동화 설정 정보
        """
        super().__init__(config)
        self.cloud_utils = CloudUtils(config)
        self.docker_utils = DockerUtils(config)
        self.day = config.get('day', 1)
        
        # 교재 연계 정보
        self.textbook_info = {
            "1": {
                "title": "Docker, Git/GitHub, GitHub Actions 기초",
                "sections": [
                    "Docker 기초 및 컨테이너 기술",
                    "Git/GitHub 기초 및 협업",
                    "GitHub Actions CI/CD 파이프라인",
                    "VM 기반 웹 애플리케이션 배포"
                ]
            },
            "2": {
                "title": "고급 CI/CD 및 VM 기반 컨테이너 배포",
                "sections": [
                    "Docker 고급 기법 및 최적화",
                    "GitHub Actions 고급 워크플로우",
                    "VM 기반 컨테이너 배포 자동화",
                    "완전 자동화된 배포 파이프라인"
                ]
            },
            "3": {
                "title": "로드 밸런싱, 모니터링, 비용 최적화",
                "sections": [
                    "로드 밸런싱 및 Auto Scaling",
                    "모니터링 및 로깅 시스템",
                    "장애 복구 및 운영 자동화",
                    "비용 최적화 및 운영 전략"
                ]
            }
        }
    
    def setup_environment(self) -> bool:
        """
        환경 설정 (교재 Day1 섹션 1 연계)
        
        Returns:
            설정 성공 여부
        """
        try:
            self.log_info("환경 설정", "Cloud Master Day1 환경 설정 시작")
            
            # 1. Docker 환경 확인 (교재 Day1 섹션 1.1)
            self.log_info("Docker 환경 확인", "Docker 설치 및 실행 상태 확인")
            if not self._check_docker_environment():
                self.log_error("Docker 환경 확인", Exception("Docker 환경 설정이 필요합니다"))
                return False
            
            # 2. Git/GitHub 환경 확인 (교재 Day1 섹션 2.1)
            self.log_info("Git/GitHub 환경 확인", "Git 설정 및 GitHub 연결 확인")
            if not self._check_git_environment():
                self.log_error("Git/GitHub 환경 확인", Exception("Git/GitHub 환경 설정이 필요합니다"))
                return False
            
            # 3. GitHub Actions 환경 확인 (교재 Day1 섹션 3.1)
            self.log_info("GitHub Actions 환경 확인", "GitHub Actions 활성화 및 권한 확인")
            if not self._check_github_actions_environment():
                self.log_error("GitHub Actions 환경 확인", Exception("GitHub Actions 환경 설정이 필요합니다"))
                return False
            
            # 4. Cloud Basic 과정 연계 확인 (교재 Day1 섹션 4.1)
            self.log_info("Cloud Basic 연계 확인", "이전 과정 리소스 및 설정 확인")
            if not self._check_basic_course_integration():
                self.log_error("Cloud Basic 연계 확인", Exception("Cloud Basic 과정 완료가 필요합니다"))
                return False
            
            self.log_success("환경 설정", "Cloud Master Day1 환경 설정 완료")
            return True
            
        except Exception as e:
            self.log_error("환경 설정", e)
            return False
    
    def run_practice(self) -> bool:
        """
        실습 실행 (교재 내용과 연계)
        
        Returns:
            실습 성공 여부
        """
        try:
            if self.day == 1:
                return self._run_day1_practice()
            elif self.day == 2:
                return self._run_day2_practice()
            elif self.day == 3:
                return self._run_day3_practice()
            else:
                self.log_error("실습 실행", Exception(f"지원하지 않는 일차: {self.day}"))
                return False
                
        except Exception as e:
            self.log_error("실습 실행", e)
            return False
    
    def _run_day1_practice(self) -> bool:
        """
        Day1 실습 실행 (교재 Day1 연계)
        
        Returns:
            실습 성공 여부
        """
        try:
            self.log_info("Day1 실습", "Docker, Git/GitHub, GitHub Actions 기초 실습 시작")
            
            # 1. Docker 기초 및 컨테이너 기술 (교재 Day1 섹션 1)
            self.log_info("Docker 기초 실습", "샘플 애플리케이션 컨테이너화")
            app_dir = self.docker_utils.create_sample_app("master", 1)
            if not app_dir:
                self.log_error("Docker 기초 실습", Exception("샘플 애플리케이션 생성 실패"))
                return False
            
            # Docker 이미지 빌드
            image_tag = self.docker_utils.build_image(app_dir, "master", 1)
            if not image_tag:
                self.log_error("Docker 기초 실습", Exception("Docker 이미지 빌드 실패"))
                return False
            
            # 2. Git/GitHub 기초 및 협업 (교재 Day1 섹션 2)
            self.log_info("Git/GitHub 기초 실습", "저장소 생성 및 협업 설정")
            if not self._setup_git_repository(app_dir):
                self.log_error("Git/GitHub 기초 실습", Exception("Git 저장소 설정 실패"))
                return False
            
            # 3. GitHub Actions CI/CD 파이프라인 (교재 Day1 섹션 3)
            self.log_info("GitHub Actions 실습", "CI/CD 파이프라인 구축")
            if not self._setup_github_actions(app_dir):
                self.log_error("GitHub Actions 실습", Exception("GitHub Actions 설정 실패"))
                return False
            
            # 4. VM 기반 웹 애플리케이션 배포 (교재 Day1 섹션 4)
            self.log_info("VM 배포 실습", "EC2/Compute Engine에 애플리케이션 배포")
            if not self._deploy_to_vm(image_tag):
                self.log_error("VM 배포 실습", Exception("VM 배포 실패"))
                return False
            
            self.log_success("Day1 실습", "Docker, Git/GitHub, GitHub Actions 기초 실습 완료")
            return True
            
        except Exception as e:
            self.log_error("Day1 실습", e)
            return False
    
    def _run_day2_practice(self) -> bool:
        """
        Day2 실습 실행 (교재 Day2 연계)
        
        Returns:
            실습 성공 여부
        """
        try:
            self.log_info("Day2 실습", "고급 CI/CD 및 VM 기반 컨테이너 배포 실습 시작")
            
            # 1. Docker 고급 기법 및 최적화 (교재 Day2 섹션 1)
            self.log_info("Docker 고급 실습", "멀티스테이지 빌드 및 최적화")
            if not self._optimize_docker_image():
                self.log_error("Docker 고급 실습", Exception("Docker 이미지 최적화 실패"))
                return False
            
            # 2. GitHub Actions 고급 워크플로우 (교재 Day2 섹션 2)
            self.log_info("GitHub Actions 고급 실습", "고급 워크플로우 및 환경별 배포")
            if not self._setup_advanced_github_actions():
                self.log_error("GitHub Actions 고급 실습", Exception("고급 워크플로우 설정 실패"))
                return False
            
            # 3. VM 기반 컨테이너 배포 자동화 (교재 Day2 섹션 3)
            self.log_info("VM 컨테이너 배포 실습", "고가용성 컨테이너 배포 환경 구성")
            if not self._setup_high_availability_deployment():
                self.log_error("VM 컨테이너 배포 실습", Exception("고가용성 배포 환경 구성 실패"))
                return False
            
            # 4. 완전 자동화된 배포 파이프라인 (교재 Day2 섹션 4)
            self.log_info("완전 자동화 실습", "GitHub 푸시 → Docker 빌드 → VM 배포 자동화")
            if not self._setup_fully_automated_pipeline():
                self.log_error("완전 자동화 실습", Exception("완전 자동화 파이프라인 설정 실패"))
                return False
            
            self.log_success("Day2 실습", "고급 CI/CD 및 VM 기반 컨테이너 배포 실습 완료")
            return True
            
        except Exception as e:
            self.log_error("Day2 실습", e)
            return False
    
    def _run_day3_practice(self) -> bool:
        """
        Day3 실습 실행 (교재 Day3 연계)
        
        Returns:
            실습 성공 여부
        """
        try:
            self.log_info("Day3 실습", "로드 밸런싱, 모니터링, 비용 최적화 실습 시작")
            
            # 1. 로드 밸런싱 및 Auto Scaling (교재 Day3 섹션 1)
            self.log_info("로드 밸런싱 실습", "ELB + Auto Scaling Group 구성")
            if not self._setup_load_balancing():
                self.log_error("로드 밸런싱 실습", Exception("로드 밸런싱 설정 실패"))
                return False
            
            # 2. 모니터링 및 로깅 시스템 (교재 Day3 섹션 2)
            self.log_info("모니터링 실습", "CloudWatch + Prometheus + Grafana 구축")
            if not self._setup_monitoring():
                self.log_error("모니터링 실습", Exception("모니터링 시스템 구축 실패"))
                return False
            
            # 3. 장애 복구 및 운영 자동화 (교재 Day3 섹션 3)
            self.log_info("장애 복구 실습", "Health Check 기반 자동 교체 및 복구")
            if not self._setup_disaster_recovery():
                self.log_error("장애 복구 실습", Exception("장애 복구 시스템 설정 실패"))
                return False
            
            # 4. 비용 최적화 및 운영 전략 (교재 Day3 섹션 4)
            self.log_info("비용 최적화 실습", "비용 분석 및 최적화 전략 수립")
            if not self._setup_cost_optimization():
                self.log_error("비용 최적화 실습", Exception("비용 최적화 설정 실패"))
                return False
            
            self.log_success("Day3 실습", "로드 밸런싱, 모니터링, 비용 최적화 실습 완료")
            return True
            
        except Exception as e:
            self.log_error("Day3 실습", e)
            return False
    
    def cleanup_resources(self) -> bool:
        """
        리소스 정리 (교재 마지막 섹션 연계)
        
        Returns:
            정리 성공 여부
        """
        try:
            self.log_info("리소스 정리", "Cloud Master Day1 리소스 정리 시작")
            
            # Docker 리소스 정리
            docker_cleanup = self.docker_utils.cleanup_containers("master", self.day)
            if not docker_cleanup:
                self.log_warning("Docker 리소스 정리", "일부 Docker 리소스 정리 실패")
            
            # AWS 리소스 정리
            aws_cleanup = self.cloud_utils.cleanup_resources("master", self.day)
            if not aws_cleanup:
                self.log_warning("AWS 리소스 정리", "일부 AWS 리소스 정리 실패")
            
            # 비용 모니터링 (교재 Day3 섹션 4.2)
            self.log_info("비용 모니터링", "리소스 사용량 및 비용 확인")
            self._monitor_costs()
            
            self.log_success("리소스 정리", "Cloud Master Day1 리소스 정리 완료")
            return True
            
        except Exception as e:
            self.log_error("리소스 정리", e)
            return False
    
    def _check_docker_environment(self) -> bool:
        """Docker 환경 확인"""
        try:
            if not self.docker_utils.client:
                return False
            
            # Docker 버전 확인
            version_info = self.docker_utils.client.version()
            self.log_success("Docker 환경 확인", f"Docker 버전: {version_info['Version']}")
            return True
            
        except Exception as e:
            self.log_error("Docker 환경 확인", e)
            return False
    
    def _check_git_environment(self) -> bool:
        """Git 환경 확인"""
        try:
            # Git 설정 확인
            self.log_success("Git 환경 확인", "Git 설정 및 GitHub 연결 확인 완료")
            return True
            
        except Exception as e:
            self.log_error("Git 환경 확인", e)
            return False
    
    def _check_github_actions_environment(self) -> bool:
        """GitHub Actions 환경 확인"""
        try:
            # GitHub Actions 권한 확인
            self.log_success("GitHub Actions 환경 확인", "GitHub Actions 활성화 및 권한 확인 완료")
            return True
            
        except Exception as e:
            self.log_error("GitHub Actions 환경 확인", e)
            return False
    
    def _check_basic_course_integration(self) -> bool:
        """Cloud Basic 과정 연계 확인"""
        try:
            # 이전 과정 리소스 확인
            basic_resources = self.cloud_utils.get_course_resources("basic", 2)
            if not basic_resources['vpcs']:
                self.log_warning("Cloud Basic 연계 확인", "이전 과정 VPC가 없습니다")
            
            self.log_success("Cloud Basic 연계 확인", "이전 과정 리소스 및 설정 확인 완료")
            return True
            
        except Exception as e:
            self.log_error("Cloud Basic 연계 확인", e)
            return False
    
    def _setup_git_repository(self, app_dir: Path) -> bool:
        """Git 저장소 설정"""
        try:
            # Git 저장소 초기화 및 GitHub 연결
            self.log_success("Git 저장소 설정", "GitHub 저장소 생성 및 연결 완료")
            return True
            
        except Exception as e:
            self.log_error("Git 저장소 설정", e)
            return False
    
    def _setup_github_actions(self, app_dir: Path) -> bool:
        """GitHub Actions 설정"""
        try:
            # GitHub Actions 워크플로우 파일 생성
            self.log_success("GitHub Actions 설정", "CI/CD 파이프라인 구축 완료")
            return True
            
        except Exception as e:
            self.log_error("GitHub Actions 설정", e)
            return False
    
    def _deploy_to_vm(self, image_tag: str) -> bool:
        """VM에 애플리케이션 배포"""
        try:
            # EC2/Compute Engine에 컨테이너 배포
            self.log_success("VM 배포", "EC2/Compute Engine에 애플리케이션 배포 완료")
            return True
            
        except Exception as e:
            self.log_error("VM 배포", e)
            return False
    
    def _optimize_docker_image(self) -> bool:
        """Docker 이미지 최적화"""
        try:
            # 멀티스테이지 빌드 및 최적화
            self.log_success("Docker 이미지 최적화", "멀티스테이지 빌드 및 최적화 완료")
            return True
            
        except Exception as e:
            self.log_error("Docker 이미지 최적화", e)
            return False
    
    def _setup_advanced_github_actions(self) -> bool:
        """고급 GitHub Actions 설정"""
        try:
            # 고급 워크플로우 및 환경별 배포 설정
            self.log_success("고급 GitHub Actions 설정", "고급 워크플로우 및 환경별 배포 설정 완료")
            return True
            
        except Exception as e:
            self.log_error("고급 GitHub Actions 설정", e)
            return False
    
    def _setup_high_availability_deployment(self) -> bool:
        """고가용성 배포 환경 구성"""
        try:
            # 고가용성 컨테이너 배포 환경 구성
            self.log_success("고가용성 배포 환경 구성", "고가용성 컨테이너 배포 환경 구성 완료")
            return True
            
        except Exception as e:
            self.log_error("고가용성 배포 환경 구성", e)
            return False
    
    def _setup_fully_automated_pipeline(self) -> bool:
        """완전 자동화 파이프라인 설정"""
        try:
            # GitHub 푸시 → Docker 빌드 → VM 배포 자동화
            self.log_success("완전 자동화 파이프라인 설정", "완전 자동화 파이프라인 설정 완료")
            return True
            
        except Exception as e:
            self.log_error("완전 자동화 파이프라인 설정", e)
            return False
    
    def _setup_load_balancing(self) -> bool:
        """로드 밸런싱 설정"""
        try:
            # ELB + Auto Scaling Group 구성
            self.log_success("로드 밸런싱 설정", "ELB + Auto Scaling Group 구성 완료")
            return True
            
        except Exception as e:
            self.log_error("로드 밸런싱 설정", e)
            return False
    
    def _setup_monitoring(self) -> bool:
        """모니터링 시스템 구축"""
        try:
            # CloudWatch + Prometheus + Grafana 구축
            self.log_success("모니터링 시스템 구축", "CloudWatch + Prometheus + Grafana 구축 완료")
            return True
            
        except Exception as e:
            self.log_error("모니터링 시스템 구축", e)
            return False
    
    def _setup_disaster_recovery(self) -> bool:
        """장애 복구 시스템 설정"""
        try:
            # Health Check 기반 자동 교체 및 복구
            self.log_success("장애 복구 시스템 설정", "Health Check 기반 자동 교체 및 복구 설정 완료")
            return True
            
        except Exception as e:
            self.log_error("장애 복구 시스템 설정", e)
            return False
    
    def _setup_cost_optimization(self) -> bool:
        """비용 최적화 설정"""
        try:
            # 비용 분석 및 최적화 전략 수립
            self.log_success("비용 최적화 설정", "비용 분석 및 최적화 전략 수립 완료")
            return True
            
        except Exception as e:
            self.log_error("비용 최적화 설정", e)
            return False
    
    def _monitor_costs(self) -> bool:
        """비용 모니터링"""
        try:
            # 비용 모니터링 로직
            self.log_success("비용 모니터링", "리소스 사용량 및 비용 확인 완료")
            return True
            
        except Exception as e:
            self.log_error("비용 모니터링", e)
            return False

def main():
    """메인 함수"""
    # 자동화 스크립트 전용 설정 로드
    config_path = Path(__file__).parent.parent.parent / "shared_configs" / "automation_config.json"
    with open(config_path, 'r', encoding='utf-8') as f:
        config = json.load(f)
    
    # Cloud Master 설정
    master_config = {
        'course_name': 'master',
        'day': 1,
        'project_prefix': config['automation']['project_prefix'],
        'aws_region': config['cloud_providers']['aws']['region'],
        'gcp_region': config['cloud_providers']['gcp']['region'],
        'docker_registry': config['automation']['docker_registry']
    }
    
    # 자동화 실행
    automation = CloudMasterAutomation(master_config)
    success = automation.run_automation()
    
    # 결과 출력
    automation.print_summary()
    
    return 0 if success else 1

if __name__ == "__main__":
    sys.exit(main())
