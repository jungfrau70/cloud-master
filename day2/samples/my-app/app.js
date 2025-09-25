const express = require('express');
const { MongoClient } = require('mongodb');
const redis = require('redis');

const app = express();
const port = 3000;

// MongoDB 연결
const mongoUrl = 'mongodb://admin:secret@db:27017';
const client = new MongoClient(mongoUrl);

// Redis 연결
const redisClient = redis.createClient({
  url: 'redis://redis:6379'
});

// Redis 연결 시작
redisClient.connect().catch(console.error);

app.get('/', async (req, res) => {
  try {
    // Redis에서 방문자 수 증가
    const visits = await redisClient.incr('visits');
    
    // MongoDB에서 사용자 수 조회
    await client.connect();
    const db = client.db('test');
    const userCount = await db.collection('users').countDocuments();
    
    res.send(`
      <h1>Hello Docker!</h1>
      <p>This is a simple Node.js app running in a Docker container.</p>
      <p>Current time: ${new Date().toISOString()}</p>
      <p>Total visits: ${visits}</p>
      <p>Users in database: ${userCount}</p>
    `);
  } catch (error) {
    res.status(500).send(`Error: ${error.message}`);
  }
});

app.listen(port, () => {
  console.log(`App running at http://localhost:${port}`);
});
