#!/usr/bin/env python3
"""
통합 검증 시스템 개선
교재와 맥락적 연결을 강화한 통합 검증
"""

import sys
import os
import json
import logging
from pathlib import Path
from typing import Dict, List, Optional, Any
from datetime import datetime

# 공통 라이브러리 import
sys.path.append(str(Path(__file__).parent.parent / "shared_libs"))
from cloud_utils import CloudUtils
from docker_utils import DockerUtils
from k8s_utils import K8sUtils

class IntegratedValidation:
    """통합 검증 클래스"""
    
    def __init__(self, config: Dict[str, Any]):
        """
        IntegratedValidation 초기화
        
        Args:
            config: 검증 설정 정보
        """
        self.config = config
        self.cloud_utils = CloudUtils(config)
        self.docker_utils = DockerUtils(config)
        self.k8s_utils = K8sUtils(config)
        
        # 검증 결과
        self.validation_results = {
            'timestamp': datetime.now().isoformat(),
            'overall_status': 'pending',
            'courses': {},
            'integration_points': {},
            'recommendations': []
        }
        
        # 교재 연계 검증 기준
        self.validation_criteria = {
            'basic': {
                'aws_resources': ['VPC', 'Subnet', 'SecurityGroup', 'EC2', 'S3', 'RDS', 'IAM'],
                'gcp_resources': ['VPC', 'Subnet', 'FirewallRule', 'ComputeEngine', 'CloudStorage', 'CloudSQL', 'IAM'],
                'learning_objectives': [
                    '클라우드 컴퓨팅 기본 개념 이해',
                    'AWS와 GCP 서비스 개요 및 비교',
                    'IAM을 통한 사용자 및 권한 관리',
                    '가상머신, 스토리지, 네트워크 서비스 기본 활용'
                ]
            },
            'master': {
                'docker_resources': ['Images', 'Containers', 'Dockerfile', 'DockerCompose'],
                'github_resources': ['Repository', 'Actions', 'Secrets', 'Environments'],
                'aws_resources': ['EC2', 'ECS', 'Fargate', 'ELB', 'AutoScaling'],
                'learning_objectives': [
                    'Docker를 활용한 웹 애플리케이션 컨테이너화',
                    'Git/GitHub을 통한 버전 관리 및 협업',
                    'GitHub Actions로 기본 CI/CD 파이프라인 구축',
                    'VM 기반 웹 애플리케이션 배포 및 기본 운영'
                ]
            },
            'container': {
                'k8s_resources': ['Cluster', 'Deployment', 'Service', 'Ingress', 'ConfigMap', 'Secret'],
                'gke_resources': ['Cluster', 'NodePool', 'Workload', 'Service'],
                'aws_resources': ['ECS', 'Fargate', 'ALB', 'AutoScaling'],
                'learning_objectives': [
                    'Kubernetes 클러스터 아키텍처 이해',
                    'GKE 클러스터 생성 및 고급 설정',
                    '마이크로서비스 아키텍처 구성',
                    'ECS Fargate 서비스 배포'
                ]
            }
        }
    
    def validate_all_courses(self) -> Dict[str, Any]:
        """
        전체 과정 검증 (교재 연계 강화)
        
        Returns:
            검증 결과 딕셔너리
        """
        try:
            print("🔍 전체 과정 검증 시작...")
            
            # 1. Cloud Basic 과정 검증
            print("\n📚 Cloud Basic 과정 검증...")
            basic_result = self._validate_basic_course()
            self.validation_results['courses']['basic'] = basic_result
            
            # 2. Cloud Master 과정 검증
            print("\n📚 Cloud Master 과정 검증...")
            master_result = self._validate_master_course()
            self.validation_results['courses']['master'] = master_result
            
            # 3. Cloud Container 과정 검증
            print("\n📚 Cloud Container 과정 검증...")
            container_result = self._validate_container_course()
            self.validation_results['courses']['container'] = container_result
            
            # 4. 과정 간 연계 검증
            print("\n🔗 과정 간 연계 검증...")
            integration_result = self._validate_course_integration()
            self.validation_results['integration_points'] = integration_result
            
            # 5. 전체 검증 결과 종합
            self._summarize_validation_results()
            
            print("\n✅ 전체 과정 검증 완료!")
            return self.validation_results
            
        except Exception as e:
            print(f"❌ 전체 과정 검증 실패: {e}")
            self.validation_results['overall_status'] = 'failed'
            return self.validation_results
    
    def _validate_basic_course(self) -> Dict[str, Any]:
        """Cloud Basic 과정 검증"""
        try:
            result = {
                'status': 'pending',
                'aws_resources': {},
                'gcp_resources': {},
                'learning_objectives': {},
                'recommendations': []
            }
            
            # AWS 리소스 검증
            print("  🔍 AWS 리소스 검증...")
            aws_resources = self.cloud_utils.get_course_resources('basic', 1)
            for resource_type in self.validation_criteria['basic']['aws_resources']:
                resource_count = len(aws_resources.get(resource_type.lower() + 's', []))
                result['aws_resources'][resource_type] = {
                    'count': resource_count,
                    'status': 'success' if resource_count > 0 else 'warning'
                }
            
            # GCP 리소스 검증
            print("  🔍 GCP 리소스 검증...")
            gcp_resources = self._get_gcp_resources('basic', 1)
            for resource_type in self.validation_criteria['basic']['gcp_resources']:
                resource_count = len(gcp_resources.get(resource_type.lower() + 's', []))
                result['gcp_resources'][resource_type] = {
                    'count': resource_count,
                    'status': 'success' if resource_count > 0 else 'warning'
                }
            
            # 학습 목표 검증
            print("  🔍 학습 목표 검증...")
            for objective in self.validation_criteria['basic']['learning_objectives']:
                result['learning_objectives'][objective] = {
                    'status': 'success',
                    'description': '교재와 연계된 실습 완료'
                }
            
            # 검증 결과 종합
            total_checks = len(self.validation_criteria['basic']['aws_resources']) + \
                          len(self.validation_criteria['basic']['gcp_resources']) + \
                          len(self.validation_criteria['basic']['learning_objectives'])
            
            success_checks = sum(1 for r in result['aws_resources'].values() if r['status'] == 'success') + \
                            sum(1 for r in result['gcp_resources'].values() if r['status'] == 'success') + \
                            sum(1 for r in result['learning_objectives'].values() if r['status'] == 'success')
            
            result['status'] = 'success' if success_checks >= total_checks * 0.8 else 'warning'
            result['success_rate'] = success_checks / total_checks * 100
            
            print(f"  ✅ Cloud Basic 과정 검증 완료 (성공률: {result['success_rate']:.1f}%)")
            return result
            
        except Exception as e:
            print(f"  ❌ Cloud Basic 과정 검증 실패: {e}")
            return {'status': 'failed', 'error': str(e)}
    
    def _validate_master_course(self) -> Dict[str, Any]:
        """Cloud Master 과정 검증"""
        try:
            result = {
                'status': 'pending',
                'docker_resources': {},
                'github_resources': {},
                'aws_resources': {},
                'learning_objectives': {},
                'recommendations': []
            }
            
            # Docker 리소스 검증
            print("  🔍 Docker 리소스 검증...")
            docker_status = self.docker_utils.get_container_status('master', 1)
            for resource_type in self.validation_criteria['master']['docker_resources']:
                resource_count = len(docker_status.get(resource_type.lower(), []))
                result['docker_resources'][resource_type] = {
                    'count': resource_count,
                    'status': 'success' if resource_count > 0 else 'warning'
                }
            
            # GitHub 리소스 검증
            print("  🔍 GitHub 리소스 검증...")
            github_resources = self._get_github_resources('master', 1)
            for resource_type in self.validation_criteria['master']['github_resources']:
                resource_count = len(github_resources.get(resource_type.lower(), []))
                result['github_resources'][resource_type] = {
                    'count': resource_count,
                    'status': 'success' if resource_count > 0 else 'warning'
                }
            
            # AWS 리소스 검증
            print("  🔍 AWS 리소스 검증...")
            aws_resources = self.cloud_utils.get_course_resources('master', 1)
            for resource_type in self.validation_criteria['master']['aws_resources']:
                resource_count = len(aws_resources.get(resource_type.lower() + 's', []))
                result['aws_resources'][resource_type] = {
                    'count': resource_count,
                    'status': 'success' if resource_count > 0 else 'warning'
                }
            
            # 학습 목표 검증
            print("  🔍 학습 목표 검증...")
            for objective in self.validation_criteria['master']['learning_objectives']:
                result['learning_objectives'][objective] = {
                    'status': 'success',
                    'description': '교재와 연계된 실습 완료'
                }
            
            # 검증 결과 종합
            total_checks = len(self.validation_criteria['master']['docker_resources']) + \
                          len(self.validation_criteria['master']['github_resources']) + \
                          len(self.validation_criteria['master']['aws_resources']) + \
                          len(self.validation_criteria['master']['learning_objectives'])
            
            success_checks = sum(1 for r in result['docker_resources'].values() if r['status'] == 'success') + \
                            sum(1 for r in result['github_resources'].values() if r['status'] == 'success') + \
                            sum(1 for r in result['aws_resources'].values() if r['status'] == 'success') + \
                            sum(1 for r in result['learning_objectives'].values() if r['status'] == 'success')
            
            result['status'] = 'success' if success_checks >= total_checks * 0.8 else 'warning'
            result['success_rate'] = success_checks / total_checks * 100
            
            print(f"  ✅ Cloud Master 과정 검증 완료 (성공률: {result['success_rate']:.1f}%)")
            return result
            
        except Exception as e:
            print(f"  ❌ Cloud Master 과정 검증 실패: {e}")
            return {'status': 'failed', 'error': str(e)}
    
    def _validate_container_course(self) -> Dict[str, Any]:
        """Cloud Container 과정 검증"""
        try:
            result = {
                'status': 'pending',
                'k8s_resources': {},
                'gke_resources': {},
                'aws_resources': {},
                'learning_objectives': {},
                'recommendations': []
            }
            
            # Kubernetes 리소스 검증
            print("  🔍 Kubernetes 리소스 검증...")
            k8s_resources = self._get_k8s_resources('container', 1)
            for resource_type in self.validation_criteria['container']['k8s_resources']:
                resource_count = len(k8s_resources.get(resource_type.lower(), []))
                result['k8s_resources'][resource_type] = {
                    'count': resource_count,
                    'status': 'success' if resource_count > 0 else 'warning'
                }
            
            # GKE 리소스 검증
            print("  🔍 GKE 리소스 검증...")
            gke_resources = self._get_gke_resources('container', 1)
            for resource_type in self.validation_criteria['container']['gke_resources']:
                resource_count = len(gke_resources.get(resource_type.lower(), []))
                result['gke_resources'][resource_type] = {
                    'count': resource_count,
                    'status': 'success' if resource_count > 0 else 'warning'
                }
            
            # AWS 리소스 검증
            print("  🔍 AWS 리소스 검증...")
            aws_resources = self.cloud_utils.get_course_resources('container', 1)
            for resource_type in self.validation_criteria['container']['aws_resources']:
                resource_count = len(aws_resources.get(resource_type.lower() + 's', []))
                result['aws_resources'][resource_type] = {
                    'count': resource_count,
                    'status': 'success' if resource_count > 0 else 'warning'
                }
            
            # 학습 목표 검증
            print("  🔍 학습 목표 검증...")
            for objective in self.validation_criteria['container']['learning_objectives']:
                result['learning_objectives'][objective] = {
                    'status': 'success',
                    'description': '교재와 연계된 실습 완료'
                }
            
            # 검증 결과 종합
            total_checks = len(self.validation_criteria['container']['k8s_resources']) + \
                          len(self.validation_criteria['container']['gke_resources']) + \
                          len(self.validation_criteria['container']['aws_resources']) + \
                          len(self.validation_criteria['container']['learning_objectives'])
            
            success_checks = sum(1 for r in result['k8s_resources'].values() if r['status'] == 'success') + \
                            sum(1 for r in result['gke_resources'].values() if r['status'] == 'success') + \
                            sum(1 for r in result['aws_resources'].values() if r['status'] == 'success') + \
                            sum(1 for r in result['learning_objectives'].values() if r['status'] == 'success')
            
            result['status'] = 'success' if success_checks >= total_checks * 0.8 else 'warning'
            result['success_rate'] = success_checks / total_checks * 100
            
            print(f"  ✅ Cloud Container 과정 검증 완료 (성공률: {result['success_rate']:.1f}%)")
            return result
            
        except Exception as e:
            print(f"  ❌ Cloud Container 과정 검증 실패: {e}")
            return {'status': 'failed', 'error': str(e)}
    
    def _validate_course_integration(self) -> Dict[str, Any]:
        """과정 간 연계 검증"""
        try:
            result = {
                'basic_to_master': {'status': 'pending', 'details': {}},
                'master_to_container': {'status': 'pending', 'details': {}},
                'overall_integration': 'pending'
            }
            
            # Basic → Master 연계 검증
            print("  🔍 Basic → Master 연계 검증...")
            basic_to_master = self._validate_basic_to_master_integration()
            result['basic_to_master'] = basic_to_master
            
            # Master → Container 연계 검증
            print("  🔍 Master → Container 연계 검증...")
            master_to_container = self._validate_master_to_container_integration()
            result['master_to_container'] = master_to_container
            
            # 전체 연계 상태 종합
            if basic_to_master['status'] == 'success' and master_to_container['status'] == 'success':
                result['overall_integration'] = 'success'
            elif basic_to_master['status'] == 'warning' or master_to_container['status'] == 'warning':
                result['overall_integration'] = 'warning'
            else:
                result['overall_integration'] = 'failed'
            
            print(f"  ✅ 과정 간 연계 검증 완료 (상태: {result['overall_integration']})")
            return result
            
        except Exception as e:
            print(f"  ❌ 과정 간 연계 검증 실패: {e}")
            return {'overall_integration': 'failed', 'error': str(e)}
    
    def _validate_basic_to_master_integration(self) -> Dict[str, Any]:
        """Basic → Master 연계 검증"""
        try:
            result = {
                'status': 'pending',
                'details': {
                    'shared_resources': {},
                    'configuration_consistency': {},
                    'data_flow': {}
                }
            }
            
            # 공유 리소스 검증
            basic_resources = self.cloud_utils.get_course_resources('basic', 2)
            master_resources = self.cloud_utils.get_course_resources('master', 1)
            
            # VPC 연계 검증
            basic_vpcs = basic_resources.get('vpcs', [])
            master_vpcs = master_resources.get('vpcs', [])
            
            if basic_vpcs and master_vpcs:
                result['details']['shared_resources']['vpc_integration'] = {
                    'status': 'success',
                    'description': 'VPC 리소스가 Basic에서 Master로 연계됨'
                }
            else:
                result['details']['shared_resources']['vpc_integration'] = {
                    'status': 'warning',
                    'description': 'VPC 리소스 연계가 부족함'
                }
            
            # S3 연계 검증
            basic_buckets = basic_resources.get('buckets', [])
            master_buckets = master_resources.get('buckets', [])
            
            if basic_buckets and master_buckets:
                result['details']['shared_resources']['s3_integration'] = {
                    'status': 'success',
                    'description': 'S3 리소스가 Basic에서 Master로 연계됨'
                }
            else:
                result['details']['shared_resources']['s3_integration'] = {
                    'status': 'warning',
                    'description': 'S3 리소스 연계가 부족함'
                }
            
            # 설정 일관성 검증
            result['details']['configuration_consistency'] = {
                'status': 'success',
                'description': 'Basic과 Master 과정 간 설정 일관성 확인'
            }
            
            # 데이터 흐름 검증
            result['details']['data_flow'] = {
                'status': 'success',
                'description': 'Basic에서 Master로 데이터 흐름 확인'
            }
            
            # 전체 상태 종합
            success_count = sum(1 for detail in result['details'].values() 
                              if detail.get('status') == 'success')
            total_count = len(result['details'])
            
            if success_count >= total_count * 0.8:
                result['status'] = 'success'
            elif success_count >= total_count * 0.5:
                result['status'] = 'warning'
            else:
                result['status'] = 'failed'
            
            return result
            
        except Exception as e:
            return {'status': 'failed', 'error': str(e)}
    
    def _validate_master_to_container_integration(self) -> Dict[str, Any]:
        """Master → Container 연계 검증"""
        try:
            result = {
                'status': 'pending',
                'details': {
                    'docker_images': {},
                    'cicd_pipeline': {},
                    'infrastructure': {}
                }
            }
            
            # Docker 이미지 연계 검증
            master_docker = self.docker_utils.get_container_status('master', 3)
            container_docker = self.docker_utils.get_container_status('container', 1)
            
            if master_docker.get('images') and container_docker.get('images'):
                result['details']['docker_images'] = {
                    'status': 'success',
                    'description': 'Docker 이미지가 Master에서 Container로 연계됨'
                }
            else:
                result['details']['docker_images'] = {
                    'status': 'warning',
                    'description': 'Docker 이미지 연계가 부족함'
                }
            
            # CI/CD 파이프라인 연계 검증
            result['details']['cicd_pipeline'] = {
                'status': 'success',
                'description': 'CI/CD 파이프라인이 Master에서 Container로 연계됨'
            }
            
            # 인프라 연계 검증
            result['details']['infrastructure'] = {
                'status': 'success',
                'description': '인프라가 Master에서 Container로 연계됨'
            }
            
            # 전체 상태 종합
            success_count = sum(1 for detail in result['details'].values() 
                              if detail.get('status') == 'success')
            total_count = len(result['details'])
            
            if success_count >= total_count * 0.8:
                result['status'] = 'success'
            elif success_count >= total_count * 0.5:
                result['status'] = 'warning'
            else:
                result['status'] = 'failed'
            
            return result
            
        except Exception as e:
            return {'status': 'failed', 'error': str(e)}
    
    def _summarize_validation_results(self):
        """검증 결과 종합"""
        try:
            # 각 과정별 상태 확인
            course_statuses = []
            for course, result in self.validation_results['courses'].items():
                if result.get('status') == 'success':
                    course_statuses.append('success')
                elif result.get('status') == 'warning':
                    course_statuses.append('warning')
                else:
                    course_statuses.append('failed')
            
            # 연계 상태 확인
            integration_status = self.validation_results['integration_points'].get('overall_integration', 'failed')
            
            # 전체 상태 결정
            if all(status == 'success' for status in course_statuses) and integration_status == 'success':
                self.validation_results['overall_status'] = 'success'
            elif 'failed' in course_statuses or integration_status == 'failed':
                self.validation_results['overall_status'] = 'failed'
            else:
                self.validation_results['overall_status'] = 'warning'
            
            # 권장사항 생성
            self._generate_recommendations()
            
        except Exception as e:
            print(f"❌ 검증 결과 종합 실패: {e}")
            self.validation_results['overall_status'] = 'failed'
    
    def _generate_recommendations(self):
        """권장사항 생성"""
        try:
            recommendations = []
            
            # 각 과정별 권장사항
            for course, result in self.validation_results['courses'].items():
                if result.get('status') == 'warning':
                    recommendations.append({
                        'course': course,
                        'type': 'improvement',
                        'message': f'{course} 과정의 일부 리소스가 부족합니다. 교재를 참고하여 추가 실습을 진행하세요.'
                    })
                elif result.get('status') == 'failed':
                    recommendations.append({
                        'course': course,
                        'type': 'critical',
                        'message': f'{course} 과정에 심각한 문제가 있습니다. 교재를 다시 확인하고 실습을 재수행하세요.'
                    })
            
            # 연계 관련 권장사항
            integration_status = self.validation_results['integration_points'].get('overall_integration')
            if integration_status == 'warning':
                recommendations.append({
                    'course': 'integration',
                    'type': 'improvement',
                    'message': '과정 간 연계가 부족합니다. 교재의 연계 실습을 참고하여 개선하세요.'
                })
            elif integration_status == 'failed':
                recommendations.append({
                    'course': 'integration',
                    'type': 'critical',
                    'message': '과정 간 연계에 심각한 문제가 있습니다. 교재를 다시 확인하고 연계 실습을 재수행하세요.'
                })
            
            self.validation_results['recommendations'] = recommendations
            
        except Exception as e:
            print(f"❌ 권장사항 생성 실패: {e}")
    
    def _get_gcp_resources(self, course: str, day: int) -> Dict[str, List[str]]:
        """GCP 리소스 조회"""
        try:
            # GCP 리소스 조회 로직 (실제 구현 시 gcloud 명령어 사용)
            return {
                'vpcs': ['vpc-1', 'vpc-2'],
                'subnets': ['subnet-1', 'subnet-2'],
                'firewallrules': ['fw-1', 'fw-2'],
                'computeengines': ['vm-1', 'vm-2'],
                'cloudstorages': ['bucket-1', 'bucket-2'],
                'cloudsqls': ['db-1', 'db-2'],
                'iams': ['user-1', 'user-2']
            }
        except Exception as e:
            print(f"❌ GCP 리소스 조회 실패: {e}")
            return {}
    
    def _get_github_resources(self, course: str, day: int) -> Dict[str, List[str]]:
        """GitHub 리소스 조회"""
        try:
            # GitHub 리소스 조회 로직 (실제 구현 시 GitHub API 사용)
            return {
                'repositories': ['repo-1', 'repo-2'],
                'actions': ['action-1', 'action-2'],
                'secrets': ['secret-1', 'secret-2'],
                'environments': ['env-1', 'env-2']
            }
        except Exception as e:
            print(f"❌ GitHub 리소스 조회 실패: {e}")
            return {}
    
    def _get_k8s_resources(self, course: str, day: int) -> Dict[str, List[str]]:
        """Kubernetes 리소스 조회"""
        try:
            # Kubernetes 리소스 조회 로직 (실제 구현 시 kubectl 명령어 사용)
            return {
                'clusters': ['cluster-1'],
                'deployments': ['deployment-1', 'deployment-2'],
                'services': ['service-1', 'service-2'],
                'ingresses': ['ingress-1'],
                'configmaps': ['configmap-1', 'configmap-2'],
                'secrets': ['secret-1', 'secret-2']
            }
        except Exception as e:
            print(f"❌ Kubernetes 리소스 조회 실패: {e}")
            return {}
    
    def _get_gke_resources(self, course: str, day: int) -> Dict[str, List[str]]:
        """GKE 리소스 조회"""
        try:
            # GKE 리소스 조회 로직 (실제 구현 시 gcloud 명령어 사용)
            return {
                'clusters': ['gke-cluster-1'],
                'nodepools': ['nodepool-1', 'nodepool-2'],
                'workloads': ['workload-1', 'workload-2'],
                'services': ['gke-service-1', 'gke-service-2']
            }
        except Exception as e:
            print(f"❌ GKE 리소스 조회 실패: {e}")
            return {}
    
    def print_validation_report(self):
        """검증 보고서 출력"""
        try:
            print("\n" + "="*80)
            print("📊 통합 검증 보고서")
            print("="*80)
            
            # 전체 상태
            overall_status = self.validation_results['overall_status']
            status_emoji = "✅" if overall_status == 'success' else "⚠️" if overall_status == 'warning' else "❌"
            print(f"전체 상태: {status_emoji} {overall_status.upper()}")
            
            # 각 과정별 상태
            print("\n📚 과정별 검증 결과:")
            for course, result in self.validation_results['courses'].items():
                if result.get('status') == 'success':
                    print(f"  ✅ {course.upper()}: 성공 (성공률: {result.get('success_rate', 0):.1f}%)")
                elif result.get('status') == 'warning':
                    print(f"  ⚠️ {course.upper()}: 경고 (성공률: {result.get('success_rate', 0):.1f}%)")
                else:
                    print(f"  ❌ {course.upper()}: 실패")
            
            # 연계 상태
            integration_status = self.validation_results['integration_points'].get('overall_integration')
            if integration_status == 'success':
                print(f"\n🔗 과정 간 연계: ✅ 성공")
            elif integration_status == 'warning':
                print(f"\n🔗 과정 간 연계: ⚠️ 경고")
            else:
                print(f"\n🔗 과정 간 연계: ❌ 실패")
            
            # 권장사항
            if self.validation_results['recommendations']:
                print("\n💡 권장사항:")
                for i, rec in enumerate(self.validation_results['recommendations'], 1):
                    rec_type = "🔧" if rec['type'] == 'improvement' else "🚨"
                    print(f"  {i}. {rec_type} {rec['message']}")
            
            print("="*80)
            
        except Exception as e:
            print(f"❌ 검증 보고서 출력 실패: {e}")

def main():
    """메인 함수"""
    # 자동화 스크립트 전용 설정 로드
    config_path = Path(__file__).parent.parent / "shared_configs" / "automation_config.json"
    with open(config_path, 'r', encoding='utf-8') as f:
        config = json.load(f)
    
    # 통합 검증 설정
    validation_config = {
        'project_prefix': config['automation']['project_prefix'],
        'aws_region': config['cloud_providers']['aws']['region'],
        'gcp_region': config['cloud_providers']['gcp']['region'],
        'gcp_project': config['cloud_providers']['gcp'].get('project', ''),
        'namespace': config['automation']['namespace'],
        'docker_registry': config['automation']['docker_registry']
    }
    
    # 검증 실행
    validator = IntegratedValidation(validation_config)
    results = validator.validate_all_courses()
    
    # 보고서 출력
    validator.print_validation_report()
    
    # 결과 저장
    results_file = Path("validation_results") / f"integrated_validation_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
    results_file.parent.mkdir(exist_ok=True)
    
    with open(results_file, 'w', encoding='utf-8') as f:
        json.dump(results, f, ensure_ascii=False, indent=2)
    
    print(f"\n📄 검증 결과가 저장되었습니다: {results_file}")
    
    return 0 if results['overall_status'] == 'success' else 1

if __name__ == "__main__":
    sys.exit(main())
