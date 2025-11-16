provider "aws" {
  region = var.aws_region
}

locals {
  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}

module "vpc" {
  source       = "./modules/vpc"
  project_name = var.project_name
  environment  = var.environment
  tags         = local.tags
}

module "security" {
  source = "./modules/security"
  vpc_id = module.vpc.vpc_id
  # Add these two lines
  public_subnets  = module.vpc.public_subnets
  private_subnets = module.vpc.private_subnets
  tags            = local.tags
}

module "database" {
  source            = "./modules/database"
  vpc_id            = module.vpc.vpc_id
  db_subnets        = module.vpc.database_subnets
  db_security_group = module.security.db_sg_id
  db_username       = var.db_username
  db_password       = var.db_password
  tags              = local.tags
}

module "messaging" {
  source = "./modules/messaging"
  tags   = local.tags
}

module "iam" {
  source                    = "./modules/iam"
  sqs_queue_arn             = module.messaging.sqs_queue_arn
  db_instance_id            = module.database.db_instance_id
  db_credentials_secret_arn = module.database.db_credentials_secret_arn
  tags                      = local.tags
}

module "ecs_cluster" {
  source = "./modules/ecs_cluster"

  ecs_cluster_name = "${var.project_name}-cluster"
  tags             = local.tags
}

# --- ADD THIS NEW MODULE FOR THE S3 BUCKET ---
# (This assumes you created the modules/frontend directory and its files)
module "frontend" {
  source       = "./modules/frontend"
  project_name = var.project_name
  environment  = var.environment
  tags         = local.tags
}

module "service1" {
  source                    = "./modules/ecs_service"
  service_name              = "service1"
  ecs_cluster_id            = module.ecs_cluster.ecs_cluster_id
  ecs_cluster_name          = module.ecs_cluster.ecs_cluster_name
  log_group_name            = module.ecs_cluster.log_group_name
  image_uri                 = module.ecs_cluster.service1_ecr_repo_url
  task_role_arn             = module.iam.service1_task_role_arn
  execution_role_arn        = module.iam.ecs_task_execution_role_arn
  vpc_id                    = module.vpc.vpc_id
  subnet_ids                = module.vpc.private_subnets
  public_subnet_ids         = module.vpc.public_subnets
  ecs_security_group_ids    = [module.security.ecs_sg_id]
  tags                      = local.tags
  create_alb                = true
  alb_security_group_id     = module.security.alb_sg_id
  container_port            = 8080 // This must match your Java app's port
  sqs_queue_url             = module.messaging.sqs_queue_url
  db_host                   = module.database.db_instance_endpoint
  db_name                   = "appdb"
  db_credentials_secret_arn = module.database.db_credentials_secret_arn
}

module "service2" {
  source             = "./modules/ecs_service"
  service_name       = "service2"
  ecs_cluster_id     = module.ecs_cluster.ecs_cluster_id
  ecs_cluster_name   = module.ecs_cluster.ecs_cluster_name
  log_group_name     = module.ecs_cluster.log_group_name
  image_uri          = module.ecs_cluster.service2_ecr_repo_url
  task_role_arn      = module.iam.service2_task_role_arn
  execution_role_arn = module.iam.ecs_task_execution_role_arn
  vpc_id             = module.vpc.vpc_id

  subnet_ids                = module.vpc.private_subnets
  ecs_security_group_ids    = [module.security.ecs_sg_id]
  tags                      = local.tags
  create_alb                = false
  enable_sqs_scaling        = true
  sqs_queue_arn             = module.messaging.sqs_queue_arn
  sqs_queue_url             = module.messaging.sqs_queue_url
  sqs_queue_name            = module.messaging.sqs_queue_name
  db_host                   = module.database.db_instance_endpoint
  db_name                   = "appdb"
  db_credentials_secret_arn = module.database.db_credentials_secret_arn


}

# --- MODIFY THIS MODULE ---
module "cloudfront" {
  source       = "./modules/cloudfront"
  alb_dns_name = module.service1.alb_dns_name
  alb_zone_id  = module.service1.alb_zone_id
  tags         = local.tags

  # --- ADD THESE TWO LINES TO FIX THE ERROR ---
  s3_bucket_id = module.frontend.ui_bucket_domain_name
  oai_path     = module.frontend.oai_path
}
