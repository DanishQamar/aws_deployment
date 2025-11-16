output "cloudfront_domain_name" {
  description = "The domain name of the CloudFront distribution."
  value       = module.cloudfront.domain_name
}

output "service1_ecr_repository_url" {
  description = "The ID of the CloudFront distribution."
  value       = module.ecs_cluster.service1_ecr_repo_url
}