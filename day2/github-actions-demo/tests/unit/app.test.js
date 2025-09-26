// 🧪 단위 테스트
// 애플리케이션의 개별 함수들을 테스트합니다

const request = require('supertest');
const app = require('../../src/app');

describe('애플리케이션 단위 테스트', () => {
  // 기본 라우트 테스트
  describe('GET /', () => {
    it('홈페이지가 정상적으로 응답해야 함', async () => {
      const response = await request(app).get('/');
      expect(response.status).toBe(200);
      expect(response.text).toContain('GitHub Actions Demo');
      expect(response.text).toContain('CI/CD 실습 애플리케이션');
    });
  });

  // 헬스 체크 테스트
  describe('GET /health', () => {
    it('헬스 체크가 정상적으로 응답해야 함', async () => {
      const response = await request(app).get('/health');
      expect(response.status).toBe(200);
      expect(response.body).toHaveProperty('status', 'OK');
      expect(response.body).toHaveProperty('timestamp');
      expect(response.body).toHaveProperty('uptime');
    });
  });

  // 메트릭 엔드포인트 테스트
  describe('GET /metrics', () => {
    it('메트릭이 정상적으로 응답해야 함', async () => {
      const response = await request(app).get('/metrics');
      expect(response.status).toBe(200);
      expect(response.text).toContain('http_requests_total');
    });
  });

  // API 엔드포인트 테스트
  describe('GET /api/status', () => {
    it('API 상태가 정상적으로 응답해야 함', async () => {
      const response = await request(app).get('/api/status');
      expect(response.status).toBe(200);
      expect(response.body).toHaveProperty('message', 'API is running');
    });
  });

  // 404 에러 테스트
  describe('GET /nonexistent', () => {
    it('존재하지 않는 라우트는 404를 반환해야 함', async () => {
      const response = await request(app).get('/nonexistent');
      expect(response.status).toBe(404);
    });
  });
});
