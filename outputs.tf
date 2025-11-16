output "cloudfront_domain_name" {
  description = "The domain name of the CloudFront distribution."
  value       = module.cloudfront.domain_name
}

output "service1_ecr_repository_url" {
  description = "The ECR repository URL for Service 1."
  value       = module.ecs_cluster.service1_ecr_repo_url
}

output "service2_ecr_repository_url" {
  description = "The ECR repository URL for Service 2."
  value       = module.ecs_cluster.service2_ecr_repo_url
}

output "ecs_cluster_name" {
  description = "The name of the ECS cluster."
  value       = module.ecs_cluster.ecs_cluster_name
}

output "alb_dns_name" {
  description = "The DNS name of the ALB for Service 1."
  value       = module.service1.alb_dns_name
}

# --- ADD THIS NEW OUTPUT ---
output "ui_bucket_name" {
  description = "The name (ID) of the S3 bucket."
  value       = module.frontend.ui_bucket_name
}