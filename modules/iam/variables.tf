variable "sqs_queue_arn" { type = string }
variable "db_instance_id" { type = string }
variable "db_credentials_secret_arn" { type = string }
variable "tags" { type = map(string) }