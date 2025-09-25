// 🔗 통합 테스트
// 전체 시스템의 통합 동작을 테스트합니다

const request = require('supertest');
const app = require('../../src/app');

describe('통합 테스트', () => {
  // 전체 워크플로우 테스트
  describe('전체 애플리케이션 워크플로우', () => {
    it('애플리케이션이 완전히 시작되어야 함', async () => {
      // 1. 기본 페이지 접근
      const homeResponse = await request(app).get('/');
      expect(homeResponse.status).toBe(200);

      // 2. 헬스 체크
      const healthResponse = await request(app).get('/health');
      expect(healthResponse.status).toBe(200);
      expect(healthResponse.body.status).toBe('OK');

      // 3. API 상태 확인
      const apiResponse = await request(app).get('/api/status');
      expect(apiResponse.status).toBe(200);

      // 4. 메트릭 확인
      const metricsResponse = await request(app).get('/metrics');
      expect(metricsResponse.status).toBe(200);
    });
  });

  // 성능 테스트
  describe('성능 테스트', () => {
    it('응답 시간이 1초 이내여야 함', async () => {
      const startTime = Date.now();
      const response = await request(app).get('/health');
      const endTime = Date.now();
      
      expect(response.status).toBe(200);
      expect(endTime - startTime).toBeLessThan(1000);
    });

    it('동시 요청을 처리할 수 있어야 함', async () => {
      const promises = Array(10).fill().map(() => 
        request(app).get('/health')
      );
      
      const responses = await Promise.all(promises);
      
      responses.forEach(response => {
        expect(response.status).toBe(200);
      });
    });
  });

  // 에러 처리 테스트
  describe('에러 처리', () => {
    it('잘못된 요청을 적절히 처리해야 함', async () => {
      const response = await request(app)
        .post('/api/status')
        .send({ invalid: 'data' });
      
      expect(response.status).toBe(404);
    });

    it('CORS가 올바르게 설정되어야 함', async () => {
      const response = await request(app)
        .get('/health')
        .set('Origin', 'http://localhost:3000');
      
      expect(response.status).toBe(200);
      expect(response.headers['access-control-allow-origin']).toBeDefined();
    });
  });

  // 메트릭 수집 테스트
  describe('메트릭 수집', () => {
    it('요청 메트릭이 올바르게 수집되어야 함', async () => {
      // 여러 요청 보내기
      await request(app).get('/');
      await request(app).get('/health');
      await request(app).get('/api/status');

      const metricsResponse = await request(app).get('/metrics');
      expect(metricsResponse.status).toBe(200);
      
      const metrics = metricsResponse.text;
      expect(metrics).toContain('http_requests_total');
      expect(metrics).toContain('http_request_duration_seconds');
    });
  });
});
