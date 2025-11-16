output "ecs_task_execution_role_arn" { value = aws_iam_role.ecs_task_execution_role.arn }
output "service1_task_role_arn" { value = aws_iam_role.service1_task_role.arn }
output "service2_task_role_arn" { value = aws_iam_role.service2_task_role.arn }