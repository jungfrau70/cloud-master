#!/bin/bash
#    Auto Scaling  

set -e

echo "    Auto Scaling  ..."

# AWS Application Load Balancer 
cat > aws-alb-setup.sh << 'EOF'
#!/bin/bash
# AWS Application Load Balancer 

set -e

# VPC 
VPC_ID=$(aws ec2 create-vpc     --cidr-block 10.0.0.0/16     --query 'Vpc.VpcId'     --output text)

echo " VPC : $VPC_ID"

#     
IGW_ID=$(aws ec2 create-internet-gateway     --query 'InternetGateway.InternetGatewayId'     --output text)

aws ec2 attach-internet-gateway     --vpc-id $VPC_ID     --internet-gateway-id $IGW_ID

#   
SUBNET_1=$(aws ec2 create-subnet     --vpc-id $VPC_ID     --cidr-block 10.0.1.0/24     --availability-zone us-west-2a     --query 'Subnet.SubnetId'     --output text)

SUBNET_2=$(aws ec2 create-subnet     --vpc-id $VPC_ID     --cidr-block 10.0.2.0/24     --availability-zone us-west-2b     --query 'Subnet.SubnetId'     --output text)

#   
ROUTE_TABLE_ID=$(aws ec2 create-route-table     --vpc-id $VPC_ID     --query 'RouteTable.RouteTableId'     --output text)

aws ec2 create-route     --route-table-id $ROUTE_TABLE_ID     --destination-cidr-block 0.0.0.0/0     --gateway-id $IGW_ID

aws ec2 associate-route-table     --subnet-id $SUBNET_1     --route-table-id $ROUTE_TABLE_ID

aws ec2 associate-route-table     --subnet-id $SUBNET_2     --route-table-id $ROUTE_TABLE_ID

#   
SECURITY_GROUP_ID=$(aws ec2 create-security-group     --group-name alb-sg     --description "Security group for ALB"     --vpc-id $VPC_ID     --query 'GroupId'     --output text)

#    
aws ec2 authorize-security-group-ingress     --group-id $SECURITY_GROUP_ID     --protocol tcp     --port 80     --cidr 0.0.0.0/0

aws ec2 authorize-security-group-ingress     --group-id $SECURITY_GROUP_ID     --protocol tcp     --port 443     --cidr 0.0.0.0/0

# Application Load Balancer 
ALB_ARN=$(aws elbv2 create-load-balancer     --name sample-alb     --subnets $SUBNET_1 $SUBNET_2     --security-groups $SECURITY_GROUP_ID     --query 'LoadBalancers[0].LoadBalancerArn'     --output text)

echo " ALB : $ALB_ARN"

#   
TARGET_GROUP_ARN=$(aws elbv2 create-target-group     --name sample-targets     --protocol HTTP     --port 80     --vpc-id $VPC_ID     --health-check-path /health     --query 'TargetGroups[0].TargetGroupArn'     --output text)

echo "   : $TARGET_GROUP_ARN"

#  
aws elbv2 create-listener     --load-balancer-arn $ALB_ARN     --protocol HTTP     --port 80     --default-actions Type=forward,TargetGroupArn=$TARGET_GROUP_ARN

echo " AWS ALB  !"
EOF

# GCP Cloud Load Balancing 
cat > gcp-lb-setup.sh << 'EOF'
#!/bin/bash
# GCP Cloud Load Balancing 

set -e

#   
gcloud compute instance-templates create sample-template     --image-family=ubuntu-2004-lts     --image-project=ubuntu-os-cloud     --machine-type=e2-micro     --boot-disk-size=10GB     --tags=http-server     --metadata-from-file startup-script=startup-script.sh

#    
gcloud compute instance-groups managed create sample-group     --template=sample-template     --size=3     --zone=us-west1-a

# Health Check 
gcloud compute health-checks create http sample-health-check     --port=80     --request-path=/health

#   
gcloud compute backend-services create sample-backend     --protocol=HTTP     --health-checks=sample-health-check     --global

#    
gcloud compute backend-services add-backend sample-backend     --instance-group=sample-group     --instance-group-zone=us-west1-a     --global

# URL  
gcloud compute url-maps create sample-url-map     --default-service=sample-backend

# HTTP  
gcloud compute target-http-proxies create sample-proxy     --url-map=sample-url-map

#  IP  
gcloud compute addresses create sample-ip     --global

#   
gcloud compute forwarding-rules create sample-rule     --global     --target-http-proxy=sample-proxy     --address=sample-ip     --ports=80

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
aws autoscaling create-auto-scaling-group     --auto-scaling-group-name sample-asg     --launch-template LaunchTemplateName=sample-template,Version=1     --min-size 1     --max-size 10     --desired-capacity 3     --target-group-arns $TARGET_GROUP_ARN     --health-check-type ELB     --health-check-grace-period 300

#   
aws autoscaling put-scaling-policy     --auto-scaling-group-name sample-asg     --policy-name scale-up-policy     --policy-type TargetTrackingScaling     --target-tracking-configuration '{
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
