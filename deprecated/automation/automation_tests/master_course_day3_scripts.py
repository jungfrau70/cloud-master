#!/usr/bin/env python3
"""
Day 3   
 , ,  
"""

import os
from pathlib import Path

def create_load_balancing_script(course_dir: Path):
    """   Auto Scaling  """
    script_content = '''#!/bin/bash
#    Auto Scaling  

set -e

echo "    Auto Scaling  ..."

# AWS Application Load Balancer 
cat > aws-alb-setup.sh << 'EOF'
#!/bin/bash
# AWS Application Load Balancer 

set -e

# VPC 
VPC_ID=$(aws ec2 create-vpc \
    --cidr-block 10.0.0.0/16 \
    --query 'Vpc.VpcId' \
    --output text)

echo " VPC : $VPC_ID"

#     
IGW_ID=$(aws ec2 create-internet-gateway \
    --query 'InternetGateway.InternetGatewayId' \
    --output text)

aws ec2 attach-internet-gateway \
    --vpc-id $VPC_ID \
    --internet-gateway-id $IGW_ID

#   
SUBNET_1=$(aws ec2 create-subnet \
    --vpc-id $VPC_ID \
    --cidr-block 10.0.1.0/24 \
    --availability-zone us-west-2a \
    --query 'Subnet.SubnetId' \
    --output text)

SUBNET_2=$(aws ec2 create-subnet \
    --vpc-id $VPC_ID \
    --cidr-block 10.0.2.0/24 \
    --availability-zone us-west-2b \
    --query 'Subnet.SubnetId' \
    --output text)

#   
ROUTE_TABLE_ID=$(aws ec2 create-route-table \
    --vpc-id $VPC_ID \
    --query 'RouteTable.RouteTableId' \
    --output text)

aws ec2 create-route \
    --route-table-id $ROUTE_TABLE_ID \
    --destination-cidr-block 0.0.0.0/0 \
    --gateway-id $IGW_ID

aws ec2 associate-route-table \
    --subnet-id $SUBNET_1 \
    --route-table-id $ROUTE_TABLE_ID

aws ec2 associate-route-table \
    --subnet-id $SUBNET_2 \
    --route-table-id $ROUTE_TABLE_ID

#   
SECURITY_GROUP_ID=$(aws ec2 create-security-group \
    --group-name alb-sg \
    --description "Security group for ALB" \
    --vpc-id $VPC_ID \
    --query 'GroupId' \
    --output text)

#    
aws ec2 authorize-security-group-ingress \
    --group-id $SECURITY_GROUP_ID \
    --protocol tcp \
    --port 80 \
    --cidr 0.0.0.0/0

aws ec2 authorize-security-group-ingress \
    --group-id $SECURITY_GROUP_ID \
    --protocol tcp \
    --port 443 \
    --cidr 0.0.0.0/0

# Application Load Balancer 
ALB_ARN=$(aws elbv2 create-load-balancer \
    --name sample-alb \
    --subnets $SUBNET_1 $SUBNET_2 \
    --security-groups $SECURITY_GROUP_ID \
    --query 'LoadBalancers[0].LoadBalancerArn' \
    --output text)

echo " ALB : $ALB_ARN"

#   
TARGET_GROUP_ARN=$(aws elbv2 create-target-group \
    --name sample-targets \
    --protocol HTTP \
    --port 80 \
    --vpc-id $VPC_ID \
    --health-check-path /health \
    --query 'TargetGroups[0].TargetGroupArn' \
    --output text)

echo "   : $TARGET_GROUP_ARN"

#  
aws elbv2 create-listener \
    --load-balancer-arn $ALB_ARN \
    --protocol HTTP \
    --port 80 \
    --default-actions Type=forward,TargetGroupArn=$TARGET_GROUP_ARN

echo " AWS ALB  !"
EOF

# GCP Cloud Load Balancing 
cat > gcp-lb-setup.sh << 'EOF'
#!/bin/bash
# GCP Cloud Load Balancing 

set -e

#   
gcloud compute instance-templates create sample-template \
    --image-family=ubuntu-2004-lts \
    --image-project=ubuntu-os-cloud \
    --machine-type=e2-micro \
    --boot-disk-size=10GB \
    --tags=http-server \
    --metadata-from-file startup-script=startup-script.sh

#    
gcloud compute instance-groups managed create sample-group \
    --template=sample-template \
    --size=3 \
    --zone=us-west1-a

# Health Check 
gcloud compute health-checks create http sample-health-check \
    --port=80 \
    --request-path=/health

#   
gcloud compute backend-services create sample-backend \
    --protocol=HTTP \
    --health-checks=sample-health-check \
    --global

#    
gcloud compute backend-services add-backend sample-backend \
    --instance-group=sample-group \
    --instance-group-zone=us-west1-a \
    --global

# URL  
gcloud compute url-maps create sample-url-map \
    --default-service=sample-backend

# HTTP  
gcloud compute target-http-proxies create sample-proxy \
    --url-map=sample-url-map

#  IP  
gcloud compute addresses create sample-ip \
    --global

#   
gcloud compute forwarding-rules create sample-rule \
    --global \
    --target-http-proxy=sample-proxy \
    --address=sample-ip \
    --ports=80

echo " GCP Cloud Load Balancing  !"
EOF

# Auto Scaling 
cat > autoscaling-setup.sh << 'EOF'
#!/bin/bash
# Auto Scaling 

set -e

# AWS Auto Scaling Group 
cat > launch-template.json << 'JSONEOF'
{
    "LaunchTemplateName": "sample-template",
    "LaunchTemplateData": {
        "ImageId": "ami-0c02fb55956c7d316",
        "InstanceType": "t3.micro",
        "SecurityGroupIds": ["sg-12345678"],
        "UserData": "IyEvYmluL2Jhc2gKc3VkbyB5dW0gdXBkYXRlIC15CnN1ZG8geXVtIGluc3RhbGwgLXkgZG9ja2VyCnN1ZG8gc3lzdGVtY3RsIHN0YXJ0IGRvY2tlcgpzdWRvIHN5c3RlbWN0bCBlbmFibGUgZG9ja2VyCnN1ZG8gZG9ja2VyIHB1bGwgZG9ja2VyL2hlbGxvLXdvcmxkCnN1ZG8gZG9ja2VyIHJ1biAtZCBwIDgwOjgwIGRvY2tlci9oZWxsby13b3JsZA=="
    }
}
JSONEOF

# Auto Scaling Group 
aws autoscaling create-auto-scaling-group \
    --auto-scaling-group-name sample-asg \
    --launch-template LaunchTemplateName=sample-template,Version=1 \
    --min-size 1 \
    --max-size 10 \
    --desired-capacity 3 \
    --target-group-arns $TARGET_GROUP_ARN \
    --health-check-type ELB \
    --health-check-grace-period 300

#   
aws autoscaling put-scaling-policy \
    --auto-scaling-group-name sample-asg \
    --policy-name scale-up-policy \
    --policy-type TargetTrackingScaling \
    --target-tracking-configuration '{
        "TargetValue": 70.0,
        "PredefinedMetricSpecification": {
            "PredefinedMetricType": "ASGAverageCPUUtilization"
        }
    }'

echo " Auto Scaling  !"
EOF

#   
cat > load-test.sh << 'EOF'
#!/bin/bash
#   

set -e

# Apache Bench  (Ubuntu/Debian)
if ! command -v ab &> /dev/null; then
    sudo apt-get update
    sudo apt-get install -y apache2-utils
fi

#   
echo "[TEST]   ..."
ab -n 1000 -c 10 http://your-load-balancer-url/

#  
echo "    :"
echo "-   : 1000"
echo "-   : 10"
echo "-    "
echo "-    "
echo "-  "

echo "   !"
EOF

chmod +x aws-alb-setup.sh gcp-lb-setup.sh autoscaling-setup.sh load-test.sh

echo "    Auto Scaling   !"
'''

    script_path = course_dir / "automation" / "day3" / "load_balancing.sh"
    script_path.write_text(script_content, encoding='utf-8')
    script_path.chmod(0o755)

def create_monitoring_script(course_dir: Path):
    """     """
    script_content = '''#!/bin/bash
#      

set -e

echo "      ..."

# Prometheus 
cat > prometheus.yml << 'EOF'
global:
  scrape_interval: 15s
  evaluation_interval: 15s

rule_files:
  - "alert_rules.yml"

alerting:
  alertmanagers:
    - static_configs:
        - targets:
          - alertmanager:9093

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'node-exporter'
    static_configs:
      - targets: ['node-exporter:9100']

  - job_name: 'cadvisor'
    static_configs:
      - targets: ['cadvisor:8080']

  - job_name: 'sample-app'
    static_configs:
      - targets: ['sample-app:3000']
    metrics_path: /metrics
    scrape_interval: 5s
EOF

# Grafana  
cat > grafana-dashboard.json << 'EOF'
{
  "dashboard": {
    "id": null,
    "title": "Sample App Dashboard",
    "tags": ["sample", "app"],
    "style": "dark",
    "timezone": "browser",
    "panels": [
      {
        "id": 1,
        "title": "CPU Usage",
        "type": "graph",
        "targets": [
          {
            "expr": "100 - (avg by (instance) (irate(node_cpu_seconds_total{mode=\"idle\"}[5m])) * 100)",
            "legendFormat": "CPU Usage %"
          }
        ],
        "yAxes": [
          {
            "label": "Percentage",
            "min": 0,
            "max": 100
          }
        ]
      },
      {
        "id": 2,
        "title": "Memory Usage",
        "type": "graph",
        "targets": [
          {
            "expr": "100 - ((node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) * 100)",
            "legendFormat": "Memory Usage %"
          }
        ],
        "yAxes": [
          {
            "label": "Percentage",
            "min": 0,
            "max": 100
          }
        ]
      },
      {
        "id": 3,
        "title": "HTTP Requests",
        "type": "graph",
        "targets": [
          {
            "expr": "rate(http_requests_total[5m])",
            "legendFormat": "Requests/sec"
          }
        ]
      }
    ],
    "time": {
      "from": "now-1h",
      "to": "now"
    },
    "refresh": "5s"
  }
}
EOF

# Docker Compose  
cat > docker-compose.monitoring.yml << 'EOF'
version: '3.8'
services:
  prometheus:
    image: prom/prometheus:latest
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
      - prometheus_data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--web.console.libraries=/etc/prometheus/console_libraries'
      - '--web.console.templates=/etc/prometheus/consoles'
      - '--storage.tsdb.retention.time=200h'
      - '--web.enable-lifecycle'

  grafana:
    image: grafana/grafana:latest
    ports:
      - "3001:3000"
    volumes:
      - grafana_data:/var/lib/grafana
      - ./grafana-dashboard.json:/var/lib/grafana/dashboards/sample-dashboard.json
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin
      - GF_USERS_ALLOW_SIGN_UP=false

  node-exporter:
    image: prom/node-exporter:latest
    ports:
      - "9100:9100"
    volumes:
      - /proc:/host/proc:ro
      - /sys:/host/sys:ro
      - /:/rootfs:ro
    command:
      - '--path.procfs=/host/proc'
      - '--path.rootfs=/rootfs'
      - '--path.sysfs=/host/sys'
      - '--collector.filesystem.mount-points-exclude=^/(sys|proc|dev|host|etc)($$|/)'

  cadvisor:
    image: gcr.io/cadvisor/cadvisor:latest
    ports:
      - "8080:8080"
    volumes:
      - /:/rootfs:ro
      - /var/run:/var/run:ro
      - /sys:/sys:ro
      - /var/lib/docker/:/var/lib/docker:ro
      - /dev/disk/:/dev/disk:ro
    privileged: true
    devices:
      - /dev/kmsg

  alertmanager:
    image: prom/alertmanager:latest
    ports:
      - "9093:9093"
    volumes:
      - ./alertmanager.yml:/etc/alertmanager/alertmanager.yml
      - alertmanager_data:/alertmanager

volumes:
  prometheus_data:
  grafana_data:
  alertmanager_data:
EOF

# Alert Manager 
cat > alertmanager.yml << 'EOF'
global:
  smtp_smarthost: 'localhost:587'
  smtp_from: 'alerts@example.com'

route:
  group_by: ['alertname']
  group_wait: 10s
  group_interval: 10s
  repeat_interval: 1h
  receiver: 'web.hook'

receivers:
- name: 'web.hook'
  webhook_configs:
  - url: 'http://127.0.0.1:5001/'

inhibit_rules:
  - source_match:
      severity: 'critical'
    target_match:
      severity: 'warning'
    equal: ['alertname', 'dev', 'instance']
EOF

#   
cat > alert_rules.yml << 'EOF'
groups:
- name: sample-app
  rules:
  - alert: HighCPUUsage
    expr: 100 - (avg by (instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 80
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "High CPU usage detected"
      description: "CPU usage is above 80% for more than 5 minutes"

  - alert: HighMemoryUsage
    expr: 100 - ((node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) * 100) > 90
    for: 5m
    labels:
      severity: critical
    annotations:
      summary: "High memory usage detected"
      description: "Memory usage is above 90% for more than 5 minutes"

  - alert: ServiceDown
    expr: up == 0
    for: 1m
    labels:
      severity: critical
    annotations:
      summary: "Service is down"
      description: "Service has been down for more than 1 minute"
EOF

#    (ELK Stack)
cat > docker-compose.logging.yml << 'EOF'
version: '3.8'
services:
  elasticsearch:
    image: docker.elastic.co/elasticsearch/elasticsearch:8.8.0
    environment:
      - discovery.type=single-node
      - xpack.security.enabled=false
    ports:
      - "9200:9200"
    volumes:
      - elasticsearch_data:/usr/share/elasticsearch/data

  logstash:
    image: docker.elastic.co/logstash/logstash:8.8.0
    ports:
      - "5044:5044"
    volumes:
      - ./logstash.conf:/usr/share/logstash/pipeline/logstash.conf
    depends_on:
      - elasticsearch

  kibana:
    image: docker.elastic.co/kibana/kibana:8.8.0
    ports:
      - "5601:5601"
    environment:
      - ELASTICSEARCH_HOSTS=http://elasticsearch:9200
    depends_on:
      - elasticsearch

volumes:
  elasticsearch_data:
EOF

# Logstash 
cat > logstash.conf << 'EOF'
input {
  beats {
    port => 5044
  }
}

filter {
  if [fields][service] == "sample-app" {
    grok {
      match => { "message" => "%{COMBINEDAPACHELOG}" }
    }
    date {
      match => [ "timestamp", "dd/MMM/yyyy:HH:mm:ss Z" ]
    }
  }
}

output {
  elasticsearch {
    hosts => ["elasticsearch:9200"]
    index => "sample-app-%{+YYYY.MM.dd}"
  }
}
EOF

#   
cat > start-monitoring.sh << 'EOF'
#!/bin/bash
#   

set -e

echo "   ..."

# Prometheus + Grafana  
docker-compose -f docker-compose.monitoring.yml up -d

#   
docker-compose -f docker-compose.logging.yml up -d

echo "⏳    ..."
sleep 30

echo "  :"
echo "- Prometheus: http://localhost:9090"
echo "- Grafana: http://localhost:3001 (admin/admin)"
echo "- Kibana: http://localhost:5601"

echo "    !"
EOF

chmod +x start-monitoring.sh

echo "       !"
'''

    script_path = course_dir / "automation" / "day3" / "monitoring.sh"
    script_path.write_text(script_content, encoding='utf-8')
    script_path.chmod(0o755)

def create_cost_optimization_script(course_dir: Path):
    """      """
    script_content = '''#!/bin/bash
#       

set -e

echo "       ..."

# AWS   
cat > aws-cost-analysis.sh << 'EOF'
#!/bin/bash
# AWS    

set -e

echo " AWS   ..."

# Cost Explorer API   
aws ce get-cost-and-usage \
    --time-period Start=2024-01-01,End=2024-12-31 \
    --granularity MONTHLY \
    --metrics BlendedCost \
    --group-by Type=DIMENSION,Key=SERVICE

# EC2   
echo " EC2   :"
aws ec2 describe-instances \
    --query 'Reservations[*].Instances[*].[InstanceId,InstanceType,State.Name,LaunchTime]' \
    --output table

# RDS   
echo " RDS   :"
aws rds describe-db-instances \
    --query 'DBInstances[*].[DBInstanceIdentifier,DBInstanceClass,Engine,AllocatedStorage]' \
    --output table

# S3   
echo " S3   :"
aws s3api list-buckets \
    --query 'Buckets[*].[Name,CreationDate]' \
    --output table

#   
echo "   :"
echo "1.   EC2  "
echo "2.    (S3 Intelligent-Tiering)"
echo "3. Reserved Instances  "
echo "4. Spot Instances "
echo "5. CloudWatch   "

#   
aws budgets create-budget \
    --account-id $(aws sts get-caller-identity --query Account --output text) \
    --budget '{
        "BudgetName": "Monthly Budget",
        "BudgetLimit": {
            "Amount": "100",
            "Unit": "USD"
        },
        "TimeUnit": "MONTHLY",
        "BudgetType": "COST"
    }'

echo " AWS   !"
EOF

# GCP   
cat > gcp-cost-analysis.sh << 'EOF'
#!/bin/bash
# GCP    

set -e

echo " GCP   ..."

#  
if [ -z "$PROJECT_ID" ]; then
    echo " PROJECT_ID   ."
    exit 1
fi

gcloud config set project $PROJECT_ID

# Compute Engine  
echo " Compute Engine  :"
gcloud compute instances list \
    --format="table(name,zone,machineType,status,creationTimestamp)"

# Cloud Storage  
echo " Cloud Storage  :"
gsutil ls -L -b gs://*

# BigQuery  
echo " BigQuery  :"
bq ls --format=table

#   
echo "   :"
echo "1. Preemptible  "
echo "2. Committed Use Discounts "
echo "3.   "
echo "4.   "
echo "5. BigQuery  "

#   
gcloud alpha billing budgets create \
    --billing-account=$(gcloud alpha billing accounts list --format="value(name)" | head -1) \
    --display-name="Monthly Budget" \
    --budget-amount=100USD \
    --threshold-rule=percent=50 \
    --threshold-rule=percent=90

echo " GCP   !"
EOF

#    
cat > cost-optimization-automation.sh << 'EOF'
#!/bin/bash
#    

set -e

echo "[AUTO]    ..."

#    
cleanup_unused_resources() {
    echo "[CLEANUP]    ..."
    
    # AWS 
    if command -v aws &> /dev/null; then
        echo "AWS   ..."
        
        #  EC2  
        aws ec2 describe-instances \
            --filters "Name=instance-state-name,Values=stopped" \
            --query 'Reservations[*].Instances[*].InstanceId' \
            --output text | xargs -r aws ec2 terminate-instances --instance-ids
        
        #   EBS  
        aws ec2 describe-volumes \
            --filters "Name=status,Values=available" \
            --query 'Volumes[*].VolumeId' \
            --output text | xargs -r aws ec2 delete-volume --volume-ids
        
        #     (30 )
        aws ec2 describe-snapshots \
            --owner-ids self \
            --query 'Snapshots[?StartTime<`'$(date -d '30 days ago' --iso-8601)'`].SnapshotId' \
            --output text | xargs -r aws ec2 delete-snapshot --snapshot-ids
    fi
    
    # GCP 
    if command -v gcloud &> /dev/null; then
        echo "GCP   ..."
        
        #   
        gcloud compute instances list \
            --filter="status=TERMINATED" \
            --format="value(name)" | xargs -r gcloud compute instances delete --quiet
        
        #    
        gcloud compute disks list \
            --filter="status=UNATTACHED" \
            --format="value(name)" | xargs -r gcloud compute disks delete --quiet
    fi
}

#  
optimize_storage() {
    echo "  ..."
    
    # AWS S3   
    if command -v aws &> /dev/null; then
        aws s3api put-bucket-intelligent-tiering-configuration \
            --bucket your-bucket-name \
            --id EntireBucket \
            --intelligent-tiering-configuration '{
                "Id": "EntireBucket",
                "Status": "Enabled",
                "Tierings": [
                    {
                        "Days": 30,
                        "AccessTier": "ARCHIVE_ACCESS"
                    },
                    {
                        "Days": 90,
                        "AccessTier": "DEEP_ARCHIVE_ACCESS"
                    }
                ]
            }'
    fi
    
    # GCP Cloud Storage  
    if command -v gsutil &> /dev/null; then
        gsutil lifecycle set lifecycle.json gs://your-bucket-name
    fi
}

#   
optimize_instance_sizes() {
    echo "   ..."
    
    # CPU    
    if command -v aws &> /dev/null; then
        aws cloudwatch get-metric-statistics \
            --namespace AWS/EC2 \
            --metric-name CPUUtilization \
            --dimensions Name=InstanceId,Value=i-1234567890abcdef0 \
            --start-time $(date -d '7 days ago' --iso-8601) \
            --end-time $(date --iso-8601) \
            --period 3600 \
            --statistics Average \
            --query 'Datapoints[?Average<`20`]'
    fi
}

# 
cleanup_unused_resources
optimize_storage
optimize_instance_sizes

echo "    !"
EOF

#   
cat > cost-monitoring-dashboard.py << 'EOF'
#!/usr/bin/env python3
"""
  
"""

import json
import requests
from datetime import datetime, timedelta
import boto3
from google.cloud import billing

class CostMonitoringDashboard:
    def __init__(self):
        self.aws_client = boto3.client('ce')
        self.gcp_client = billing.CloudBillingClient()
    
    def get_aws_costs(self, days=30):
        """AWS  """
        end_date = datetime.now().date()
        start_date = end_date - timedelta(days=days)
        
        response = self.aws_client.get_cost_and_usage(
            TimePeriod={
                'Start': start_date.strftime('%Y-%m-%d'),
                'End': end_date.strftime('%Y-%m-%d')
            },
            Granularity='DAILY',
            Metrics=['BlendedCost'],
            GroupBy=[
                {'Type': 'DIMENSION', 'Key': 'SERVICE'}
            ]
        )
        
        return response
    
    def get_gcp_costs(self, project_id, days=30):
        """GCP  """
        end_date = datetime.now().date()
        start_date = end_date - timedelta(days=days)
        
        # GCP   
        #   Cloud Billing API 
        pass
    
    def generate_cost_report(self):
        """  """
        report = {
            'timestamp': datetime.now().isoformat(),
            'aws_costs': self.get_aws_costs(),
            'gcp_costs': self.get_gcp_costs('your-project-id'),
            'recommendations': [
                '   ',
                '  ',
                'Reserved Instances  ',
                'Spot Instances '
            ]
        }
        
        with open('cost_report.json', 'w') as f:
            json.dump(report, f, indent=2, default=str)
        
        return report

if __name__ == "__main__":
    dashboard = CostMonitoringDashboard()
    report = dashboard.generate_cost_report()
    print("  : cost_report.json")
EOF

#   
chmod +x aws-cost-analysis.sh gcp-cost-analysis.sh cost-optimization-automation.sh
chmod +x cost-monitoring-dashboard.py

echo "        !"
'''

    script_path = course_dir / "automation" / "day3" / "cost_optimization.sh"
    script_path.write_text(script_content, encoding='utf-8')
    script_path.chmod(0o755)
