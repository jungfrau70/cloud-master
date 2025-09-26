import React, { useState, useEffect } from 'react';
import styled from 'styled-components';
import { QueryClient, QueryClientProvider, useQuery } from 'react-query';
import axios from 'axios';
import { LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer } from 'recharts';

// API 기본 URL 설정
const API_BASE_URL = process.env.REACT_APP_API_URL || 'http://localhost:3000';

// React Query 클라이언트 생성
const queryClient = new QueryClient();

// 스타일드 컴포넌트
const Container = styled.div`
  max-width: 1200px;
  margin: 0 auto;
  padding: 20px;
  font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
`;

const Header = styled.header`
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  color: white;
  padding: 2rem;
  border-radius: 10px;
  margin-bottom: 2rem;
  text-align: center;
`;

const Title = styled.h1`
  margin: 0;
  font-size: 2.5rem;
  font-weight: 300;
`;

const Subtitle = styled.p`
  margin: 0.5rem 0 0 0;
  font-size: 1.2rem;
  opacity: 0.9;
`;

const Grid = styled.div`
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
  gap: 2rem;
  margin-bottom: 2rem;
`;

const Card = styled.div`
  background: white;
  border-radius: 10px;
  padding: 1.5rem;
  box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
  border: 1px solid #e1e5e9;
`;

const CardTitle = styled.h3`
  margin: 0 0 1rem 0;
  color: #333;
  font-size: 1.3rem;
`;

const Button = styled.button`
  background: #667eea;
  color: white;
  border: none;
  padding: 0.75rem 1.5rem;
  border-radius: 5px;
  cursor: pointer;
  font-size: 1rem;
  margin: 0.5rem;
  transition: background 0.3s;

  &:hover {
    background: #5a6fd8;
  }

  &:disabled {
    background: #ccc;
    cursor: not-allowed;
  }
`;

const Input = styled.input`
  width: 100%;
  padding: 0.75rem;
  border: 1px solid #ddd;
  border-radius: 5px;
  font-size: 1rem;
  margin: 0.5rem 0;
  box-sizing: border-box;
`;

const StatusIndicator = styled.div`
  display: inline-block;
  width: 10px;
  height: 10px;
  border-radius: 50%;
  background: ${props => props.status === 'healthy' ? '#4CAF50' : '#F44336'};
  margin-right: 0.5rem;
`;

const ErrorMessage = styled.div`
  color: #F44336;
  background: #ffebee;
  padding: 1rem;
  border-radius: 5px;
  margin: 1rem 0;
`;

// API 함수들
const api = {
  getHealth: () => axios.get(`${API_BASE_URL}/health`),
  getStats: () => axios.get(`${API_BASE_URL}/api/stats`),
  getUsers: () => axios.get(`${API_BASE_URL}/api/users`),
  createUser: (userData) => axios.post(`${API_BASE_URL}/api/users`, userData),
  generateLoad: (duration, intensity) => axios.get(`${API_BASE_URL}/api/load?duration=${duration}&intensity=${intensity}`)
};

// 헬스 체크 컴포넌트
function HealthCheck() {
  const { data: health, isLoading, error } = useQuery('health', api.getHealth, {
    refetchInterval: 30000, // 30초마다 갱신
  });

  if (isLoading) return <div>Loading health status...</div>;
  if (error) return <ErrorMessage>Failed to check health status</ErrorMessage>;

  return (
    <Card>
      <CardTitle>System Health</CardTitle>
      <div>
        <StatusIndicator status={health?.data?.status} />
        Status: {health?.data?.status || 'Unknown'}
      </div>
      <div>Database: {health?.data?.database || 'Unknown'}</div>
      <div>Timestamp: {new Date(health?.data?.timestamp * 1000).toLocaleString()}</div>
    </Card>
  );
}

// 통계 컴포넌트
function Stats() {
  const { data: stats, isLoading, error } = useQuery('stats', api.getStats, {
    refetchInterval: 10000, // 10초마다 갱신
  });

  if (isLoading) return <div>Loading stats...</div>;
  if (error) return <ErrorMessage>Failed to load stats</ErrorMessage>;

  const chartData = [
    { name: 'Total Users', value: stats?.data?.total_users || 0 },
    { name: 'New Today', value: stats?.data?.new_users_today || 0 },
  ];

  return (
    <Card>
      <CardTitle>Application Statistics</CardTitle>
      <div>Total Users: {stats?.data?.total_users || 0}</div>
      <div>New Users Today: {stats?.data?.new_users_today || 0}</div>
      <div>Uptime: {Math.floor((stats?.data?.uptime || 0) / 60)} minutes</div>
      
      <ResponsiveContainer width="100%" height={200}>
        <LineChart data={chartData}>
          <CartesianGrid strokeDasharray="3 3" />
          <XAxis dataKey="name" />
          <YAxis />
          <Tooltip />
          <Line type="monotone" dataKey="value" stroke="#667eea" strokeWidth={2} />
        </LineChart>
      </ResponsiveContainer>
    </Card>
  );
}

// 사용자 관리 컴포넌트
function UserManagement() {
  const [name, setName] = useState('');
  const [email, setEmail] = useState('');
  const [isCreating, setIsCreating] = useState(false);

  const { data: users, isLoading, error, refetch } = useQuery('users', api.getUsers);

  const handleCreateUser = async (e) => {
    e.preventDefault();
    if (!name || !email) return;

    setIsCreating(true);
    try {
      await api.createUser({ name, email });
      setName('');
      setEmail('');
      refetch();
    } catch (err) {
      console.error('Failed to create user:', err);
    } finally {
      setIsCreating(false);
    }
  };

  if (isLoading) return <div>Loading users...</div>;
  if (error) return <ErrorMessage>Failed to load users</ErrorMessage>;

  return (
    <Card>
      <CardTitle>User Management</CardTitle>
      
      <form onSubmit={handleCreateUser}>
        <Input
          type="text"
          placeholder="Name"
          value={name}
          onChange={(e) => setName(e.target.value)}
          required
        />
        <Input
          type="email"
          placeholder="Email"
          value={email}
          onChange={(e) => setEmail(e.target.value)}
          required
        />
        <Button type="submit" disabled={isCreating}>
          {isCreating ? 'Creating...' : 'Create User'}
        </Button>
      </form>

      <div style={{ marginTop: '1rem' }}>
        <h4>Users ({users?.data?.users?.length || 0})</h4>
        {users?.data?.users?.map(user => (
          <div key={user.id} style={{ padding: '0.5rem', borderBottom: '1px solid #eee' }}>
            <strong>{user.name}</strong> - {user.email}
            <br />
            <small>Created: {new Date(user.created_at).toLocaleString()}</small>
          </div>
        ))}
      </div>
    </Card>
  );
}

// 부하 테스트 컴포넌트
function LoadTest() {
  const [isRunning, setIsRunning] = useState(false);
  const [duration, setDuration] = useState(10);
  const [intensity, setIntensity] = useState(1);

  const handleLoadTest = async () => {
    setIsRunning(true);
    try {
      await api.generateLoad(duration, intensity);
      alert(`Load test completed: ${duration}s with intensity ${intensity}`);
    } catch (err) {
      console.error('Load test failed:', err);
      alert('Load test failed');
    } finally {
      setIsRunning(false);
    }
  };

  return (
    <Card>
      <CardTitle>Load Test</CardTitle>
      <div>
        <label>Duration (seconds): </label>
        <Input
          type="number"
          value={duration}
          onChange={(e) => setDuration(parseInt(e.target.value))}
          min="1"
          max="60"
        />
      </div>
      <div>
        <label>Intensity: </label>
        <Input
          type="number"
          value={intensity}
          onChange={(e) => setIntensity(parseInt(e.target.value))}
          min="1"
          max="10"
        />
      </div>
      <Button onClick={handleLoadTest} disabled={isRunning}>
        {isRunning ? 'Running...' : 'Start Load Test'}
      </Button>
    </Card>
  );
}

// 메인 앱 컴포넌트
function App() {
  return (
    <QueryClientProvider client={queryClient}>
      <Container>
        <Header>
          <Title>My App</Title>
          <Subtitle>고급 Docker 및 Kubernetes 애플리케이션</Subtitle>
        </Header>

        <Grid>
          <HealthCheck />
          <Stats />
          <UserManagement />
          <LoadTest />
        </Grid>
      </Container>
    </QueryClientProvider>
  );
}

export default App;
