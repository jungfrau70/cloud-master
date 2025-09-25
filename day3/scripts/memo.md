
LAUNCH_TEMPLATE_ID=$[aws ec2 create-launch-template \
    --launch-template-name cloud-master-day3-template \
    --launch-template-data '{
        "ImageId": "ami-077ad873396d76f6a",
        "InstanceType": "t2.nano",
        "SecurityGroupIds": ["'$SECURITY_GROUP'"],
        "TagSpecifications": [{
            "ResourceType": "instance",
            "Tags": [{"Key": "Name", "Value": "cloud-master-day3-asg"}]
        }]
    }' \
    --query 'LaunchTemplate.LaunchTemplateId' --output text]

aws autoscaling create-auto-scaling-group \
    --auto-scaling-group-name cloud-master-day3-asg \
    --launch-template LaunchTemplateId=$LAUNCH_TEMPLATE_ID,Version='$Latest' \
    --min-size 1 --max-size 3 --desired-capacity 2 \
    --target-group-arns $TARGET_GROUP_ARN \
    --health-check-type ELB --health-check-grace-period 300 

aws autoscaling create-auto-scaling-group \
    --auto-scaling-group-name cloud-master-day3-asg \
    --launch-template LaunchTemplateId=$LAUNCH_TEMPLATE_ID,Version='$Latest' \
    --min-size 1 --max-size 3 --desired-capacity 2 \
    --target-group-arns $TARGET_GROUP_ARN \
    --health-check-type ELB --health-check-grace-period 300 \
    --availability-zones ap-northeast-2a ap-northeast-2c


echo "--- AWS 비용 분석 ---"
aws ce get-cost-and-usage \
    --time-period Start=2025-09-01,End=2025-09-24 \
    --granularity MONTHLY \
    --metrics BlendedCost \
    --group-by Type=DIMENSION,Key=SERVICE