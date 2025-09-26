#!/bin/bash
# VM     

set -e

echo " VM      ..."

# AWS EC2  
cat > deploy_aws.sh << 'EOF'
#!/bin/bash
# AWS EC2  

set -e

#   
if [ -z "$AWS_REGION" ]; then
    export AWS_REGION="us-west-2"
fi

if [ -z "$INSTANCE_TYPE" ]; then
    export INSTANCE_TYPE="t3.micro"
fi

echo " AWS EC2   ..."

#   
SECURITY_GROUP_ID=$(aws ec2 create-security-group     --group-name "sample-app-sg"     --description "Security group for sample app"     --query 'GroupId'     --output text)

echo "   : $SECURITY_GROUP_ID"

#    
aws ec2 authorize-security-group-ingress     --group-id $SECURITY_GROUP_ID     --protocol tcp     --port 22     --cidr 0.0.0.0/0

aws ec2 authorize-security-group-ingress     --group-id $SECURITY_GROUP_ID     --protocol tcp     --port 3000     --cidr 0.0.0.0/0

#   
aws ec2 create-key-pair     --key-name sample-app-key     --query 'KeyMaterial'     --output text > sample-app-key.pem

chmod 400 sample-app-key.pem

#  
INSTANCE_ID=$(aws ec2 run-instances     --image-id ami-0c02fb55956c7d316     --count 1     --instance-type $INSTANCE_TYPE     --key-name sample-app-key     --security-group-ids $SECURITY_GROUP_ID     --user-data file://user-data.sh     --query 'Instances[0].InstanceId'     --output text)

echo "  : $INSTANCE_ID"

#   
aws ec2 wait instance-running --instance-ids $INSTANCE_ID

#  IP 
PUBLIC_IP=$(aws ec2 describe-instances     --instance-ids $INSTANCE_ID     --query 'Reservations[0].Instances[0].PublicIpAddress'     --output text)

echo "  IP: $PUBLIC_IP"
echo "  URL: http://$PUBLIC_IP:3000"
EOF

# GCP Compute Engine  
cat > deploy_gcp.sh << 'EOF'
#!/bin/bash
# GCP Compute Engine  

set -e

#   
if [ -z "$PROJECT_ID" ]; then
    echo " PROJECT_ID   ."
    exit 1
fi

if [ -z "$ZONE" ]; then
    export ZONE="us-west1-a"
fi

echo " GCP Compute Engine   ..."

#  
gcloud config set project $PROJECT_ID

#   
gcloud compute firewall-rules create allow-sample-app     --allow tcp:3000     --source-ranges 0.0.0.0/0     --description "Allow sample app traffic"

#  
gcloud compute instances create sample-app-instance     --zone=$ZONE     --machine-type=e2-micro     --image-family=ubuntu-2004-lts     --image-project=ubuntu-os-cloud     --boot-disk-size=10GB     --metadata-from-file startup-script=startup-script.sh

echo "   "

#  IP 
INSTANCE_IP=$(gcloud compute instances describe sample-app-instance     --zone=$ZONE     --format='get(networkInterfaces[0].accessConfigs[0].natIP)')

echo "  IP: $INSTANCE_IP"
echo "  URL: http://$INSTANCE_IP:3000"
EOF

# User Data  (AWS)
cat > user-data.sh << 'EOF'
#!/bin/bash
# AWS EC2 User Data Script

set -e

#  
apt-get update
apt-get upgrade -y

# Docker 
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh
usermod -aG docker ubuntu

# Docker Compose 
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

#   
mkdir -p /opt/sample-app
cd /opt/sample-app

# Docker Compose  
cat > docker-compose.yml << 'DOCKEREOF'
version: '3.8'
services:
  app:
    image: nginx:alpine
    ports:
      - "3000:80"
    volumes:
      - ./index.html:/usr/share/nginx/html/index.html
DOCKEREOF

#  HTML  
cat > index.html << 'HTMLEOF'
<!DOCTYPE html>
<html>
<head>
    <title>Sample App</title>
</head>
<body>
    <h1>Hello from AWS EC2!</h1>
    <p>This is a sample application deployed on AWS EC2.</p>
    <p>Timestamp: <span id="timestamp"></span></p>
    <script>
        document.getElementById('timestamp').textContent = new Date().toISOString();
    </script>
</body>
</html>
HTMLEOF

# Docker Compose 
docker-compose up -d

#   
systemctl enable docker
EOF

# Startup Script (GCP)
cat > startup-script.sh << 'EOF'
#!/bin/bash
# GCP Compute Engine Startup Script

set -e

#  
apt-get update
apt-get upgrade -y

# Docker 
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh

# Docker Compose 
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

#   
mkdir -p /opt/sample-app
cd /opt/sample-app

# Docker Compose  
cat > docker-compose.yml << 'DOCKEREOF'
version: '3.8'
services:
  app:
    image: nginx:alpine
    ports:
      - "3000:80"
    volumes:
      - ./index.html:/usr/share/nginx/html/index.html
DOCKEREOF

#  HTML  
cat > index.html << 'HTMLEOF'
<!DOCTYPE html>
<html>
<head>
    <title>Sample App</title>
</head>
<body>
    <h1>Hello from GCP Compute Engine!</h1>
    <p>This is a sample application deployed on GCP Compute Engine.</p>
    <p>Timestamp: <span id="timestamp"></span></p>
    <script>
        document.getElementById('timestamp').textContent = new Date().toISOString();
    </script>
</body>
</html>
HTMLEOF

# Docker Compose 
docker-compose up -d
EOF

#   
chmod +x deploy_aws.sh deploy_gcp.sh

echo " VM    !"
echo " :"
echo "  AWS: ./deploy_aws.sh"
echo "  GCP: PROJECT_ID=your-project-id ./deploy_gcp.sh"

echo " VM      !"
