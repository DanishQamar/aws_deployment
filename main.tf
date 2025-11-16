terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Standard tags to apply to all resources
locals {
  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}

# 
module "vpc" {
  source       = "./modules/vpc"
  project_name = var.project_name
  environment  = var.environment
  tags         = local.tags
}

# 
module "security" {
  source          = "./modules/security"
  vpc_id          = module.vpc.vpc_id
  public_subnets  = module.vpc.public_subnets
  private_subnets = module.vpc.private_subnets
  tags            = local.tags
}

# 
module "database" {
  source            = "./modules/database"
  vpc_id            = module.vpc.vpc_id
  db_subnets        = module.vpc.database_subnets
  db_security_group = module.security.db_sg_id
  db_username       = var.db_username
  db_password       = var.db_password
  tags              = local.tags
}

# 
module "messaging" {
  source = "./modules/messaging"
  tags   = local.tags
}

# [cite: 100]
module "iam" {
  source         = "./modules/iam"
  sqs_queue_arn  = module.messaging.sqs_queue_arn
  db_instance_id = module.database.db_instance_id # Simplified access, real-world might use hostname
  tags           = local.tags
}

# 
module "ecs_cluster" {
  source           = "./modules/ecs_cluster"
  ecs_cluster_name = var.ecs_cluster_name
  tags             = local.tags
}

module "service1" {
  source                 = "./modules/ecs_service"
  service_name           = "service1"
  ecs_cluster_id         = module.ecs_cluster.ecs_cluster_id
  log_group_name         = module.ecs_cluster.log_group_name
  ecs_cluster_name       = module.ecs_cluster.ecs_cluster_name
  image_uri              = module.ecs_cluster.service1_ecr_repo_url
  sqs_queue_url          = module.messaging.sqs_queue_url # Pass queue URL to service 1
  task_role_arn          = module.iam.service1_task_role_arn
  execution_role_arn     = module.iam.ecs_task_execution_role_arn
  vpc_id                 = module.vpc.vpc_id
  subnet_ids             = module.vpc.private_subnets
  public_subnet_ids      = module.vpc.public_subnets
  ecs_security_group_ids = [module.security.ecs_sg_id]
  alb_security_group_id  = module.security.alb_sg_id
  tags                   = local.tags

  # Service 1 specifics
  container_port = 8080
  create_alb     = true
}

# [cite: 107, 109]
module "service2" {
  source                 = "./modules/ecs_service"
  service_name           = "service2"
  ecs_cluster_id         = module.ecs_cluster.ecs_cluster_id
  log_group_name         = module.ecs_cluster.log_group_name
  ecs_cluster_name       = module.ecs_cluster.ecs_cluster_name
  image_uri              = module.ecs_cluster.service2_ecr_repo_url
  sqs_queue_url          = module.messaging.sqs_queue_url # Pass queue URL to service 2
  task_role_arn          = module.iam.service2_task_role_arn
  execution_role_arn     = module.iam.ecs_task_execution_role_arn
  vpc_id                 = module.vpc.vpc_id
  subnet_ids             = module.vpc.private_subnets
  ecs_security_group_ids = [module.security.ecs_sg_id]
  tags                   = local.tags

  # Service 2 specifics
  create_alb         = false
  enable_sqs_scaling = true # [cite: 110]
  sqs_queue_arn      = module.messaging.sqs_queue_arn
}
