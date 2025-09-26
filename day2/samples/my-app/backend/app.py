#!/usr/bin/env python3
"""
My App Backend - 고급 Docker 및 Kubernetes 애플리케이션
"""

import os
import time
import logging
from flask import Flask, jsonify, request
from prometheus_client import Counter, Histogram, generate_latest, CONTENT_TYPE_LATEST
import psycopg2
from psycopg2.pool import SimpleConnectionPool

# 로깅 설정
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Flask 앱 생성
app = Flask(__name__)

# Prometheus 메트릭
REQUEST_COUNT = Counter('http_requests_total', 'Total HTTP requests', ['method', 'endpoint', 'status'])
REQUEST_DURATION = Histogram('http_request_duration_seconds', 'HTTP request duration', ['method', 'endpoint'])
DB_CONNECTION_COUNT = Counter('db_connections_total', 'Total database connections')
DB_QUERY_DURATION = Histogram('db_query_duration_seconds', 'Database query duration')

# 데이터베이스 연결 풀
db_pool = None

def init_db():
    """데이터베이스 연결 풀 초기화"""
    global db_pool
    try:
        db_pool = SimpleConnectionPool(
            minconn=1,
            maxconn=10,
            host=os.getenv('DB_HOST', 'localhost'),
            port=os.getenv('DB_PORT', '5432'),
            database=os.getenv('DB_NAME', 'myapp'),
            user=os.getenv('DB_USER', 'postgres'),
            password=os.getenv('DB_PASSWORD', 'password')
        )
        logger.info("Database connection pool initialized")
    except Exception as e:
        logger.error(f"Failed to initialize database: {e}")

def get_db_connection():
    """데이터베이스 연결 가져오기"""
    if not db_pool:
        init_db()
    return db_pool.getconn()

def return_db_connection(conn):
    """데이터베이스 연결 반환"""
    if db_pool:
        db_pool.putconn(conn)

@app.before_request
def before_request():
    """요청 전 처리"""
    request.start_time = time.time()

@app.after_request
def after_request(response):
    """요청 후 처리"""
    if hasattr(request, 'start_time'):
        duration = time.time() - request.start_time
        REQUEST_DURATION.labels(method=request.method, endpoint=request.endpoint).observe(duration)
    
    REQUEST_COUNT.labels(method=request.method, endpoint=request.endpoint, status=response.status_code).inc()
    return response

@app.route('/')
def index():
    """메인 페이지"""
    return jsonify({
        'message': 'My App Backend - 고급 Docker 및 Kubernetes 애플리케이션',
        'version': '2.0.0',
        'status': 'healthy',
        'timestamp': time.time()
    })

@app.route('/health')
def health():
    """헬스 체크 엔드포인트"""
    try:
        # 데이터베이스 연결 테스트
        conn = get_db_connection()
        if conn:
            with conn.cursor() as cursor:
                cursor.execute('SELECT 1')
                cursor.fetchone()
            return_db_connection(conn)
            
            return jsonify({
                'status': 'healthy',
                'database': 'connected',
                'timestamp': time.time()
            }), 200
        else:
            return jsonify({
                'status': 'unhealthy',
                'database': 'disconnected',
                'timestamp': time.time()
            }), 503
    except Exception as e:
        logger.error(f"Health check failed: {e}")
        return jsonify({
            'status': 'unhealthy',
            'error': str(e),
            'timestamp': time.time()
        }), 503

@app.route('/metrics')
def metrics():
    """Prometheus 메트릭 엔드포인트"""
    return generate_latest(), 200, {'Content-Type': CONTENT_TYPE_LATEST}

@app.route('/api/users', methods=['GET'])
def get_users():
    """사용자 목록 조회"""
    try:
        conn = get_db_connection()
        if not conn:
            return jsonify({'error': 'Database connection failed'}), 500
        
        with conn.cursor() as cursor:
            cursor.execute('SELECT id, name, email, created_at FROM users ORDER BY created_at DESC')
            users = cursor.fetchall()
            
            user_list = []
            for user in users:
                user_list.append({
                    'id': user[0],
                    'name': user[1],
                    'email': user[2],
                    'created_at': user[3].isoformat() if user[3] else None
                })
            
            return_db_connection(conn)
            return jsonify({'users': user_list}), 200
            
    except Exception as e:
        logger.error(f"Failed to get users: {e}")
        return jsonify({'error': 'Internal server error'}), 500

@app.route('/api/users', methods=['POST'])
def create_user():
    """사용자 생성"""
    try:
        data = request.get_json()
        if not data or 'name' not in data or 'email' not in data:
            return jsonify({'error': 'Name and email are required'}), 400
        
        conn = get_db_connection()
        if not conn:
            return jsonify({'error': 'Database connection failed'}), 500
        
        with conn.cursor() as cursor:
            cursor.execute(
                'INSERT INTO users (name, email) VALUES (%s, %s) RETURNING id',
                (data['name'], data['email'])
            )
            user_id = cursor.fetchone()[0]
            conn.commit()
            
            return_db_connection(conn)
            return jsonify({
                'id': user_id,
                'name': data['name'],
                'email': data['email'],
                'message': 'User created successfully'
            }), 201
            
    except Exception as e:
        logger.error(f"Failed to create user: {e}")
        return jsonify({'error': 'Internal server error'}), 500

@app.route('/api/stats')
def get_stats():
    """애플리케이션 통계"""
    try:
        conn = get_db_connection()
        if not conn:
            return jsonify({'error': 'Database connection failed'}), 500
        
        with conn.cursor() as cursor:
            cursor.execute('SELECT COUNT(*) FROM users')
            user_count = cursor.fetchone()[0]
            
            cursor.execute('SELECT COUNT(*) FROM users WHERE created_at > NOW() - INTERVAL \'1 day\'')
            new_users_today = cursor.fetchone()[0]
            
            return_db_connection(conn)
            
            return jsonify({
                'total_users': user_count,
                'new_users_today': new_users_today,
                'uptime': time.time() - app.start_time if hasattr(app, 'start_time') else 0,
                'timestamp': time.time()
            }), 200
            
    except Exception as e:
        logger.error(f"Failed to get stats: {e}")
        return jsonify({'error': 'Internal server error'}), 500

@app.route('/api/load')
def generate_load():
    """CPU 부하 생성 (테스트용)"""
    try:
        duration = int(request.args.get('duration', 10))
        intensity = int(request.args.get('intensity', 1))
        
        start_time = time.time()
        while time.time() - start_time < duration:
            # CPU 집약적 작업
            for i in range(100000 * intensity):
                _ = i ** 2
        
        return jsonify({
            'message': f'Load generated for {duration} seconds with intensity {intensity}',
            'duration': duration,
            'intensity': intensity
        }), 200
        
    except Exception as e:
        logger.error(f"Failed to generate load: {e}")
        return jsonify({'error': 'Internal server error'}), 500

if __name__ == '__main__':
    app.start_time = time.time()
    init_db()
    
    port = int(os.getenv('PORT', 3000))
    debug = os.getenv('DEBUG', 'false').lower() == 'true'
    
    logger.info(f"Starting My App Backend on port {port}")
    app.run(host='0.0.0.0', port=port, debug=debug)
