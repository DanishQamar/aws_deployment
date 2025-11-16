variable "service_name" { type = string }
variable "ecs_cluster_id" { type = string }
variable "ecs_cluster_name" { type = string } # Needed for scaling resource ID
variable "log_group_name" { type = string }
variable "image_uri" { type = string }
variable "task_role_arn" { type = string }
variable "execution_role_arn" { type = string }
variable "vpc_id" { type = string }
variable "subnet_ids" { type = list(string) } # Private subnets for tasks
variable "public_subnet_ids" {
  type    = list(string)
  default = []
} # Public subnets for ALB
variable "ecs_security_group_ids" { type = list(string) }
variable "tags" { type = map(string) }

variable "cpu" {
  type    = number
  default = 256 # 0.25 vCPU
}
variable "memory" {
  type    = number
  default = 512 # 0.5 GB
}
variable "desired_count" {
  type    = number
  default = 1
}

# Service 1 variables
variable "create_alb" {
  type    = bool
  default = false
}
variable "alb_security_group_id" {
  type    = string
  default = null
}
variable "container_port" {
  type    = number
  default = null
}

# Service 2 variables
variable "enable_sqs_scaling" {
  type    = bool
  default = false
}
variable "sqs_queue_arn" {
  type    = string
  default = ""
}
variable "sqs_queue_url" {
  type    = string
  default = ""
}
variable "min_tasks" {
  type    = number
  default = 1
}
variable "max_tasks" {
  type    = number
  default = 4 # As per your diagram
}

# Database variables (passed from root)
variable "db_host" {
  type    = string
  default = null
}
variable "db_name" {
  type    = string
  default = null
}
variable "db_credentials_secret_arn" {
  type    = string
  default = null
}
