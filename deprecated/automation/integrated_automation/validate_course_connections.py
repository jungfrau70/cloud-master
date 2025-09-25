#!/usr/bin/env python3
"""
과정 간 연결 검증 도구
Cloud Basic → Cloud Master → Cloud Container 과정 간 연결성 검증
"""

import os
import sys
import json
import yaml
from pathlib import Path
from typing import Dict, List, Any, Optional, Tuple
import subprocess
import logging
from datetime import datetime
import re

# 로깅 설정
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

class CourseConnectionValidator:
    """과정 간 연결 검증자"""
    
    def __init__(self, base_path: Path):
        self.base_path = base_path
        if base_path.name == "integrated_automation":
            self.integrated_path = base_path
            parent_path = base_path.parent
        else:
            self.integrated_path = base_path / "integrated_automation"
            parent_path = base_path
            
        self.results_path = self.integrated_path / "results"
        
        # 과정별 경로
        self.courses = {
            "cloud_basic": {
                "path": parent_path / "cloud_basic",
                "automation_script": "cloud_basic_course_automation.py",
                "next_course": "cloud_master"
            },
            "cloud_master": {
                "path": parent_path / "cloud_master",
                "automation_script": "cloud_master_course_automation.py",
                "next_course": "cloud_container",
                "prev_course": "cloud_basic"
            },
            "cloud_container": {
                "path": parent_path / "cloud_container",
                "automation_script": "cloud_container_course_automation.py",
                "prev_course": "cloud_master"
            }
        }
    
    def validate_course_automation_scripts(self) -> Dict[str, Any]:
        """과정별 자동화 스크립트 검증"""
        logger.info("🤖 과정별 자동화 스크립트 검증 중...")
        
        results = {
            "scripts": {},
            "overall_status": "passed"
        }
        
        for course_name, course_info in self.courses.items():
            script_path = course_info["path"] / "automation_tests" / course_info["automation_script"]
            
            script_result = {
                "exists": script_path.exists(),
                "path": str(script_path),
                "size": 0,
                "has_main_function": False,
                "has_course_config": False,
                "has_shared_resource_integration": False
            }
            
            if script_path.exists():
                # 파일 크기 확인
                script_result["size"] = script_path.stat().st_size
                
                # 파일 내용 분석
                try:
                    with open(script_path, 'r', encoding='utf-8') as f:
                        content = f.read()
                    
                    # main 함수 존재 확인
                    if "def main(" in content or "if __name__ == \"__main__\":" in content:
                        script_result["has_main_function"] = True
                    
                    # 과정 설정 관련 코드 확인
                    if "course_config" in content.lower() or "config" in content.lower():
                        script_result["has_course_config"] = True
                    
                    # 공유 리소스 통합 확인
                    if "shared" in content.lower() or "integration" in content.lower():
                        script_result["has_shared_resource_integration"] = True
                    
                    logger.info(f"✅ {course_name} 스크립트 분석 완료")
                    
                except Exception as e:
                    logger.warning(f"⚠️ {course_name} 스크립트 분석 실패: {e}")
            else:
                logger.warning(f"❌ {course_name} 스크립트 누락: {script_path}")
                results["overall_status"] = "failed"
            
            results["scripts"][course_name] = script_result
        
        return results
    
    def validate_bridge_scripts(self) -> Dict[str, Any]:
        """브리지 스크립트 검증"""
        logger.info("🌉 브리지 스크립트 검증 중...")
        
        bridge_scripts = [
            "basic_to_master_bridge.sh",
            "master_to_container_bridge.sh"
        ]
        
        results = {
            "scripts": {},
            "overall_status": "passed"
        }
        
        for script_name in bridge_scripts:
            script_path = self.integrated_path / "bridge_scripts" / script_name
            
            script_result = {
                "exists": script_path.exists(),
                "path": str(script_path),
                "size": 0,
                "is_executable": False,
                "has_logging": False,
                "has_error_handling": False,
                "has_resource_validation": False
            }
            
            if script_path.exists():
                # 파일 크기 확인
                script_result["size"] = script_path.stat().st_size
                
                # 실행 권한 확인
                script_result["is_executable"] = os.access(script_path, os.X_OK)
                
                # 파일 내용 분석
                try:
                    with open(script_path, 'r', encoding='utf-8') as f:
                        content = f.read()
                    
                    # 로깅 기능 확인
                    if "log_" in content or "echo" in content:
                        script_result["has_logging"] = True
                    
                    # 오류 처리 확인
                    if "set -e" in content or "error" in content.lower():
                        script_result["has_error_handling"] = True
                    
                    # 리소스 검증 확인
                    if "aws" in content.lower() or "gcp" in content.lower() or "docker" in content.lower():
                        script_result["has_resource_validation"] = True
                    
                    logger.info(f"✅ {script_name} 스크립트 분석 완료")
                    
                except Exception as e:
                    logger.warning(f"⚠️ {script_name} 스크립트 분석 실패: {e}")
            else:
                logger.warning(f"❌ {script_name} 스크립트 누락: {script_path}")
                results["overall_status"] = "failed"
            
            results["scripts"][script_name] = script_result
        
        return results
    
    def validate_shared_resource_integration(self) -> Dict[str, Any]:
        """공유 리소스 통합 검증"""
        logger.info("📦 공유 리소스 통합 검증 중...")
        
        results = {
            "shared_resource_manager": {},
            "resource_files": {},
            "integration_points": {},
            "overall_status": "passed"
        }
        
        # SharedResourceManager 클래스 검증
        manager_file = self.integrated_path / "shared_resource_manager.py"
        if manager_file.exists():
            try:
                with open(manager_file, 'r', encoding='utf-8') as f:
                    content = f.read()
                
                manager_result = {
                    "exists": True,
                    "has_shared_resource_manager_class": "class SharedResourceManager" in content,
                    "has_load_state_method": "def load_state" in content,
                    "has_save_state_method": "def save_state" in content,
                    "has_add_resource_method": "def add_resource" in content,
                    "has_get_resource_method": "def get_resource" in content
                }
                
                results["shared_resource_manager"] = manager_result
                logger.info("✅ SharedResourceManager 클래스 검증 완료")
                
            except Exception as e:
                logger.warning(f"⚠️ SharedResourceManager 분석 실패: {e}")
                results["overall_status"] = "failed"
        else:
            logger.warning("❌ SharedResourceManager 파일 누락")
            results["overall_status"] = "failed"
        
        # 공유 리소스 파일 검증
        shared_path = self.integrated_path / "shared_resources"
        resource_files = [
            "shared_state.json",
            "shared_resources.json",
            "aws_resources.env",
            "gcp_resources.env",
            "docker_images.json"
        ]
        
        for resource_file in resource_files:
            file_path = shared_path / resource_file
            exists = file_path.exists()
            results["resource_files"][resource_file] = exists
            
            if exists:
                logger.info(f"✅ 공유 리소스 파일 존재: {resource_file}")
            else:
                logger.warning(f"⚠️ 공유 리소스 파일 누락: {resource_file}")
        
        return results
    
    def validate_course_dependencies(self) -> Dict[str, Any]:
        """과정 간 의존성 검증"""
        logger.info("🔗 과정 간 의존성 검증 중...")
        
        results = {
            "dependencies": {},
            "overall_status": "passed"
        }
        
        # Basic → Master 의존성
        basic_to_master = {
            "aws_resources": ["VPC", "Subnet", "Security Group", "S3 Bucket"],
            "gcp_resources": ["Project", "Network", "Subnet"],
            "shared_config": ["Environment Variables", "Project Settings"]
        }
        
        # Master → Container 의존성
        master_to_container = {
            "docker_resources": ["Images", "Containers", "Registry"],
            "github_resources": ["Repositories", "Workflows", "Secrets"],
            "kubernetes_resources": ["Cluster", "Namespaces", "Config"]
        }
        
        results["dependencies"]["basic_to_master"] = basic_to_master
        results["dependencies"]["master_to_container"] = master_to_container
        
        logger.info("✅ 과정 간 의존성 매핑 완료")
        
        return results
    
    def validate_configuration_consistency(self) -> Dict[str, Any]:
        """설정 일관성 검증"""
        logger.info("⚙️ 설정 일관성 검증 중...")
        
        results = {
            "integrated_config": {},
            "course_configs": {},
            "consistency_issues": [],
            "overall_status": "passed"
        }
        
        # 통합 설정 파일 로드
        config_file = self.integrated_path / "integrated_config.json"
        if config_file.exists():
            try:
                with open(config_file, 'r', encoding='utf-8') as f:
                    integrated_config = json.load(f)
                
                results["integrated_config"] = integrated_config
                
                # 각 과정의 설정 파일 확인
                for course_name, course_info in self.courses.items():
                    course_config_path = course_info["path"] / "automation_tests" / "config.json"
                    
                    if course_config_path.exists():
                        try:
                            with open(course_config_path, 'r', encoding='utf-8') as f:
                                course_config = json.load(f)
                            
                            results["course_configs"][course_name] = course_config
                            
                            # 설정 일관성 검사
                            if "aws_region" in integrated_config.get("environment_setup", {}):
                                integrated_region = integrated_config["environment_setup"]["aws_region"]
                                if "aws_region" in course_config:
                                    if course_config["aws_region"] != integrated_region:
                                        results["consistency_issues"].append(
                                            f"{course_name}: AWS 리전 불일치 ({course_config['aws_region']} vs {integrated_region})"
                                        )
                            
                        except Exception as e:
                            logger.warning(f"⚠️ {course_name} 설정 파일 분석 실패: {e}")
                    else:
                        logger.warning(f"⚠️ {course_name} 설정 파일 누락")
                
                if results["consistency_issues"]:
                    results["overall_status"] = "failed"
                    logger.warning("❌ 설정 일관성 문제 발견")
                else:
                    logger.info("✅ 설정 일관성 검증 완료")
                
            except Exception as e:
                logger.error(f"❌ 통합 설정 파일 분석 실패: {e}")
                results["overall_status"] = "failed"
        else:
            logger.warning("❌ 통합 설정 파일 누락")
            results["overall_status"] = "failed"
        
        return results
    
    def generate_connection_report(self, all_results: Dict[str, Any]) -> str:
        """연결 검증 보고서 생성"""
        report = f"""# 과정 간 연결 검증 보고서

**생성 시간**: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}

## 📊 검증 결과 요약

"""
        
        # 전체 상태
        overall_status = "✅ 통과" if all_results.get("overall_status") == "passed" else "❌ 실패"
        report += f"**전체 상태**: {overall_status}\n\n"
        
        # 각 검증 항목별 결과
        for category, results in all_results.items():
            if category == "overall_status":
                continue
                
            report += f"### {category.replace('_', ' ').title()}\n\n"
            
            if isinstance(results, dict):
                for item, status in results.items():
                    if isinstance(status, bool):
                        status_icon = "✅" if status else "❌"
                        report += f"- {status_icon} {item}\n"
                    elif isinstance(status, dict):
                        report += f"- **{item}**:\n"
                        for sub_item, sub_status in status.items():
                            if isinstance(sub_status, bool):
                                sub_icon = "✅" if sub_status else "❌"
                                report += f"  - {sub_icon} {sub_item}\n"
                            else:
                                report += f"  - {sub_item}: {sub_status}\n"
                    elif isinstance(status, list):
                        report += f"- **{item}**:\n"
                        for list_item in status:
                            report += f"  - ⚠️ {list_item}\n"
            
            report += "\n"
        
        # 과정 간 연결 다이어그램
        report += """## 🔗 과정 간 연결 다이어그램

```
Cloud Basic (2일)
    ↓ [AWS/GCP 리소스 공유]
Cloud Master (3일)
    ↓ [Docker/GitHub 리소스 공유]
Cloud Container (2일)
```

## 🔧 권장사항

1. **누락된 스크립트 생성**
2. **공유 리소스 통합 강화**
3. **설정 일관성 확보**
4. **정기적인 연결성 검증**

## 📞 지원

문제가 발생한 경우 다음을 확인하세요:
- 각 과정의 automation_tests 디렉토리
- 브리지 스크립트 실행 권한
- 공유 리소스 디렉토리 상태

---
*이 보고서는 자동으로 생성되었습니다.*
"""
        
        return report
    
    def run_full_validation(self) -> Dict[str, Any]:
        """전체 연결 검증 실행"""
        logger.info("🚀 과정 간 연결 검증 시작...")
        
        all_results = {}
        
        # 각 검증 단계 실행
        all_results["course_automation_scripts"] = self.validate_course_automation_scripts()
        all_results["bridge_scripts"] = self.validate_bridge_scripts()
        all_results["shared_resource_integration"] = self.validate_shared_resource_integration()
        all_results["course_dependencies"] = self.validate_course_dependencies()
        all_results["configuration_consistency"] = self.validate_configuration_consistency()
        
        # 전체 상태 결정
        overall_status = "passed"
        for category, results in all_results.items():
            if isinstance(results, dict) and results.get("overall_status") == "failed":
                overall_status = "failed"
        
        all_results["overall_status"] = overall_status
        
        # 보고서 생성 및 저장
        report = self.generate_connection_report(all_results)
        report_file = self.results_path / f"connection_validation_report_{datetime.now().strftime('%Y%m%d_%H%M%S')}.md"
        
        with open(report_file, 'w', encoding='utf-8') as f:
            f.write(report)
        
        logger.info(f"📄 연결 검증 보고서 저장: {report_file}")
        
        return all_results

def main():
    """메인 함수"""
    import argparse
    
    parser = argparse.ArgumentParser(description='과정 간 연결 검증 도구')
    parser.add_argument('--base-path', type=str, default='.', 
                       help='기본 경로 (기본값: 현재 디렉토리)')
    parser.add_argument('--output-format', choices=['json', 'markdown'], default='markdown',
                       help='출력 형식 (기본값: markdown)')
    
    args = parser.parse_args()
    
    base_path = Path(args.base_path).resolve()
    validator = CourseConnectionValidator(base_path)
    
    # 전체 검증 실행
    results = validator.run_full_validation()
    
    # 결과 출력
    if args.output_format == 'json':
        print(json.dumps(results, ensure_ascii=False, indent=2))
    else:
        print(f"\n🎯 연결 검증 완료! 전체 상태: {results['overall_status']}")
        print(f"📄 상세 보고서: {validator.results_path}/connection_validation_report_*.md")

if __name__ == "__main__":
    main()
