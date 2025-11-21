output "cloudfront_domain_name" {
  description = "The domain name of the CloudFront distribution."
  value       = module.cloudfront.domain_name
}
output "application_url" {
  description = "The main URL to access the deployed application."
  value       = "https://${module.cloudfront.domain_name}"
}

output "service1_ecr_repository_url" {
  value       = module.ecs_cluster.service1_ecr_repo_url
}
output "alb_access_logs_s3_bucket" {
  value       = aws_s3_bucket.alb_logs.bucket
}

output "service2_ecr_repository_url" {
  value       = module.ecs_cluster.service2_ecr_repo_url
}
output "application_log_group" {
  value       = module.ecs_cluster.log_group_name
}

output "ecs_cluster_name" {
  value       = module.ecs_cluster.ecs_cluster_name
}

output "alb_dns_name" {
  value       = module.service1.alb_dns_name
}

output "ui_bucket_name" {
  value       = module.frontend.ui_bucket_name
}

# --- CHANGED OUTPUT ---
output "source_bucket_name" {
  description = "S3 Bucket for triggering the pipeline"
  value       = module.cicd.source_bucket_name
}