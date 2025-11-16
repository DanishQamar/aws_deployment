variable "project_name" {
  description = "The name of the project."
  type        = string
}

variable "environment" {
  description = "The environment (e.g., dev, prod)."
  type        = string
}

variable "tags" {
  description = "A map of tags to apply to resources."
  type        = map(string)
}