#!/usr/bin/env python3
"""
통합 자동화 실행 스크립트
"""

import sys
import os
import argparse
from pathlib import Path

# 현재 디렉토리를 Python 경로에 추가
current_dir = Path(__file__).parent
sys.path.insert(0, str(current_dir))

def main():
    """메인 함수"""
    parser = argparse.ArgumentParser(description='통합 클라우드 과정 자동화 실행')
    parser.add_argument('--start-from', choices=['basic', 'master', 'container'], 
                       default='basic', help='시작할 과정 (기본값: basic)')
    parser.add_argument('--config', type=str, default='integrated_config.json',
                       help='설정 파일 경로 (기본값: integrated_config.json)')
    parser.add_argument('--validate-only', action='store_true',
                       help='검증만 실행하고 실제 자동화는 실행하지 않음')
    parser.add_argument('--validate-connections', action='store_true',
                       help='과정 간 연결성 검증 실행')
    parser.add_argument('--dry-run', action='store_true',
                       help='실행 계획만 표시하고 실제 실행은 하지 않음')
    
    args = parser.parse_args()
    
    print("🚀 통합 클라우드 과정 자동화 시스템")
    print("=" * 50)
    
    # 검증 도구 실행
    if args.validate_connections:
        print("🔍 과정 간 연결성 검증 실행 중...")
        from validate_course_connections import CourseConnectionValidator
        
        validator = CourseConnectionValidator(Path('.').resolve())
        results = validator.run_full_validation()
        
        if results['overall_status'] == 'passed':
            print("✅ 연결성 검증 통과")
        else:
            print("❌ 연결성 검증 실패 - 문제를 해결한 후 다시 실행하세요")
            return 1
    
    if args.validate_only:
        print("🔍 통합 자동화 시스템 검증 실행 중...")
        from validate_integration import IntegrationValidator
        
        validator = IntegrationValidator(Path('.').resolve())
        results = validator.run_full_validation()
        
        if results['overall_status'] == 'passed':
            print("✅ 시스템 검증 통과")
        else:
            print("❌ 시스템 검증 실패 - 문제를 해결한 후 다시 실행하세요")
            return 1
        
        return 0
    
    # 실제 자동화 실행
    if args.dry_run:
        print("📋 실행 계획:")
        print(f"  - 시작 과정: {args.start_from}")
        print(f"  - 설정 파일: {args.config}")
        print("  - 실제 실행은 하지 않음 (dry-run 모드)")
        return 0
    
    print(f"🎯 시작 과정: {args.start_from}")
    print(f"⚙️ 설정 파일: {args.config}")
    
    try:
        from integrated_course_automation import IntegratedCourseAutomation
        
        # 통합 자동화 실행
        automation = IntegratedCourseAutomation(Path('.').resolve())
        result = automation.run_integrated_courses(
            start_from=args.start_from,
            config_file=args.config
        )
        
        if result:
            print("🎉 통합 자동화 완료!")
            return 0
        else:
            print("❌ 통합 자동화 실패")
            return 1
            
    except ImportError as e:
        print(f"❌ 모듈 import 오류: {e}")
        print("필요한 의존성을 설치하세요: pip install -r requirements.txt")
        return 1
    except Exception as e:
        print(f"❌ 실행 오류: {e}")
        return 1

if __name__ == "__main__":
    sys.exit(main())
