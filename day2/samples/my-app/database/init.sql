-- My App 데이터베이스 초기화 스크립트

-- 사용자 테이블 생성
CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 인덱스 생성
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_users_created_at ON users(created_at);

-- 샘플 데이터 삽입
INSERT INTO users (name, email) VALUES 
    ('John Doe', 'john.doe@example.com'),
    ('Jane Smith', 'jane.smith@example.com'),
    ('Bob Johnson', 'bob.johnson@example.com'),
    ('Alice Brown', 'alice.brown@example.com'),
    ('Charlie Wilson', 'charlie.wilson@example.com')
ON CONFLICT (email) DO NOTHING;

-- 업데이트 시간 자동 갱신 함수
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- 트리거 생성
CREATE TRIGGER update_users_updated_at 
    BEFORE UPDATE ON users 
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

-- 뷰 생성 (통계용)
CREATE OR REPLACE VIEW user_stats AS
SELECT 
    COUNT(*) as total_users,
    COUNT(CASE WHEN created_at > CURRENT_DATE THEN 1 END) as new_users_today,
    COUNT(CASE WHEN created_at > CURRENT_DATE - INTERVAL '7 days' THEN 1 END) as new_users_week,
    COUNT(CASE WHEN created_at > CURRENT_DATE - INTERVAL '30 days' THEN 1 END) as new_users_month
FROM users;

-- 함수 생성 (사용자 생성)
CREATE OR REPLACE FUNCTION create_user(
    p_name VARCHAR(100),
    p_email VARCHAR(255)
)
RETURNS TABLE(
    user_id INTEGER,
    user_name VARCHAR(100),
    user_email VARCHAR(255),
    created_at TIMESTAMP
) AS $$
BEGIN
    INSERT INTO users (name, email) 
    VALUES (p_name, p_email)
    RETURNING id, name, email, created_at
    INTO user_id, user_name, user_email, created_at;
    
    RETURN NEXT;
END;
$$ LANGUAGE plpgsql;

-- 함수 생성 (사용자 통계)
CREATE OR REPLACE FUNCTION get_user_statistics()
RETURNS TABLE(
    total_users BIGINT,
    new_users_today BIGINT,
    new_users_week BIGINT,
    new_users_month BIGINT
) AS $$
BEGIN
    RETURN QUERY
    SELECT * FROM user_stats;
END;
$$ LANGUAGE plpgsql;

-- 권한 설정
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO postgres;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO postgres;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO postgres;
