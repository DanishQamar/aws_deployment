variable "tags" { type = map(string) }
variable "ecs_cluster_name" {
  description = "The name for the ECS cluster."
  type        = string
}