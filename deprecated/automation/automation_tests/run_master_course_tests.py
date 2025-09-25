#!/usr/bin/env python3
"""
     
"""

import sys
import subprocess
import logging
from pathlib import Path

#  
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

def run_tests():
    """ """
    logger.info("[TEST]     ...")
    
    try:
        # pytest  
        try:
            import pytest
            logger.info(" pytest ")
        except ImportError:
            logger.error(" pytest  .")
            logger.info(" pytest  ...")
            subprocess.run([sys.executable, "-m", "pip", "install", "pytest"], check=True)
            logger.info(" pytest  ")
        
        #  
        test_file = Path(__file__).parent / "test_master_course_automation.py"
        
        logger.info(f"   : {test_file}")
        
        result = subprocess.run([
            sys.executable, "-m", "pytest", 
            str(test_file),
            "-v",
            "--tb=short",
            "--color=yes"
        ], capture_output=True, text=True)
        
        #  
        print("\n" + "="*80)
        print(" :")
        print("="*80)
        print(result.stdout)
        
        if result.stderr:
            print("\n :")
            print("-"*40)
            print(result.stderr)
        
        print("="*80)
        print(f"  : {result.returncode}")
        
        if result.returncode == 0:
            logger.info("   !")
            return True
        else:
            logger.error("   ")
            return False
            
    except Exception as e:
        logger.error(f"     : {e}")
        return False

def run_integration_test():
    """  """
    logger.info("   ...")
    
    try:
        #    
        automation_script = Path(__file__).parent / "master_course_automation.py"
        
        logger.info(f"   : {automation_script}")
        
        result = subprocess.run([
            sys.executable, str(automation_script)
        ], capture_output=True, text=True)
        
        print("\n" + "="*80)
        print("   :")
        print("="*80)
        print(result.stdout)
        
        if result.stderr:
            print("\n :")
            print("-"*40)
            print(result.stderr)
        
        print("="*80)
        print(f"  : {result.returncode}")
        
        if result.returncode == 0:
            logger.info("    !")
            return True
        else:
            logger.error("    ")
            return False
            
    except Exception as e:
        logger.error(f"      : {e}")
        return False

def check_generated_files():
    """  """
    logger.info("   ...")
    
    try:
        course_dir = Path(__file__).parent.parent / "mcp_knowledge_base" / "cloud_master"
        automation_dir = course_dir / "automation"
        
        if not automation_dir.exists():
            logger.error("    .")
            return False
        
        # Day 1  
        day1_scripts = [
            "docker_basics.sh",
            "git_github_basics.sh",
            "github_actions.sh",
            "vm_deployment.sh"
        ]
        
        for script in day1_scripts:
            script_path = automation_dir / "day1" / script
            if script_path.exists():
                logger.info(f" {script} ")
            else:
                logger.error(f" {script}  ")
                return False
        
        # Day 2  
        day2_scripts = [
            "docker_advanced.sh",
            "advanced_cicd.sh",
            "container_orchestration.sh"
        ]
        
        for script in day2_scripts:
            script_path = automation_dir / "day2" / script
            if script_path.exists():
                logger.info(f" {script} ")
            else:
                logger.error(f" {script}  ")
                return False
        
        # Day 3  
        day3_scripts = [
            "load_balancing.sh",
            "monitoring.sh",
            "cost_optimization.sh"
        ]
        
        for script in day3_scripts:
            script_path = automation_dir / "day3" / script
            if script_path.exists():
                logger.info(f" {script} ")
            else:
                logger.error(f" {script}  ")
                return False
        
        #   
        results_file = automation_dir / "results" / "automation_results.json"
        if results_file.exists():
            logger.info(" automation_results.json ")
        else:
            logger.error(" automation_results.json  ")
            return False
        
        logger.info("    .")
        return True
        
    except Exception as e:
        logger.error(f"     : {e}")
        return False

def main():
    """ """
    logger.info("      ")
    
    #   
    unit_test_success = run_tests()
    
    #   
    integration_test_success = run_integration_test()
    
    #   
    file_check_success = check_generated_files()
    
    #  
    print("\n" + "="*80)
    print("   :")
    print("="*80)
    print(f" : {' ' if unit_test_success else ' '}")
    print(f" : {' ' if integration_test_success else ' '}")
    print(f"  : {' ' if file_check_success else ' '}")
    
    overall_success = unit_test_success and integration_test_success and file_check_success
    print(f" : {' ' if overall_success else ' '}")
    print("="*80)
    
    if overall_success:
        logger.info("    !")
        return 0
    else:
        logger.error("   .")
        return 1

if __name__ == "__main__":
    sys.exit(main())
