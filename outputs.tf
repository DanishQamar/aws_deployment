output "alb_dns_name" {
  description = "The DNS name of the Application Load Balancer for Service 1."
  value       = module.service1.alb_dns_name
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