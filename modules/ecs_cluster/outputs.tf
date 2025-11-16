output "ecs_cluster_id" { value = aws_ecs_cluster.main.id }
output "ecs_cluster_name" { value = aws_ecs_cluster.main.name }
output "log_group_name" { value = aws_cloudwatch_log_group.main.name }
output "service1_ecr_repo_url" { value = aws_ecr_repository.service1.repository_url }
output "service2_ecr_repo_url" { value = aws_ecr_repository.service2.repository_url }