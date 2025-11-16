variable "aws_region" {
  description = "The AWS region to deploy resources in."
  type        = string
}

variable "project_name" { type = string }
variable "environment" { type = string }
variable "db_username" { type = string }
variable "db_password" { type = string }