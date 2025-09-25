#!/usr/bin/env python3
"""
공유 리소스 관리 시스템
과정 간 리소스 공유 및 연계 관리
"""

import json
import yaml
from pathlib import Path
from typing import Dict, List, Any, Optional
from datetime import datetime
import logging

logger = logging.getLogger(__name__)

class SharedResourceManager:
    """공유 리소스 관리자"""
    
    def __init__(self, base_path: Path):
        self.base_path = base_path
        self.shared_path = base_path / "shared_resources"
        self.state_file = self.shared_path / "shared_state.json"
        self.resources_file = self.shared_path / "shared_resources.json"
        self.setup_directories()
    
    def setup_directories(self):
        """디렉토리 설정"""
        self.shared_path.mkdir(exist_ok=True)
        
        # 초기 상태 파일 생성
        if not self.state_file.exists():
            self._initialize_state()
    
    def _initialize_state(self):
        """초기 상태 초기화"""
        initial_state = {
            "created_at": datetime.now().isoformat(),
            "courses_completed": [],
            "shared_resources": {},
            "environment_variables": {},
            "aws_resources": {},
            "gcp_resources": {},
            "docker_resources": {},
            "kubernetes_resources": {}
        }
        
        with open(self.state_file, 'w', encoding='utf-8') as f:
            json.dump(initial_state, f, ensure_ascii=False, indent=2)
    
    def load_state(self) -> Dict[str, Any]:
        """상태 로드"""
        try:
            with open(self.state_file, 'r', encoding='utf-8') as f:
                return json.load(f)
        except FileNotFoundError:
            self._initialize_state()
            return self.load_state()
    
    def save_state(self, state: Dict[str, Any]):
        """상태 저장"""
        with open(self.state_file, 'w', encoding='utf-8') as f:
            json.dump(state, f, ensure_ascii=False, indent=2)
    
    def mark_course_completed(self, course_name: str, resources: Dict[str, Any] = None):
        """과정 완료 표시"""
        state = self.load_state()
        
        if course_name not in state["courses_completed"]:
            state["courses_completed"].append(course_name)
        
        if resources:
            state["shared_resources"][course_name] = resources
        
        self.save_state(state)
        logger.info(f"과정 완료 표시: {course_name}")
    
    def get_shared_resources(self, course_name: str) -> Dict[str, Any]:
        """공유 리소스 조회"""
        state = self.load_state()
        return state["shared_resources"].get(course_name, {})
    
    def get_all_shared_resources(self) -> Dict[str, Any]:
        """모든 공유 리소스 조회"""
        state = self.load_state()
        return state["shared_resources"]
    
    def add_aws_resource(self, resource_type: str, resource_id: str, properties: Dict[str, Any] = None):
        """AWS 리소스 추가"""
        state = self.load_state()
        
        if resource_type not in state["aws_resources"]:
            state["aws_resources"][resource_type] = []
        
        resource_info = {
            "id": resource_id,
            "created_at": datetime.now().isoformat(),
            "properties": properties or {}
        }
        
        state["aws_resources"][resource_type].append(resource_info)
        self.save_state(state)
        logger.info(f"AWS 리소스 추가: {resource_type}/{resource_id}")
    
    def add_gcp_resource(self, resource_type: str, resource_id: str, properties: Dict[str, Any] = None):
        """GCP 리소스 추가"""
        state = self.load_state()
        
        if resource_type not in state["gcp_resources"]:
            state["gcp_resources"][resource_type] = []
        
        resource_info = {
            "id": resource_id,
            "created_at": datetime.now().isoformat(),
            "properties": properties or {}
        }
        
        state["gcp_resources"][resource_type].append(resource_info)
        self.save_state(state)
        logger.info(f"GCP 리소스 추가: {resource_type}/{resource_id}")
    
    def add_docker_resource(self, image_name: str, tag: str, properties: Dict[str, Any] = None):
        """Docker 리소스 추가"""
        state = self.load_state()
        
        if "images" not in state["docker_resources"]:
            state["docker_resources"]["images"] = []
        
        image_info = {
            "name": image_name,
            "tag": tag,
            "created_at": datetime.now().isoformat(),
            "properties": properties or {}
        }
        
        state["docker_resources"]["images"].append(image_info)
        self.save_state(state)
        logger.info(f"Docker 이미지 추가: {image_name}:{tag}")
    
    def add_kubernetes_resource(self, resource_type: str, name: str, namespace: str = "default", properties: Dict[str, Any] = None):
        """Kubernetes 리소스 추가"""
        state = self.load_state()
        
        if resource_type not in state["kubernetes_resources"]:
            state["kubernetes_resources"][resource_type] = []
        
        resource_info = {
            "name": name,
            "namespace": namespace,
            "created_at": datetime.now().isoformat(),
            "properties": properties or {}
        }
        
        state["kubernetes_resources"][resource_type].append(resource_info)
        self.save_state(state)
        logger.info(f"Kubernetes 리소스 추가: {resource_type}/{name}")
    
    def get_aws_resources(self, resource_type: str = None) -> Dict[str, Any]:
        """AWS 리소스 조회"""
        state = self.load_state()
        if resource_type:
            return state["aws_resources"].get(resource_type, [])
        return state["aws_resources"]
    
    def get_gcp_resources(self, resource_type: str = None) -> Dict[str, Any]:
        """GCP 리소스 조회"""
        state = self.load_state()
        if resource_type:
            return state["gcp_resources"].get(resource_type, [])
        return state["gcp_resources"]
    
    def get_docker_resources(self) -> List[Dict[str, Any]]:
        """Docker 리소스 조회"""
        state = self.load_state()
        return state["docker_resources"].get("images", [])
    
    def get_kubernetes_resources(self, resource_type: str = None) -> Dict[str, Any]:
        """Kubernetes 리소스 조회"""
        state = self.load_state()
        if resource_type:
            return state["kubernetes_resources"].get(resource_type, [])
        return state["kubernetes_resources"]
    
    def generate_resource_summary(self) -> Dict[str, Any]:
        """리소스 요약 생성"""
        state = self.load_state()
        
        summary = {
            "total_courses_completed": len(state["courses_completed"]),
            "courses_completed": state["courses_completed"],
            "aws_resources_count": sum(len(resources) for resources in state["aws_resources"].values()),
            "gcp_resources_count": sum(len(resources) for resources in state["gcp_resources"].values()),
            "docker_images_count": len(state["docker_resources"].get("images", [])),
            "kubernetes_resources_count": sum(len(resources) for resources in state["kubernetes_resources"].values()),
            "last_updated": datetime.now().isoformat()
        }
        
        return summary
    
    def cleanup_resources(self, course_name: str = None):
        """리소스 정리"""
        state = self.load_state()
        
        if course_name:
            # 특정 과정의 리소스만 정리
            if course_name in state["courses_completed"]:
                state["courses_completed"].remove(course_name)
            if course_name in state["shared_resources"]:
                del state["shared_resources"][course_name]
        else:
            # 모든 리소스 정리
            state["courses_completed"] = []
            state["shared_resources"] = {}
            state["aws_resources"] = {}
            state["gcp_resources"] = {}
            state["docker_resources"] = {}
            state["kubernetes_resources"] = {}
        
        self.save_state(state)
        logger.info(f"리소스 정리 완료: {course_name or '전체'}")
    
    def export_resources(self, export_file: Path):
        """리소스 내보내기"""
        state = self.load_state()
        
        export_data = {
            "exported_at": datetime.now().isoformat(),
            "state": state,
            "summary": self.generate_resource_summary()
        }
        
        with open(export_file, 'w', encoding='utf-8') as f:
            json.dump(export_data, f, ensure_ascii=False, indent=2)
        
        logger.info(f"리소스 내보내기 완료: {export_file}")
    
    def import_resources(self, import_file: Path):
        """리소스 가져오기"""
        try:
            with open(import_file, 'r', encoding='utf-8') as f:
                import_data = json.load(f)
            
            if "state" in import_data:
                self.save_state(import_data["state"])
                logger.info(f"리소스 가져오기 완료: {import_file}")
            else:
                logger.error("잘못된 가져오기 파일 형식")
        except Exception as e:
            logger.error(f"리소스 가져오기 실패: {e}")

def main():
    """테스트 및 데모"""
    import tempfile
    
    # 임시 디렉토리에서 테스트
    with tempfile.TemporaryDirectory() as temp_dir:
        manager = SharedResourceManager(Path(temp_dir))
        
        # 테스트 데이터 추가
        manager.mark_course_completed("Cloud Basic", {
            "scripts": ["basic_script1.sh", "basic_script2.sh"],
            "aws_resources": ["vpc-12345", "subnet-67890"]
        })
        
        manager.add_aws_resource("vpc", "vpc-12345", {"region": "us-west-2"})
        manager.add_gcp_resource("project", "my-project-123", {"region": "us-central1"})
        manager.add_docker_resource("my-app", "latest", {"size": "100MB"})
        
        # 요약 생성
        summary = manager.generate_resource_summary()
        print("리소스 요약:")
        print(json.dumps(summary, indent=2, ensure_ascii=False))

if __name__ == "__main__":
    main()
