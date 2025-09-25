#!/usr/bin/env python3
"""
   
"""

import pytest
import tempfile
import shutil
import os
from pathlib import Path
from unittest.mock import Mock, patch, MagicMock
import subprocess
import json

#    import
import sys
sys.path.append(str(Path(__file__).parent))

from .master_course_automation import MasterCourseAutomation, CourseConfig, DayPlan

class TestCourseConfig:
    """CourseConfig """
    
    def test_default_config(self):
        """  """
        config = CourseConfig()
        assert config.course_name == "Cloud Master Course"
        assert config.duration_days == 3
        assert config.daily_hours == 7
        assert config.start_time == "09:00"
        assert config.end_time == "17:00"
        assert "aws" in config.cloud_providers
        assert "gcp" in config.cloud_providers
        assert "docker" in config.required_tools
    
    def test_custom_config(self):
        """   """
        config = CourseConfig(
            course_name="Custom Course",
            duration_days=5,
            cloud_providers=["aws"],
            required_tools=["docker", "git"]
        )
        assert config.course_name == "Custom Course"
        assert config.duration_days == 5
        assert config.cloud_providers == ["aws"]
        assert config.required_tools == ["docker", "git"]

class TestDayPlan:
    """DayPlan """
    
    def test_day_plan_creation(self):
        """   """
        plan = DayPlan(
            day=1,
            title="Test Day",
            topics=["Topic 1", "Topic 2"],
            hands_on_labs=["Lab 1"],
            duration_hours=7
        )
        assert plan.day == 1
        assert plan.title == "Test Day"
        assert len(plan.topics) == 2
        assert len(plan.hands_on_labs) == 1
        assert plan.duration_hours == 7

class TestMasterCourseAutomation:
    """MasterCourseAutomation """
    
    @pytest.fixture
    def temp_dir(self):
        """  """
        temp_dir = tempfile.mkdtemp()
        yield Path(temp_dir)
        shutil.rmtree(temp_dir)
    
    @pytest.fixture
    def config(self):
        """ """
        return CourseConfig()
    
    @pytest.fixture
    def automation(self, temp_dir, config):
        """  """
        with patch('master_course_automation.Path') as mock_path:
            mock_path.return_value.parent = temp_dir
            return MasterCourseAutomation(config)
    
    def test_initialization(self, automation, config):
        """ """
        assert automation.config == config
        assert automation.results == {}
    
    def test_create_directories(self, automation, temp_dir):
        """  """
        with patch.object(automation, 'course_dir', temp_dir / "course"):
            automation._create_directories()
            
            #   
            assert (temp_dir / "course" / "automation").exists()
            assert (temp_dir / "course" / "automation" / "day1").exists()
            assert (temp_dir / "course" / "automation" / "day2").exists()
            assert (temp_dir / "course" / "automation" / "day3").exists()
    
    def test_setup_environment_variables(self, automation):
        """   """
        with patch.dict('os.environ', {}, clear=True):
            automation._setup_environment_variables()
            
            assert os.environ.get('COURSE_NAME') == automation.config.course_name
            assert os.environ.get('COURSE_DURATION') == str(automation.config.duration_days)
    
    @patch('subprocess.run')
    def test_check_required_tools_success(self, mock_run, automation):
        """    """
        mock_run.return_value = Mock(returncode=0)
        
        missing_tools = automation._check_required_tools()
        assert missing_tools == []
    
    @patch('subprocess.run')
    def test_check_required_tools_missing(self, mock_run, automation):
        """   """
        def side_effect(*args, **kwargs):
            if 'docker' in args[0]:
                raise subprocess.CalledProcessError(1, 'docker')
            return Mock(returncode=0)
        
        mock_run.side_effect = side_effect
        
        missing_tools = automation._check_required_tools()
        assert 'docker' in missing_tools
    
    def test_create_day_plans(self, automation):
        """   """
        day_plans = automation.create_day_plans()
        
        assert len(day_plans) == 3
        assert day_plans[0].day == 1
        assert day_plans[1].day == 2
        assert day_plans[2].day == 3
        
        # Day 1 
        assert "Docker" in day_plans[0].title
        assert "Git" in day_plans[0].title
        assert "GitHub Actions" in day_plans[0].title
        
        # Day 2 
        assert " CI/CD" in day_plans[1].title
        assert " " in day_plans[1].title
        
        # Day 3 
        assert " " in day_plans[2].title
        assert "" in day_plans[2].title
        assert " " in day_plans[2].title
    
    def test_save_results(self, automation, temp_dir):
        """  """
        with patch.object(automation, 'course_dir', temp_dir / "course"):
            #  
            (temp_dir / "course" / "automation" / "results").mkdir(parents=True, exist_ok=True)
            
            day_plans = automation.create_day_plans()
            automation._save_results(day_plans)
            
            results_file = temp_dir / "course" / "automation" / "results" / "automation_results.json"
            assert results_file.exists()
            
            with open(results_file, 'r', encoding='utf-8') as f:
                results = json.load(f)
            
            assert results['course_name'] == automation.config.course_name
            assert len(results['day_plans']) == 3
            assert 'scripts_generated' in results

class TestScriptGeneration:
    """  """
    
    @pytest.fixture
    def temp_dir(self):
        """  """
        temp_dir = tempfile.mkdtemp()
        yield Path(temp_dir)
        shutil.rmtree(temp_dir)
    
    def test_docker_basics_script_generation(self, temp_dir):
        """Docker    """
        from master_course_automation import MasterCourseAutomation, CourseConfig
        
        config = CourseConfig()
        automation = MasterCourseAutomation(config)
        automation.course_dir = temp_dir / "course"
        automation.course_dir.mkdir(parents=True)
        
        #  
        (temp_dir / "course" / "automation" / "day1").mkdir(parents=True, exist_ok=True)
        
        automation._create_docker_basics_script()
        
        script_path = temp_dir / "course" / "automation" / "day1" / "docker_basics.sh"
        assert script_path.exists()
        
        script_content = script_path.read_text(encoding='utf-8')
        assert "Docker  " in script_content
        assert "docker run" in script_content
        assert "Dockerfile" in script_content
    
    def test_git_github_script_generation(self, temp_dir):
        """Git/GitHub   """
        from master_course_automation import MasterCourseAutomation, CourseConfig
        
        config = CourseConfig()
        automation = MasterCourseAutomation(config)
        automation.course_dir = temp_dir / "course"
        automation.course_dir.mkdir(parents=True)
        
        #  
        (temp_dir / "course" / "automation" / "day1").mkdir(parents=True, exist_ok=True)
        
        automation._create_git_github_script()
        
        script_path = temp_dir / "course" / "automation" / "day1" / "git_github_basics.sh"
        assert script_path.exists()
        
        script_content = script_path.read_text(encoding='utf-8')
        assert "Git/GitHub  " in script_content
        assert "git init" in script_content
        assert "git commit" in script_content
    
    def test_github_actions_script_generation(self, temp_dir):
        """GitHub Actions   """
        from master_course_automation import MasterCourseAutomation, CourseConfig
        
        config = CourseConfig()
        automation = MasterCourseAutomation(config)
        automation.course_dir = temp_dir / "course"
        automation.course_dir.mkdir(parents=True)
        
        #  
        (temp_dir / "course" / "automation" / "day1").mkdir(parents=True, exist_ok=True)
        
        automation._create_github_actions_script()
        
        script_path = temp_dir / "course" / "automation" / "day1" / "github_actions.sh"
        assert script_path.exists()
        
        script_content = script_path.read_text(encoding='utf-8')
        assert "GitHub Actions CI/CD" in script_content
        assert ".github/workflows" in script_content
        assert "docker/build-push-action" in script_content
    
    def test_vm_deployment_script_generation(self, temp_dir):
        """VM    """
        from master_course_automation import MasterCourseAutomation, CourseConfig
        
        config = CourseConfig()
        automation = MasterCourseAutomation(config)
        automation.course_dir = temp_dir / "course"
        automation.course_dir.mkdir(parents=True)
        
        #  
        (temp_dir / "course" / "automation" / "day1").mkdir(parents=True, exist_ok=True)
        
        automation._create_vm_deployment_script()
        
        script_path = temp_dir / "course" / "automation" / "day1" / "vm_deployment.sh"
        assert script_path.exists()
        
        script_content = script_path.read_text(encoding='utf-8')
        assert "VM    " in script_content
        assert "aws ec2" in script_content
        assert "gcloud compute" in script_content

class TestIntegration:
    """ """
    
    @pytest.fixture
    def temp_dir(self):
        """  """
        temp_dir = tempfile.mkdtemp()
        yield Path(temp_dir)
        shutil.rmtree(temp_dir)
    
    @patch('subprocess.run')
    def test_full_automation_success(self, mock_run, temp_dir):
        """   """
        # subprocess.run 
        mock_run.return_value = Mock(returncode=0)
        
        from master_course_automation import MasterCourseAutomation, CourseConfig
        
        config = CourseConfig()
        automation = MasterCourseAutomation(config)
        automation.project_root = temp_dir
        automation.course_dir = temp_dir / "mcp_knowledge_base" / "cloud_master"
        
        #  
        result = automation.run_course_automation()
        
        assert result == True
        
        #   
        results_file = temp_dir / "mcp_knowledge_base" / "cloud_master" / "automation" / "results" / "automation_results.json"
        assert results_file.exists()
        
        #   
        day1_scripts = [
            "docker_basics.sh",
            "git_github_basics.sh", 
            "github_actions.sh",
            "vm_deployment.sh"
        ]
        
        for script in day1_scripts:
            script_path = temp_dir / "mcp_knowledge_base" / "cloud_master" / "automation" / "day1" / script
            assert script_path.exists()
    
    @patch('subprocess.run')
    def test_automation_with_missing_tools(self, mock_run, temp_dir):
        """    """
        def side_effect(*args, **kwargs):
            if 'docker' in args[0]:
                raise subprocess.CalledProcessError(1, 'docker')
            return Mock(returncode=0)
        
        mock_run.side_effect = side_effect
        
        from master_course_automation import MasterCourseAutomation, CourseConfig
        
        config = CourseConfig()
        automation = MasterCourseAutomation(config)
        automation.project_root = temp_dir
        automation.course_dir = temp_dir / "mcp_knowledge_base" / "cloud_master"
        
        #  
        result = automation.run_course_automation()
        
        assert result == True  # 누락된 도구가 있어도 계속 진행

class TestDay2Scripts:
    """Day 2  """
    
    @pytest.fixture
    def temp_dir(self):
        """  """
        temp_dir = tempfile.mkdtemp()
        yield Path(temp_dir)
        shutil.rmtree(temp_dir)
    
    def test_docker_advanced_script(self, temp_dir):
        """Docker   """
        from master_course_day2_scripts import create_docker_advanced_script
        
        course_dir = temp_dir / "course"
        course_dir.mkdir(parents=True)
        
        #  
        (course_dir / "automation" / "day2").mkdir(parents=True, exist_ok=True)
        
        create_docker_advanced_script(course_dir)
        
        script_path = course_dir / "automation" / "day2" / "docker_advanced.sh"
        assert script_path.exists()
        
        script_content = script_path.read_text(encoding='utf-8')
        assert "Docker  " in script_content
        assert " " in script_content
        assert "docker-compose.advanced.yml" in script_content
    
    def test_advanced_cicd_script(self, temp_dir):
        """ CI/CD  """
        from master_course_day2_scripts import create_advanced_cicd_script
        
        course_dir = temp_dir / "course"
        course_dir.mkdir(parents=True)
        
        #  
        (course_dir / "automation" / "day2").mkdir(parents=True, exist_ok=True)
        
        create_advanced_cicd_script(course_dir)
        
        script_path = course_dir / "automation" / "day2" / "advanced_cicd.sh"
        assert script_path.exists()
        
        script_content = script_path.read_text(encoding='utf-8')
        assert " CI/CD " in script_content
        assert "matrix" in script_content
        assert "security-scan" in script_content
    
    def test_container_orchestration_script(self, temp_dir):
        """   """
        from master_course_day2_scripts import create_container_orchestration_script
        
        course_dir = temp_dir / "course"
        course_dir.mkdir(parents=True)
        
        #  
        (course_dir / "automation" / "day2").mkdir(parents=True, exist_ok=True)
        
        create_container_orchestration_script(course_dir)
        
        script_path = course_dir / "automation" / "day2" / "container_orchestration.sh"
        assert script_path.exists()
        
        script_content = script_path.read_text(encoding='utf-8')
        assert " " in script_content
        assert "docker swarm" in script_content
        assert "kubernetes" in script_content

class TestDay3Scripts:
    """Day 3  """
    
    @pytest.fixture
    def temp_dir(self):
        """  """
        temp_dir = tempfile.mkdtemp()
        yield Path(temp_dir)
        shutil.rmtree(temp_dir)
    
    def test_load_balancing_script(self, temp_dir):
        """   """
        from master_course_day3_scripts import create_load_balancing_script
        
        course_dir = temp_dir / "course"
        course_dir.mkdir(parents=True)
        
        #  
        (course_dir / "automation" / "day3").mkdir(parents=True, exist_ok=True)
        
        create_load_balancing_script(course_dir)
        
        script_path = course_dir / "automation" / "day3" / "load_balancing.sh"
        assert script_path.exists()
        
        script_content = script_path.read_text(encoding='utf-8')
        assert " " in script_content
        assert "Application Load Balancer" in script_content
        assert "Auto Scaling" in script_content
    
    def test_monitoring_script(self, temp_dir):
        """  """
        from master_course_day3_scripts import create_monitoring_script
        
        course_dir = temp_dir / "course"
        course_dir.mkdir(parents=True)
        
        #  
        (course_dir / "automation" / "day3").mkdir(parents=True, exist_ok=True)
        
        create_monitoring_script(course_dir)
        
        script_path = course_dir / "automation" / "day3" / "monitoring.sh"
        assert script_path.exists()
        
        script_content = script_path.read_text(encoding='utf-8')
        assert "  " in script_content
        assert "Prometheus" in script_content
        assert "Grafana" in script_content
    
    def test_cost_optimization_script(self, temp_dir):
        """   """
        from master_course_day3_scripts import create_cost_optimization_script
        
        course_dir = temp_dir / "course"
        course_dir.mkdir(parents=True)
        
        #  
        (course_dir / "automation" / "day3").mkdir(parents=True, exist_ok=True)
        
        create_cost_optimization_script(course_dir)
        
        script_path = course_dir / "automation" / "day3" / "cost_optimization.sh"
        assert script_path.exists()
        
        script_content = script_path.read_text(encoding='utf-8')
        assert " " in script_content
        assert "Cost Explorer" in script_content
        assert "Reserved Instances" in script_content

if __name__ == "__main__":
    pytest.main([__file__, "-v"])
