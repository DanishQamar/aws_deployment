variable "project_name" { type = string }
variable "environment" { type = string }
variable "aws_region" { type = string }
variable "tags" { type = map(string) }

# ECS Service Details for Deployment
variable "ecs_cluster_name" { type = string }
variable "service1_name" { type = string }
variable "service2_name" { type = string }

# ECR Repository URLs for Build
variable "service1_ecr_url" { type = string }
variable "service2_ecr_url" { type = string }