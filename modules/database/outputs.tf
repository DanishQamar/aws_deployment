output "db_instance_id" { value = aws_db_instance.default.id }
output "db_instance_endpoint" { value = aws_db_instance.default.address }
output "db_credentials_secret_arn" { value = aws_secretsmanager_secret.db_credentials.arn }