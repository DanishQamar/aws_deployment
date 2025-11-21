# --- Artifacts & Source Bucket ---
resource "aws_s3_bucket" "pipeline_artifacts" {
  bucket        = "${var.project_name}-${var.environment}-pipeline-artifacts"
  force_destroy = true
  tags          = var.tags
}

# Separate bucket for source code uploads (to trigger pipeline)
resource "aws_s3_bucket" "source_code_bucket" {
  bucket        = "${var.project_name}-${var.environment}-source-code"
  force_destroy = true
  tags          = var.tags
}

# Enable versioning so Pipeline can see new uploads
resource "aws_s3_bucket_versioning" "source_versioning" {
  bucket = aws_s3_bucket.source_code_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

# --- IAM Roles ---
# 1. CodeBuild Role
resource "aws_iam_role" "codebuild_role" {
  name = "${var.project_name}-codebuild-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = { Service = "codebuild.amazonaws.com" }
    }]
  })
  tags = var.tags
}

resource "aws_iam_role_policy" "codebuild_policy" {
  role = aws_iam_role.codebuild_role.name
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents",
          "ecr:GetAuthorizationToken", "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer", "ecr:BatchGetImage",
          "ecr:PutImage", "ecr:InitiateLayerUpload", "ecr:UploadLayerPart", "ecr:CompleteLayerUpload",
          "s3:GetObject", "s3:GetObjectVersion", "s3:PutObject", "s3:ListBucket"
        ],
        Resource = "*"
      }
    ]
  })
}

# 2. CodePipeline Role
resource "aws_iam_role" "pipeline_role" {
  name = "${var.project_name}-pipeline-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = { Service = "codepipeline.amazonaws.com" }
    }]
  })
  tags = var.tags
}

resource "aws_iam_role_policy" "pipeline_policy" {
  role = aws_iam_role.pipeline_role.name
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          # FIXED: Added s3:ListBucket which is required for "PollForSourceChanges"
          "s3:GetObject", "s3:GetObjectVersion", "s3:GetBucketVersioning", 
          "s3:PutObjectAcl", "s3:PutObject", "s3:ListBucket",
          "codebuild:BatchGetBuilds", "codebuild:StartBuild",
          "ecs:RegisterTaskDefinition", "ecs:UpdateService", "ecs:DescribeServices", "ecs:DescribeTaskDefinition", "ecs:ListTasks", "ecs:DescribeTasks",
          "iam:PassRole"
        ],
        Resource = "*"
      }
    ]
  })
}

# --- CodeBuild Projects ---

# Build Project for Service 1
resource "aws_codebuild_project" "service1_build" {
  name          = "${var.project_name}-service1-build"
  service_role  = aws_iam_role.codebuild_role.arn
  build_timeout = "10"

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type    = "BUILD_GENERAL1_SMALL"
    image           = "aws/codebuild/standard:7.0" # Supports Java 17
    type            = "LINUX_CONTAINER"
    privileged_mode = true # Required for Docker

    environment_variable {
      name  = "AWS_REGION"
      value = var.aws_region
    }
    environment_variable {
      name  = "ECR_REPOSITORY_URL"
      value = var.service1_ecr_url
    }
    environment_variable {
      name  = "CONTAINER_NAME"
      value = var.service1_name
    }
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = "service1/buildspec.yml"
  }
  tags = var.tags
}

# Build Project for Service 2
resource "aws_codebuild_project" "service2_build" {
  name          = "${var.project_name}-service2-build"
  service_role  = aws_iam_role.codebuild_role.arn
  build_timeout = "10"

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type    = "BUILD_GENERAL1_SMALL"
    image           = "aws/codebuild/standard:7.0"
    type            = "LINUX_CONTAINER"
    privileged_mode = true

    environment_variable {
      name  = "AWS_REGION"
      value = var.aws_region
    }
    environment_variable {
      name  = "ECR_REPOSITORY_URL"
      value = var.service2_ecr_url
    }
    environment_variable {
      name  = "CONTAINER_NAME"
      value = var.service2_name
    }
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = "service2/buildspec.yml"
  }
  tags = var.tags
}

# --- CodePipeline ---
resource "aws_codepipeline" "main" {
  name     = "${var.project_name}-pipeline"
  role_arn = aws_iam_role.pipeline_role.arn

  artifact_store {
    location = aws_s3_bucket.pipeline_artifacts.bucket
    type     = "S3"
  }

  # 1. Source Stage (Updated to S3)
  stage {
    name = "Source"
    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "S3"
      version          = "1"
      output_artifacts = ["source_output"]
      configuration = {
        S3Bucket             = aws_s3_bucket.source_code_bucket.bucket
        S3ObjectKey          = "source_code.zip"
        PollForSourceChanges = "true"
      }
    }
  }

  # 2. Build Stage (Parallel Builds)
  stage {
    name = "Build"
    action {
      name             = "Build-Service1"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["source_output"]
      output_artifacts = ["build_output_service1"]
      version          = "1"
      configuration = {
        ProjectName = aws_codebuild_project.service1_build.name
      }
    }
    action {
      name             = "Build-Service2"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["source_output"]
      output_artifacts = ["build_output_service2"]
      version          = "1"
      configuration = {
        ProjectName = aws_codebuild_project.service2_build.name
      }
    }
  }

  # 3. Deploy Stage (Deploy to ECS)
  stage {
    name = "Deploy"
    action {
      name            = "Deploy-Service1"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "ECS"
      input_artifacts = ["build_output_service1"]
      version         = "1"
      configuration = {
        ClusterName = var.ecs_cluster_name
        ServiceName = var.service1_name
        FileName    = "imagedefinitions.json"
      }
    }
    action {
      name            = "Deploy-Service2"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "ECS"
      input_artifacts = ["build_output_service2"]
      version         = "1"
      configuration = {
        ClusterName = var.ecs_cluster_name
        ServiceName = var.service2_name
        FileName    = "imagedefinitions.json"
      }
    }
  }
  tags = var.tags
}