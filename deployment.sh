#!/bin/bash
set -e

# This script manages the deployment of the AWS infrastructure and services.
#
# USAGE:
#   ./deployment.sh [action]
#
# ACTIONS:
#   plan      - Generates a Terraform execution plan.
#   deploy    - Creates or updates the infrastructure, builds and pushes Docker images, and deploys the services.
#   destroy   - Destroys all managed infrastructure.
#
# Before running, ensure your AWS credentials (AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY) are set in your environment.

# --- Variables ---
AWS_REGION="ap-south-1"
TF_VARS_FILE="terraform.tfvars"

# --- Functions ---

# Creates the terraform.tfvars file. This function is called by all actions.
create_tfvars() {
    echo "Creating ${TF_VARS_FILE}..."
    # You can customize these values
    echo "aws_region     = \"${AWS_REGION}\"" > ${TF_VARS_FILE}
    echo "project_name = \"my-ecs-project\"" >> ${TF_VARS_FILE}
    echo "environment  = \"dev\"" >> ${TF_VARS_FILE}
    echo "db_username  = \"dbadmin\"" >> ${TF_VARS_FILE}
    echo "db_password  = \"MySecurePassword123\"" >> ${TF_VARS_FILE}
}

# Generates a Terraform execution plan.
plan() {
    echo "--- Running Terraform Plan ---"
    create_tfvars
    echo "Initializing Terraform..."
    terraform init
    echo "Generating Terraform plan..."
    terraform plan -var-file=${TF_VARS_FILE}
    echo "------------------------------"
}

# Deploys the infrastructure and application.
deploy() {
    echo "--- Deploying Infrastructure and Application ---"
    create_tfvars
    
    # 1. Initialize and Apply Terraform
    echo "Initializing Terraform..."
    terraform init

    echo "Applying Terraform to create infrastructure..."
    terraform apply -auto-approve -var-file=${TF_VARS_FILE}

    # 2. Get ECR URLs from Terraform Output
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

    # 3. Build and Push Docker Images
    echo "Logging in to AWS ECR..."
    aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${SERVICE1_REPO_URL}

    echo "Building and pushing Service 1..."
    docker build -t ${SERVICE1_REPO_URL}:latest ./service1
    docker push ${SERVICE1_REPO_URL}:latest

    echo "Building and pushing Service 2..."
    docker build -t ${SERVICE2_REPO_URL}:latest ./service2
    docker push ${SERVICE2_REPO_URL}:latest

    # 4. Force New ECS Deployment
    echo "Forcing new deployment for ECS services to pick up images..."
    aws ecs update-service --region ${AWS_REGION} --cluster ${CLUSTER_NAME} --service "service1" --force-new-deployment
    aws ecs update-service --region ${AWS_REGION} --cluster ${CLUSTER_NAME} --service "service2" --force-new-deployment

    # 5. Output ALB DNS Name
    CLOUDFRONT_DOMAIN=$(terraform output -raw cloudfront_domain_name)
    echo "----------------------------------------"
    echo "Deployment Complete!"
    echo "UI is available at: https://${CLOUDFRONT_DOMAIN}/"
    echo "----------------------------------------"
}

# Destroys the infrastructure.
destroy() {
    echo "--- Destroying Infrastructure ---"
    create_tfvars
    echo "Initializing Terraform..."
    terraform init
    echo "Destroying all resources..."
    terraform destroy -auto-approve -var-file=${TF_VARS_FILE}
    echo "---------------------------------"
}

# --- Main Logic ---
ACTION=$1

case "$ACTION" in
    plan)
        plan
        ;;
    deploy)
        deploy
        ;;
    destroy)
        destroy
        ;;
    *)
        echo "Usage: $0 {plan|deploy|destroy}"
        exit 1
        ;;
esac