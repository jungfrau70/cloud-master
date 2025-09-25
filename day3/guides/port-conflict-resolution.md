# 포트 충돌 해결 가이드

## 🚨 문제 상황

Day2와 Day3에서 동일한 포트를 사용하는 모니터링 스택으로 인한 충돌:

| 서비스 | Day2 포트 | Day3 포트 | 충돌 여부 |
|--------|-----------|-----------|-----------|
| Prometheus | 9090 | 9090 | ❌ 충돌 |
| Grafana | 3001 | 3001 | ❌ 충돌 |
| Jaeger | 16686 | 16686 | ❌ 충돌 |
| Elasticsearch | 9200 | 9200 | ❌ 충돌 |
| Kibana | 5601 | 5601 | ❌ 충돌 |

## 🔧 해결 방안

### 옵션 1: Day2 모니터링 스택 중지 ["권장"]

#### Day2 모니터링 스택 중지
```bash
# Day2 프로젝트 디렉토리로 이동
cd /mnt/c/Users/["사용자명"]/mcp_cloud/mcp_knowledge_base/cloud_master/repos/samples/day2/my-app

# Docker Compose 중지
docker-compose down

# 컨테이너 완전 제거
docker-compose down --volumes --remove-orphans

# 확인
docker ps -a | grep -E "[prometheus|grafana|jaeger|elasticsearch|kibana]"
```

#### Day2 모니터링 스택 재시작 ["필요시"]
```bash
# Day2 모니터링 스택 재시작
docker-compose up -d

# 상태 확인
docker-compose ps
```

### 옵션 2: Day3 포트 변경 ["자동 적용됨"]

Day3 스크립트는 자동으로 다른 포트를 사용합니다:

| 서비스 | Day2 포트 | Day3 포트 | 상태 |
|--------|-----------|-----------|------|
| Prometheus | 9090 | 9091 | ✅ 해결 |
| Grafana | 3001 | 3002 | ✅ 해결 |
| Jaeger | 16686 | 16687 | ✅ 해결 |
| Elasticsearch | 9200 | 9201 | ✅ 해결 |
| Kibana | 5601 | 5602 | ✅ 해결 |
| Test App | 3000 | 3001 | ✅ 해결 |

### 옵션 3: 별도 Docker 네트워크 사용

#### Day3 전용 네트워크 생성
```bash
# Day3 전용 네트워크 생성
docker network create day3-monitoring

# Day3 모니터링 스택 실행
cd cloud-master-day3-practice
docker-compose --project-name day3 up -d
```

#### 네트워크 확인
```bash
# Docker 네트워크 목록
docker network ls

# Day3 네트워크 상세 정보
docker network inspect day3-monitoring
```

### 옵션 4: 수동 포트 매핑 변경

#### Day3 docker-compose.yml 수정
```yaml
version: '3.8'

services:
  prometheus:
    image: prom/prometheus:latest
    ports:
      - "9091:9090"  # 9090 → 9091로 변경
  
  grafana:
    image: grafana/grafana:latest
    ports:
      - "3002:3000"  # 3001 → 3002로 변경
  
  jaeger:
    image: jaegertracing/all-in-one:latest
    ports:
      - "16687:16686"  # 16686 → 16687로 변경
  
  elasticsearch:
    image: docker.elastic.co/elasticsearch/elasticsearch:7.15.0
    ports:
      - "9201:9200"  # 9200 → 9201로 변경
  
  kibana:
    image: docker.elastic.co/kibana/kibana:7.15.0
    ports:
      - "5602:5601"  # 5601 → 5602로 변경
```

## 🔍 충돌 확인 방법

### 포트 사용 현황 확인
```bash
# 현재 사용 중인 포트 확인
netstat -tulpn | grep -E "[9090|3001|16686|9200|5601]"

# Docker 컨테이너 포트 확인
docker ps --format "table {{.Names}}\t{{.Ports}}"
```

### Day2/Day3 서비스 상태 확인
```bash
# Day2 서비스 확인
curl -s http://localhost:9090/api/v1/status/config | jq .  # Prometheus
curl -s http://localhost:3001/api/health | jq .            # Grafana

# Day3 서비스 확인
curl -s http://localhost:9091/api/v1/status/config | jq .  # Prometheus
curl -s http://localhost:3002/api/health | jq .            # Grafana
```

## 🚀 권장 해결 순서

### 1단계: 현재 상태 확인
```bash
# 포트 사용 현황 확인
netstat -tulpn | grep -E "[9090|3001|16686|9200|5601]"

# Docker 컨테이너 확인
docker ps -a
```

### 2단계: Day2 모니터링 스택 중지
```bash
# Day2 프로젝트로 이동
cd /mnt/c/Users/["사용자명"]/mcp_cloud/mcp_knowledge_base/cloud_master/repos/samples/day2/my-app

# 모니터링 스택 중지
docker-compose down
```

### 3단계: Day3 실습 실행
```bash
# Day3 실습 시작
cd cloud-master-day3-practice
./03-monitoring-stack.sh setup
./03-monitoring-stack.sh start
```

### 4단계: 서비스 접속 확인
```bash
# Day3 모니터링 서비스 접속
echo "Prometheus: http://localhost:9091"
echo "Grafana: http://localhost:3002 [admin/admin]"
echo "Jaeger: http://localhost:16687"
echo "Elasticsearch: http://localhost:9201"
echo "Kibana: http://localhost:5602"
```

## 🔄 실습 완료 후 정리

### Day3 모니터링 스택 중지
```bash
# Day3 모니터링 스택 중지
./03-monitoring-stack.sh cleanup

# 또는 Docker Compose로 직접 중지
docker-compose down --volumes --remove-orphans
```

### Day2 모니터링 스택 재시작 ["필요시"]
```bash
# Day2 프로젝트로 이동
cd /mnt/c/Users/["사용자명"]/mcp_cloud/mcp_knowledge_base/cloud_master/repos/samples/day2/my-app

# 모니터링 스택 재시작
docker-compose up -d
```

## ⚠️ 주의사항

1. **데이터 손실 방지**: 모니터링 데이터가 중요한 경우 백업 후 진행
2. **서비스 의존성**: 다른 서비스가 모니터링 스택에 의존하는 경우 확인
3. **포트 충돌**: 다른 애플리케이션과의 포트 충돌 가능성 확인
4. **리소스 사용량**: 동시 실행 시 메모리 및 CPU 사용량 증가

## 📚 관련 자료

- ["WSL → Cloud VM 설정 가이드"][wsl-to-vm-setup.md]
- ["문제 해결 가이드"][troubleshooting.md]
- ["Docker 네트워킹 가이드"][https://docs.docker.com/network/]
