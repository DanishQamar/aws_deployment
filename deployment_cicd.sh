#!/bin/bash
set -e

# This is the V3.5 Deployment Script (ImageDetail Cleanup).
# 1. Provisions Infrastructure
# 2. Checks for buildspecs
# 3. Strict cleanup of local artifacts
# 4. Zips & Uploads

# --- Variables ---
TF_VARS_FILE="terraform.tfvars"
ZIP_FILE="source_code.zip"

# --- Functions ---

create_tfvars() {
    if [ ! -f "$TF_VARS_FILE" ]; then
        echo "Creating ${TF_VARS_FILE}..."
        echo "aws_region     = \"ap-south-1\"" > ${TF_VARS_FILE}
        echo "project_name = \"my-ecs-project\"" >> ${TF_VARS_FILE}
        echo "environment  = \"dev\"" >> ${TF_VARS_FILE}
        echo "db_username  = \"dbadmin\"" >> ${TF_VARS_FILE}
        echo "db_password  = \"MySecurePassword123\"" >> ${TF_VARS_FILE}
    fi
}

deploy() {
    echo "--- Provisioning Infrastructure ---"
    create_tfvars
    
    terraform init
    terraform apply -auto-approve -var-file=${TF_VARS_FILE}

    # Get Outputs
    SOURCE_BUCKET=$(terraform output -raw source_bucket_name 2>/dev/null)
    UI_BUCKET_NAME=$(terraform output -raw ui_bucket_name 2>/dev/null)
    CLOUDFRONT_DOMAIN=$(terraform output -raw cloudfront_domain_name 2>/dev/null)

    if [ -z "$SOURCE_BUCKET" ]; then
        echo "Error: Could not find Source Bucket. Terraform might have failed."
        exit 1
    fi

    # --- SAFETY CHECK ---
    if [ ! -f "service1/buildspec.yml" ]; then
        echo "❌ Error: service1/buildspec.yml not found!"
        exit 1
    fi
    if [ ! -f "service2/buildspec.yml" ]; then
        echo "❌ Error: service2/buildspec.yml not found!"
        exit 1
    fi

    echo ""
    echo "--- Triggering Pipeline (Upload to S3) ---"
    
    # 1. Strict Cleanup
    # Remove zip, json files, and artifact directories
    rm -f $ZIP_FILE
    rm -rf imagedefinitions.json
    rm -rf artifacts 
    rm -rf imageDetail

    # 2. Zip the project
    echo "Zipping source code..."
    # Explicitly exclude potential trouble paths
    zip -r -q $ZIP_FILE . -x "*.git*" "*.terraform*" "*target*" "*node_modules*" "*.DS_Store" "terraform.tfstate*" "imagedefinitions.json" "artifacts/*" "imageDetail/*"

    # 3. Upload to S3
    echo "Uploading to s3://${SOURCE_BUCKET}/source_code.zip ..."
    aws s3 cp $ZIP_FILE s3://${SOURCE_BUCKET}/source_code.zip

    echo ""
    echo "✅ Upload Complete. Pipeline Triggered!"
    echo "   Go to AWS Console -> CodePipeline to watch the build."
    echo "---------------------------------------------------"
    
    if [ ! -z "$UI_BUCKET_NAME" ]; then
        echo "Uploading index.html to S3..."
        aws s3 cp ./index.html s3://${UI_BUCKET_NAME}/index.html
        echo "UI available at: https://${CLOUDFRONT_DOMAIN}/"
    fi
}

destroy() {
    echo "--- Destroying Infrastructure ---"
    create_tfvars
    terraform init
    terraform destroy -auto-approve -var-file=${TF_VARS_FILE}
    echo "---------------------------------"
}

# --- Main Logic ---
ACTION=$1

case "$ACTION" in
    deploy)
        deploy
        ;;
    destroy)
        destroy
        ;;
    *)
        echo "Usage: $0 {deploy|destroy}"
        exit 1
        ;;
esac