#!/usr/bin/env python3
"""
통합 자동화 시스템 테스트
"""

import unittest
import tempfile
import shutil
import json
from pathlib import Path
from unittest.mock import patch, MagicMock
import sys
import os

# 테스트 대상 모듈 import
sys.path.append(str(Path(__file__).parent))
from integrated_course_automation import IntegratedCourseConfig, CourseProgress, IntegratedCourseAutomation

class TestIntegratedCourseConfig(unittest.TestCase):
    """통합 과정 설정 테스트"""
    
    def test_default_config(self):
        """기본 설정 테스트"""
        config = IntegratedCourseConfig()
        self.assertEqual(config.total_duration_days, 7)
        self.assertEqual(config.cloud_providers, ["aws", "gcp"])
        self.assertIn("aws-cli", config.required_tools)
        self.assertIn("docker", config.required_tools)
    
    def test_custom_config(self):
        """사용자 정의 설정 테스트"""
        config = IntegratedCourseConfig(
            total_duration_days=10,
            cloud_providers=["aws"],
            required_tools=["aws-cli", "terraform"]
        )
        self.assertEqual(config.total_duration_days, 10)
        self.assertEqual(config.cloud_providers, ["aws"])
        self.assertEqual(config.required_tools, ["aws-cli", "terraform"])

class TestCourseProgress(unittest.TestCase):
    """과정 진행 상황 테스트"""
    
    def test_initial_progress(self):
        """초기 진행 상황 테스트"""
        progress = CourseProgress(course_name="Test Course", status="not_started")
        self.assertEqual(progress.course_name, "Test Course")
        self.assertEqual(progress.status, "not_started")
        self.assertEqual(progress.completed_days, [])
        self.assertEqual(progress.created_resources, [])
        self.assertEqual(progress.errors, [])

class TestIntegratedCourseAutomation(unittest.TestCase):
    """통합 자동화 테스트"""
    
    def setUp(self):
        """테스트 설정"""
        self.temp_dir = tempfile.mkdtemp()
        self.config = IntegratedCourseConfig()
        self.automation = IntegratedCourseAutomation(self.config)
    
    def tearDown(self):
        """테스트 정리"""
        shutil.rmtree(self.temp_dir, ignore_errors=True)
    
    def test_initialization(self):
        """초기화 테스트"""
        self.assertIsNotNone(self.automation.config)
        self.assertIsNotNone(self.automation.courses)
        self.assertIsNotNone(self.automation.progress)
    
    def test_courses_structure(self):
        """과정 구조 테스트"""
        courses = self.automation.courses
        self.assertIn("basic", courses)
        self.assertIn("master", courses)
        self.assertIn("container", courses)
        
        # 각 과정의 필수 필드 확인
        for course_key, course in courses.items():
            self.assertIn("name", course)
            self.assertIn("duration", course)
            self.assertIn("path", course)
            self.assertIn("automation_script", course)
            self.assertIn("test_script", course)
    
    @patch('subprocess.run')
    def test_check_tool_installed_success(self, mock_run):
        """도구 설치 확인 성공 테스트"""
        mock_run.return_value.returncode = 0
        
        result = self.automation._check_tool_installed("aws-cli")
        self.assertTrue(result)
        mock_run.assert_called_once()
    
    @patch('subprocess.run')
    def test_check_tool_installed_failure(self, mock_run):
        """도구 설치 확인 실패 테스트"""
        mock_run.side_effect = subprocess.CalledProcessError(1, "aws")
        
        result = self.automation._check_tool_installed("aws-cli")
        self.assertFalse(result)
    
    @patch.dict(os.environ, {'AWS_ACCESS_KEY_ID': 'test', 'AWS_SECRET_ACCESS_KEY': 'test'})
    def test_check_environment_variables_success(self):
        """환경 변수 확인 성공 테스트"""
        # 환경 변수가 설정되어 있으므로 경고가 발생하지 않아야 함
        with self.assertLogs(level='WARNING') as log:
            self.automation._check_environment_variables()
            # 경고 로그가 없어야 함
            self.assertEqual(len(log.output), 0)
    
    @patch.dict(os.environ, {}, clear=True)
    def test_check_environment_variables_missing(self):
        """환경 변수 누락 테스트"""
        with self.assertLogs(level='WARNING') as log:
            self.automation._check_environment_variables()
            # 경고 로그가 있어야 함
            self.assertTrue(any("누락된 환경 변수" in message for message in log.output))
    
    def test_collect_course_resources(self):
        """과정 리소스 수집 테스트"""
        # 임시 결과 파일 생성
        temp_results = {
            "scripts_generated": {
                "day1": ["script1.sh", "script2.sh"],
                "day2": ["script3.sh"]
            }
        }
        
        with tempfile.NamedTemporaryFile(mode='w', suffix='.json', delete=False) as f:
            json.dump(temp_results, f)
            temp_file = f.name
        
        try:
            # 모의 과정 설정
            course_key = "basic"
            self.automation.courses[course_key]["path"] = Path(temp_file).parent
            self.automation.progress[course_key] = CourseProgress(
                course_name="Test Course", 
                status="completed"
            )
            
            # 리소스 수집 실행
            self.automation._collect_course_resources(course_key)
            
            # 결과 확인
            progress = self.automation.progress[course_key]
            self.assertEqual(progress.created_resources, temp_results["scripts_generated"])
            
        finally:
            os.unlink(temp_file)
    
    def test_save_integrated_results(self):
        """통합 결과 저장 테스트"""
        # 모의 진행 상황 설정
        self.automation.progress["basic"] = CourseProgress(
            course_name="Cloud Basic",
            status="completed",
            completed_days=[1, 2],
            created_resources={"day1": ["script1.sh"]}
        )
        
        # 결과 저장
        self.automation.save_integrated_results()
        
        # 결과 파일 확인
        results_file = self.automation.results_path / "integrated_automation_results.json"
        self.assertTrue(results_file.exists())
        
        with open(results_file, 'r', encoding='utf-8') as f:
            results = json.load(f)
            
        self.assertIn("integrated_course_info", results)
        self.assertIn("course_progress", results)
        self.assertIn("summary", results)
        self.assertEqual(results["course_progress"]["basic"]["status"], "completed")

class TestIntegrationFlow(unittest.TestCase):
    """통합 흐름 테스트"""
    
    def setUp(self):
        """테스트 설정"""
        self.temp_dir = tempfile.mkdtemp()
        self.config = IntegratedCourseConfig()
        self.automation = IntegratedCourseAutomation(self.config)
    
    def tearDown(self):
        """테스트 정리"""
        shutil.rmtree(self.temp_dir, ignore_errors=True)
    
    @patch('subprocess.run')
    def test_run_course_success(self, mock_run):
        """과정 실행 성공 테스트"""
        mock_run.return_value.returncode = 0
        mock_run.return_value.stdout = "Success"
        mock_run.return_value.stderr = ""
        
        # 모의 과정 경로 설정
        self.automation.courses["basic"]["path"] = Path(self.temp_dir)
        
        result = self.automation.run_course("basic")
        self.assertTrue(result)
        self.assertEqual(self.automation.progress["basic"].status, "completed")
    
    @patch('subprocess.run')
    def test_run_course_failure(self, mock_run):
        """과정 실행 실패 테스트"""
        mock_run.return_value.returncode = 1
        mock_run.return_value.stderr = "Error occurred"
        
        # 모의 과정 경로 설정
        self.automation.courses["basic"]["path"] = Path(self.temp_dir)
        
        result = self.automation.run_course("basic")
        self.assertFalse(result)
        self.assertEqual(self.automation.progress["basic"].status, "failed")
    
    def test_generate_integration_report(self):
        """통합 보고서 생성 테스트"""
        # 모의 진행 상황 설정
        self.automation.progress["basic"] = CourseProgress(
            course_name="Cloud Basic",
            status="completed",
            completed_days=[1, 2],
            created_resources={"day1": ["script1.sh", "script2.sh"]}
        )
        
        # 보고서 생성
        self.automation.generate_integration_report()
        
        # 보고서 파일 확인
        report_file = self.automation.results_path / "integration_report.md"
        self.assertTrue(report_file.exists())
        
        with open(report_file, 'r', encoding='utf-8') as f:
            content = f.read()
            
        self.assertIn("통합 클라우드 과정 자동화 보고서", content)
        self.assertIn("Cloud Basic", content)
        self.assertIn("script1.sh", content)

def run_tests():
    """테스트 실행"""
    # 테스트 스위트 생성
    loader = unittest.TestLoader()
    suite = unittest.TestSuite()
    
    # 테스트 클래스 추가
    suite.addTests(loader.loadTestsFromTestCase(TestIntegratedCourseConfig))
    suite.addTests(loader.loadTestsFromTestCase(TestCourseProgress))
    suite.addTests(loader.loadTestsFromTestCase(TestIntegratedCourseAutomation))
    suite.addTests(loader.loadTestsFromTestCase(TestIntegrationFlow))
    
    # 테스트 실행
    runner = unittest.TextTestRunner(verbosity=2)
    result = runner.run(suite)
    
    return result.wasSuccessful()

if __name__ == "__main__":
    success = run_tests()
    if success:
        print("\n🎉 모든 테스트가 성공적으로 통과했습니다!")
    else:
        print("\n❌ 일부 테스트가 실패했습니다.")
        sys.exit(1)
