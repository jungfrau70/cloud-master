// Day1 - Basic Express Application
// Cloud Master Day1 강의안 기반

const express = require('express');
const app = express();
const PORT = process.env.PORT || 3000;

// 기본 미들웨어
app.use(express.json());
app.use(express.static('public'));

// 기본 라우트
app.get('/', (req, res) => {
  res.json({
    message: 'Cloud Master Day1 - Basic CI/CD Pipeline',
    version: '1.0.0',
    environment: process.env.NODE_ENV || 'development',
    timestamp: new Date().toISOString()
  });
});

// 헬스 체크 엔드포인트
app.get('/health', (req, res) => {
  res.json({
    status: 'healthy',
    uptime: process.uptime(),
    timestamp: new Date().toISOString()
  });
});

// API 엔드포인트
app.get('/api/info', (req, res) => {
  res.json({
    service: 'github-actions-demo',
    day: 1,
    features: [
      'Basic Express Server',
      'Health Check Endpoint',
      'Docker Containerization',
      'GitHub Actions CI/CD'
    ]
  });
});

// 서버 시작
app.listen(PORT, () => {
  console.log(`🚀 Day1 Server running on port ${PORT}`);
  console.log(`📊 Health check: http://localhost:${PORT}/health`);
  console.log(`ℹ️  API info: http://localhost:${PORT}/api/info`);
});

module.exports = app;