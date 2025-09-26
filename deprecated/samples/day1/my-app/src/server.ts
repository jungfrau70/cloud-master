import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import morgan from 'morgan';
import dotenv from 'dotenv';

// 환경 변수 로드
dotenv.config();

const app = express();
const PORT = process.env.PORT || 8080;

// 미들웨어 설정
app.use(helmet());
app.use(cors());
app.use(morgan('combined'));
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// 정적 파일 서빙
app.use(express.static('public'));

// 기본 라우트
app.get('/', (req, res) => {
  res.json({
    message: 'MCP Cloud Master Day1 실습 애플리케이션',
    version: '1.0.0',
    environment: process.env.NODE_ENV || 'development',
    timestamp: new Date().toISOString(),
    uptime: process.uptime()
  });
});

// 헬스체크 엔드포인트
app.get('/health', (req, res) => {
  res.status(200).json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    memory: process.memoryUsage(),
    version: process.version
  });
});

// API 라우트
app.get('/api/info', (req, res) => {
  res.json({
    app: 'MCP Cloud Master Day1',
    description: 'Docker 및 VM 배포 실습용 애플리케이션',
    features: [
      'Docker 컨테이너화',
      'AWS EC2 배포',
      'GCP Compute Engine 배포',
      'GitHub Actions CI/CD',
      'Docker Hub 자동 푸시'
    ],
    endpoints: [
      'GET / - 메인 페이지',
      'GET /health - 헬스체크',
      'GET /api/info - API 정보',
      'GET /api/status - 상태 정보'
    ]
  });
});

// 상태 정보 엔드포인트
app.get('/api/status', (req, res) => {
  res.json({
    status: 'running',
    environment: process.env.NODE_ENV || 'development',
    nodeVersion: process.version,
    platform: process.platform,
    arch: process.arch,
    uptime: process.uptime(),
    memory: process.memoryUsage(),
    timestamp: new Date().toISOString()
  });
});

// 404 핸들러
app.use('*', (req, res) => {
  res.status(404).json({
    error: 'Not Found',
    message: `경로를 찾을 수 없습니다: ${req.originalUrl}`,
    timestamp: new Date().toISOString()
  });
});

// 에러 핸들러
app.use((err: Error, req: express.Request, res: express.Response, next: express.NextFunction) => {
  console.error('Error:', err);
  res.status(500).json({
    error: 'Internal Server Error',
    message: process.env.NODE_ENV === 'production' ? '서버 오류가 발생했습니다.' : err.message,
    timestamp: new Date().toISOString()
  });
});

// 서버 시작
app.listen(PORT, '0.0.0.0', () => {
  console.log(`🚀 MCP Cloud Master Day1 애플리케이션이 포트 ${PORT}에서 실행 중입니다.`);
  console.log(`📊 환경: ${process.env.NODE_ENV || 'development'}`);
  console.log(`🌐 URL: http://localhost:${PORT}`);
  console.log(`❤️  헬스체크: http://localhost:${PORT}/health`);
});

// Graceful shutdown
process.on('SIGTERM', () => {
  console.log('SIGTERM 신호를 받았습니다. 서버를 종료합니다...');
  process.exit(0);
});

process.on('SIGINT', () => {
  console.log('SIGINT 신호를 받았습니다. 서버를 종료합니다...');
  process.exit(0);
});
