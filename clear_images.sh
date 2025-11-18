#!/bin/bash
set -e

echo "--- Deleting ALL images from ECR Repositories ---"

# 1. Get Region
REGION=$(terraform output -raw aws_region 2>/dev/null || echo "ap-south-1")
echo "Region: $REGION"

# 2. Define Repositories (Names match those in modules/ecs_cluster/main.tf)
REPOS=("service1" "service2")

for REPO in "${REPOS[@]}"; do
    echo "---------------------------------------------------"
    echo "Processing Repository: $REPO"
    
    # List all image digests
    echo "Fetching image list..."
    IMAGES=$(aws ecr list-images --repository-name $REPO --region $REGION --query 'imageIds[*]' --output json)

    # Check if images exist
    if [ "$IMAGES" == "[]" ] || [ -z "$IMAGES" ]; then
        echo "No images found in $REPO."
    else
        COUNT=$(echo $IMAGES | grep -o "imageDigest" | wc -l)
        echo "Found $COUNT images. Deleting..."
        
        # Batch delete
        aws ecr batch-delete-image \
            --repository-name $REPO \
            --region $REGION \
            --image-ids "$IMAGES" > /dev/null
            
        echo "✅ Successfully deleted all images from $REPO."
    fi
done

echo "---------------------------------------------------"
echo "Cleanup complete."