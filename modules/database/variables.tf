variable "vpc_id" { type = string }
variable "db_subnets" { type = list(string) }
variable "db_security_group" { type = string }
variable "db_username" { type = string }
variable "db_password" { type = string }
variable "tags" { type = map(string) }