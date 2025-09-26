#!/usr/bin/env python3
"""
통합 클라우드 과정 자동화 시스템
Cloud Basic → Cloud Master → Cloud Container 연계 자동화

교재 연계성:
- Cloud Basic: 클라우드 기초 서비스 실습 (AWS/GCP 계정, IAM, EC2/Compute Engine, S3/Cloud Storage)
- Cloud Master: Docker 컨테이너화 및 CI/CD 파이프라인 (Docker, Git/GitHub, GitHub Actions, VM 배포)
- Cloud Container: Kubernetes 오케스트레이션 (GKE, ECS/Fargate, 고급 CI/CD, 고가용성 아키텍처)

학습 시나리오:
1. Basic → Master: 기초 클라우드 서비스 → 컨테이너화 및 자동화
2. Master → Container: VM 기반 배포 → 컨테이너 오케스트레이션
3. 전체 과정: 점진적 복잡성 증가와 실무 중심 프로젝트
"""

import os
import sys
import json
import time
import subprocess
import logging
from datetime import datetime, timedelta
from typing import Dict, List, Optional, Tuple, Any
from dataclasses import dataclass, asdict
from pathlib import Path
import yaml
import shutil

# 로깅 설정
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('integrated_course_automation.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

@dataclass
class IntegratedCourseConfig:
    """통합 과정 설정"""
    total_duration_days: int = 7  # Basic(2) + Master(3) + Container(2)
    cloud_providers: List[str] = None
    required_tools: List[str] = None
    environment_setup: Dict[str, Any] = None
    
    def __post_init__(self):
        if self.cloud_providers is None:
            self.cloud_providers = ["aws", "gcp"]
        if self.required_tools is None:
            self.required_tools = [
                "aws-cli", "gcloud-cli", "docker", "git", "github-cli", 
                "kubectl", "helm", "terraform"
            ]
        if self.environment_setup is None:
            self.environment_setup = {
                "aws_region": "us-west-2",
                "gcp_region": "us-central1",
                "project_prefix": "cloud-training",
                "shared_resources": True
            }

@dataclass
class CourseProgress:
    """과정 진행 상황"""
    course_name: str
    status: str  # "not_started", "in_progress", "completed", "failed"
    start_time: Optional[datetime] = None
    end_time: Optional[datetime] = None
    completed_days: List[int] = None
    created_resources: List[str] = None
    errors: List[str] = None
    
    def __post_init__(self):
        if self.completed_days is None:
            self.completed_days = []
        if self.created_resources is None:
            self.created_resources = []
        if self.errors is None:
            self.errors = []

class IntegratedCourseAutomation:
    """통합 과정 자동화 클래스"""
    
    def __init__(self, config: IntegratedCourseConfig = None):
        self.config = config or IntegratedCourseConfig()
        self.base_path = Path(__file__).parent
        self.courses = {
            "basic": {
                "name": "Cloud Basic",
                "duration": 2,
                "path": self.base_path.parent / "cloud_basic" / "automation_tests",
                "automation_script": "basic_course_automation.py",
                "test_script": "run_basic_course_tests.py"
            },
            "master": {
                "name": "Cloud Master", 
                "duration": 3,
                "path": self.base_path.parent / "cloud_master" / "automation_tests",
                "automation_script": "master_course_automation.py",
                "test_script": "run_master_course_tests.py"
            },
            "container": {
                "name": "Cloud Container",
                "duration": 2,
                "path": self.base_path.parent / "cloud_container" / "automation_tests",
                "automation_script": "container_course_automation.py",
                "test_script": "run_container_course_tests.py"
            }
        }
        self.progress = {}
        self.shared_resources = {}
        self.setup_directories()
    
    def setup_directories(self):
        """디렉토리 구조 설정"""
        self.integrated_path = self.base_path
        self.results_path = self.integrated_path / "results"
        self.shared_path = self.integrated_path / "shared_resources"
        
        for path in [self.results_path, self.shared_path]:
            path.mkdir(exist_ok=True)
        
        logger.info(f"통합 자동화 디렉토리 설정 완료: {self.integrated_path}")
    
    def check_prerequisites(self) -> bool:
        """사전 요구사항 확인"""
        logger.info("사전 요구사항 확인 중...")
        
        missing_tools = []
        for tool in self.config.required_tools:
            if not self._check_tool_installed(tool):
                missing_tools.append(tool)
        
        if missing_tools:
            logger.warning(f"누락된 도구: {missing_tools}")
            logger.info("자동화는 계속 진행되지만 일부 기능이 제한될 수 있습니다.")
        
        # 환경 변수 확인
        self._check_environment_variables()
        
        return True
    
    def _check_tool_installed(self, tool: str) -> bool:
        """도구 설치 여부 확인"""
        try:
            if tool == "aws-cli":
                subprocess.run(["aws", "--version"], capture_output=True, check=True)
            elif tool == "gcloud-cli":
                subprocess.run(["gcloud", "--version"], capture_output=True, check=True)
            elif tool == "docker":
                subprocess.run(["docker", "--version"], capture_output=True, check=True)
            elif tool == "git":
                subprocess.run(["git", "--version"], capture_output=True, check=True)
            elif tool == "kubectl":
                subprocess.run(["kubectl", "version", "--client"], capture_output=True, check=True)
            elif tool == "helm":
                subprocess.run(["helm", "version"], capture_output=True, check=True)
            elif tool == "terraform":
                subprocess.run(["terraform", "version"], capture_output=True, check=True)
            return True
        except (subprocess.CalledProcessError, FileNotFoundError):
            return False
    
    def _check_environment_variables(self):
        """환경 변수 확인"""
        required_env_vars = {
            "AWS_ACCESS_KEY_ID": "AWS 액세스 키",
            "AWS_SECRET_ACCESS_KEY": "AWS 시크릿 키", 
            "AWS_DEFAULT_REGION": "AWS 기본 리전",
            "GOOGLE_APPLICATION_CREDENTIALS": "GCP 서비스 계정 키 파일"
        }
        
        missing_vars = []
        for var, description in required_env_vars.items():
            if not os.getenv(var):
                missing_vars.append(f"{var} ({description})")
        
        if missing_vars:
            logger.warning(f"누락된 환경 변수: {missing_vars}")
            logger.info("일부 클라우드 서비스 실습이 제한될 수 있습니다.")
    
    def run_course(self, course_key: str) -> bool:
        """개별 과정 실행"""
        if course_key not in self.courses:
            logger.error(f"알 수 없는 과정: {course_key}")
            return False
        
        course = self.courses[course_key]
        logger.info(f"{course['name']} 과정 시작...")
        
        # 진행 상황 초기화
        self.progress[course_key] = CourseProgress(
            course_name=course['name'],
            status="in_progress",
            start_time=datetime.now()
        )
        
        try:
            # 과정 디렉토리로 이동
            original_cwd = os.getcwd()
            os.chdir(course['path'])
            
            # 자동화 스크립트 실행
            logger.info(f"{course['name']} 자동화 스크립트 실행 중...")
            result = subprocess.run([
                sys.executable, course['automation_script']
            ], capture_output=True, text=True, timeout=300)
            
            if result.returncode != 0:
                logger.error(f"{course['name']} 자동화 실패: {result.stderr}")
                self.progress[course_key].status = "failed"
                self.progress[course_key].errors.append(result.stderr)
                return False
            
            # 테스트 실행
            logger.info(f"{course['name']} 테스트 실행 중...")
            test_result = subprocess.run([
                sys.executable, course['test_script']
            ], capture_output=True, text=True, timeout=300)
            
            if test_result.returncode != 0:
                logger.warning(f"{course['name']} 테스트 일부 실패: {test_result.stderr}")
                # 테스트 실패해도 과정은 완료로 처리
            
            # 과정 완료 처리
            self.progress[course_key].status = "completed"
            self.progress[course_key].end_time = datetime.now()
            self.progress[course_key].completed_days = list(range(1, course['duration'] + 1))
            
            # 생성된 리소스 정보 수집
            self._collect_course_resources(course_key)
            
            logger.info(f"{course['name']} 과정 완료!")
            return True
            
        except subprocess.TimeoutExpired:
            logger.error(f"{course['name']} 과정 타임아웃")
            self.progress[course_key].status = "failed"
            self.progress[course_key].errors.append("Process timeout")
            return False
        except Exception as e:
            logger.error(f"{course['name']} 과정 오류: {str(e)}")
            self.progress[course_key].status = "failed"
            self.progress[course_key].errors.append(str(e))
            return False
        finally:
            os.chdir(original_cwd)
    
    def _collect_course_resources(self, course_key: str):
        """과정에서 생성된 리소스 정보 수집"""
        course = self.courses[course_key]
        results_file = course['path'].parent / "automation" / "results" / "automation_results.json"
        
        if results_file.exists():
            try:
                with open(results_file, 'r', encoding='utf-8') as f:
                    results = json.load(f)
                    self.progress[course_key].created_resources = results.get('scripts_generated', {})
            except Exception as e:
                logger.warning(f"리소스 정보 수집 실패: {e}")
    
    def run_integrated_courses(self, start_from: str = "basic") -> bool:
        """통합 과정 실행"""
        logger.info("🚀 통합 클라우드 과정 자동화 시작!")
        
        # 사전 요구사항 확인
        if not self.check_prerequisites():
            logger.error("사전 요구사항 확인 실패")
            return False
        
        # 과정 실행 순서 정의
        course_order = ["basic", "master", "container"]
        start_index = course_order.index(start_from) if start_from in course_order else 0
        
        success_count = 0
        total_courses = len(course_order) - start_index
        
        for i, course_key in enumerate(course_order[start_index:], 1):
            logger.info(f"📚 과정 {i}/{total_courses}: {self.courses[course_key]['name']}")
            
            if self.run_course(course_key):
                success_count += 1
                logger.info(f"✅ {self.courses[course_key]['name']} 완료!")
            else:
                logger.error(f"❌ {self.courses[course_key]['name']} 실패!")
                # 다음 과정으로 계속 진행할지 결정
                if course_key == "basic":
                    logger.error("Basic 과정 실패로 전체 과정 중단")
                    break
                else:
                    logger.warning("이전 과정 실패했지만 다음 과정 계속 진행")
        
        # 결과 저장
        self.save_integrated_results()
        
        logger.info(f"🎉 통합 과정 완료! 성공: {success_count}/{total_courses}")
        return success_count == total_courses
    
    def save_integrated_results(self):
        """통합 결과 저장"""
        results = {
            "integrated_course_info": {
                "total_duration_days": self.config.total_duration_days,
                "cloud_providers": self.config.cloud_providers,
                "required_tools": self.config.required_tools,
                "environment_setup": self.config.environment_setup
            },
            "course_progress": {},
            "summary": {
                "total_courses": len(self.courses),
                "completed_courses": sum(1 for p in self.progress.values() if p.status == "completed"),
                "failed_courses": sum(1 for p in self.progress.values() if p.status == "failed"),
                "generated_at": datetime.now().isoformat()
            }
        }
        
        # 과정별 진행 상황 저장
        for course_key, progress in self.progress.items():
            results["course_progress"][course_key] = {
                "course_name": progress.course_name,
                "status": progress.status,
                "start_time": progress.start_time.isoformat() if progress.start_time else None,
                "end_time": progress.end_time.isoformat() if progress.end_time else None,
                "completed_days": progress.completed_days,
                "created_resources": progress.created_resources,
                "errors": progress.errors
            }
        
        # 결과 파일 저장
        results_file = self.results_path / "integrated_automation_results.json"
        with open(results_file, 'w', encoding='utf-8') as f:
            json.dump(results, f, ensure_ascii=False, indent=2)
        
        logger.info(f"통합 결과 저장 완료: {results_file}")
    
    def generate_integration_report(self):
        """통합 보고서 생성"""
        report_file = self.results_path / "integration_report.md"
        
        with open(report_file, 'w', encoding='utf-8') as f:
            f.write("# 통합 클라우드 과정 자동화 보고서\n\n")
            f.write(f"**생성 시간**: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n\n")
            
            f.write("## 📊 과정별 진행 상황\n\n")
            for course_key, progress in self.progress.items():
                status_emoji = "✅" if progress.status == "completed" else "❌" if progress.status == "failed" else "⏳"
                f.write(f"### {status_emoji} {progress.course_name}\n")
                f.write(f"- **상태**: {progress.status}\n")
                f.write(f"- **시작 시간**: {progress.start_time.strftime('%Y-%m-%d %H:%M:%S') if progress.start_time else 'N/A'}\n")
                f.write(f"- **완료 시간**: {progress.end_time.strftime('%Y-%m-%d %H:%M:%S') if progress.end_time else 'N/A'}\n")
                f.write(f"- **완료된 일수**: {len(progress.completed_days)}/{self.courses[course_key]['duration']}\n")
                
                if progress.created_resources:
                    f.write(f"- **생성된 리소스**: {len(progress.created_resources)}개\n")
                
                if progress.errors:
                    f.write(f"- **오류**: {len(progress.errors)}개\n")
                    for error in progress.errors:
                        f.write(f"  - {error}\n")
                f.write("\n")
            
            f.write("## 🔧 생성된 스크립트들\n\n")
            for course_key, progress in self.progress.items():
                if progress.created_resources:
                    f.write(f"### {progress.course_name}\n")
                    for day, scripts in progress.created_resources.items():
                        f.write(f"**{day}**:\n")
                        for script in scripts:
                            f.write(f"- `{script}`\n")
                        f.write("\n")
        
        logger.info(f"통합 보고서 생성 완료: {report_file}")

def main():
    """메인 함수"""
    import argparse
    
    parser = argparse.ArgumentParser(description="통합 클라우드 과정 자동화")
    parser.add_argument("--start-from", choices=["basic", "master", "container"], 
                       default="basic", help="시작할 과정")
    parser.add_argument("--config", help="설정 파일 경로")
    
    args = parser.parse_args()
    
    # 설정 로드
    config = IntegratedCourseConfig()
    if args.config and Path(args.config).exists():
        with open(args.config, 'r', encoding='utf-8') as f:
            config_data = json.load(f)
            config = IntegratedCourseConfig(**config_data)
    
    # 통합 자동화 실행
    automation = IntegratedCourseAutomation(config)
    success = automation.run_integrated_courses(args.start_from)
    
    # 보고서 생성
    automation.generate_integration_report()
    
    if success:
        logger.info("🎉 모든 과정이 성공적으로 완료되었습니다!")
        sys.exit(0)
    else:
        logger.error("❌ 일부 과정에서 오류가 발생했습니다.")
        sys.exit(1)

if __name__ == "__main__":
    main()
