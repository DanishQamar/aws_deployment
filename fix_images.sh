#!/bin/bash
    set -e

    echo "--- Fixing 503 Error: Building and Pushing Images ---"

    # 1. Get the ECR Repository URLs from Terraform
    echo "Fetching ECR URLs from Terraform..."
    SERVICE1_REPO=$(terraform output -raw service1_ecr_repository_url)
    SERVICE2_REPO=$(terraform output -raw service2_ecr_repository_url)
    REGION=$(terraform output -raw aws_region 2>/dev/null || echo "ap-south-1") # Default to ap-south-1 if var not found

    if [ -z "$SERVICE1_REPO" ]; then
      echo "Error: Could not find Service 1 ECR URL. Did you run 'terraform apply'?"
      exit 1
    fi

    echo "Service 1 Repo: $SERVICE1_REPO"
    echo "Service 2 Repo: $SERVICE2_REPO"

    # 2. Login to AWS ECR
    echo "Logging in to ECR..."
    aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $SERVICE1_REPO

    # 3. Build and Push Service 1 (The one causing the 503)
    echo "Building Service 1..."
    docker build -t $SERVICE1_REPO:latest ./service1
    echo "Pushing Service 1..."
    docker push $SERVICE1_REPO:latest

    # 4. Build and Push Service 2 (Good practice to keep them in sync)
    echo "Building Service 2..."
    docker build -t $SERVICE2_REPO:latest ./service2
    echo "Pushing Service 2..."
    docker push $SERVICE2_REPO:latest

    # 5. Force ECS to restart the tasks immediately
    echo "Forcing ECS to pull the new image..."
    CLUSTER_NAME=$(terraform output -raw ecs_cluster_name)
    aws ecs update-service --cluster $CLUSTER_NAME --service service1 --force-new-deployment --region $REGION
    aws ecs update-service --cluster $CLUSTER_NAME --service service2 --force-new-deployment --region $REGION

    echo "---------------------------------------------------"
    echo "✅ Images pushed and deployment triggered."
    echo "   Please wait 2-3 minutes for the 503 error to resolve."
    echo "---------------------------------------------------"