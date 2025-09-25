#!/bin/bash
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
aws ce get-cost-and-usage     --time-period Start=2024-01-01,End=2024-12-31     --granularity MONTHLY     --metrics BlendedCost     --group-by Type=DIMENSION,Key=SERVICE

# EC2   
echo " EC2   :"
aws ec2 describe-instances     --query 'Reservations[*].Instances[*].[InstanceId,InstanceType,State.Name,LaunchTime]'     --output table

# RDS   
echo " RDS   :"
aws rds describe-db-instances     --query 'DBInstances[*].[DBInstanceIdentifier,DBInstanceClass,Engine,AllocatedStorage]'     --output table

# S3   
echo " S3   :"
aws s3api list-buckets     --query 'Buckets[*].[Name,CreationDate]'     --output table

#   
echo "   :"
echo "1.   EC2  "
echo "2.    (S3 Intelligent-Tiering)"
echo "3. Reserved Instances  "
echo "4. Spot Instances "
echo "5. CloudWatch   "

#   
aws budgets create-budget     --account-id $(aws sts get-caller-identity --query Account --output text)     --budget '{
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
gcloud compute instances list     --format="table(name,zone,machineType,status,creationTimestamp)"

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
gcloud alpha billing budgets create     --billing-account=$(gcloud alpha billing accounts list --format="value(name)" | head -1)     --display-name="Monthly Budget"     --budget-amount=100USD     --threshold-rule=percent=50     --threshold-rule=percent=90

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
        aws ec2 describe-instances             --filters "Name=instance-state-name,Values=stopped"             --query 'Reservations[*].Instances[*].InstanceId'             --output text | xargs -r aws ec2 terminate-instances --instance-ids
        
        #   EBS  
        aws ec2 describe-volumes             --filters "Name=status,Values=available"             --query 'Volumes[*].VolumeId'             --output text | xargs -r aws ec2 delete-volume --volume-ids
        
        #     (30 )
        aws ec2 describe-snapshots             --owner-ids self             --query 'Snapshots[?StartTime<`'$(date -d '30 days ago' --iso-8601)'`].SnapshotId'             --output text | xargs -r aws ec2 delete-snapshot --snapshot-ids
    fi
    
    # GCP 
    if command -v gcloud &> /dev/null; then
        echo "GCP   ..."
        
        #   
        gcloud compute instances list             --filter="status=TERMINATED"             --format="value(name)" | xargs -r gcloud compute instances delete --quiet
        
        #    
        gcloud compute disks list             --filter="status=UNATTACHED"             --format="value(name)" | xargs -r gcloud compute disks delete --quiet
    fi
}

#  
optimize_storage() {
    echo "  ..."
    
    # AWS S3   
    if command -v aws &> /dev/null; then
        aws s3api put-bucket-intelligent-tiering-configuration             --bucket your-bucket-name             --id EntireBucket             --intelligent-tiering-configuration '{
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
        aws cloudwatch get-metric-statistics             --namespace AWS/EC2             --metric-name CPUUtilization             --dimensions Name=InstanceId,Value=i-1234567890abcdef0             --start-time $(date -d '7 days ago' --iso-8601)             --end-time $(date --iso-8601)             --period 3600             --statistics Average             --query 'Datapoints[?Average<`20`]'
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
