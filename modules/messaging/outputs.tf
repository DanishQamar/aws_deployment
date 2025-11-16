output "sqs_queue_arn" { value = aws_sqs_queue.default.arn }
output "sqs_queue_url" { value = aws_sqs_queue.default.id }
output "sqs_queue_name" { value = aws_sqs_queue.default.name }