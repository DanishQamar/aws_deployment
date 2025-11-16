#!/bin/bash
set -e

# --- Variables ---
AWS_REGION="ap-south-1"
TF_VARS_FILE="terraform.tfvars"

# --- 1. Set AWS credentials (if not already set) ---
# Ensure your AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, 
# and AWS_SESSION_TOKEN (if needed) are set in your environment.

# --- 2. Create terraform.tfvars file ---
# You can customize these values
echo "aws_region     = \"${AWS_REGION}\"" > ${TF_VARS_FILE}
echo "project_name = \"my-ecs-project\"" >> ${TF_VARS_FILE}
echo "environment  = \"dev\"" >> ${TF_VARS_FILE}
echo "db_username  = \"dbadmin\"" >> ${TF_VARS_FILE}
echo "db_password  = \"MySecurePassword123\"" >> ${TF_VARS_FILE}

# --- 3. Initialize and Apply Terraform ---
echo "Initializing Terraform..."
terraform init

echo "Applying Terraform to create infrastructure..."
terraform apply -auto-approve -var-file=${TF_VARS_FILE}

# --- 4. Get ECR URLs from Terraform Output ---
echo "Fetching ECR repository URLs..."
SERVICE1_REPO_URL=$(terraform output -raw service1_ecr_repository_url)
SERVICE2_REPO_URL=$(terraform output -raw service2_ecr_repository_url)
CLUSTER_NAME=$(terraform output -raw ecs_cluster_name)

if [ -z "$SERVICE1_REPO_URL" ] || [ -z "$SERVICE2_REPO_URL" ]; then
    echo "Failed to get ECR repository URLs."
    exit 1
fi

echo "Service 1 Repo: $SERVICE1_REPO_URL"
echo "Service 2 Repo: $SERVICE2_REPO_URL"

# --- 5. Build and Push Docker Images ---
echo "Logging in to AWS ECR..."
aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${SERVICE1_REPO_URL}

echo "Building and pushing Service 1..."
docker build -t ${SERVICE1_REPO_URL}:latest ./service1
docker push ${SERVICE1_REPO_URL}:latest

echo "Building and pushing Service 2..."
docker build -t ${SERVICE2_REPO_URL}:latest ./service2
docker push ${SERVICE2_REPO_URL}:latest

# --- 6. Force New ECS Deployment ---
echo "Forcing new deployment for ECS services to pick up images..."

aws ecs update-service --region ${AWS_REGION} \
    --cluster ${CLUSTER_NAME} \
    --service "service1" \
    --force-new-deployment

aws ecs update-service --region ${AWS_REGION} \
    --cluster ${CLUSTER_NAME} \
    --service "service2" \
    --force-new-deployment

# --- 7. Output ALB DNS Name ---
ALB_DNS=$(terraform output -raw alb_dns_name)
echo "----------------------------------------"
echo "Deployment Complete!"
echo "Service 1 is available at: http://${ALB_DNS}/"
echo "(Try http://${ALB_DNS}/submit-job to test SQS)"
echo "----------------------------------------"