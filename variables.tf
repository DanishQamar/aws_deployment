variable "aws_region" {
  description = "AWS region for deployment."
  type        = string
  default     = "ap-south-1"
}

variable "project_name" {
  description = "DanishQamar-Aws Deployment"
  type        = string
}

variable "environment" {
  description = "prod"
  type        = string
}

variable "ecs_cluster_name" {
  description = "The name to give the ECS Cluster. Should be unique per environment."
  type        = string
  default     = "dev-cluster"
}

variable "db_username" {
  description = "Database admin username."
  type        = string
  sensitive   = true
}

variable "db_password" {
  description = "Database admin password."
  type        = string
  sensitive   = true
}