variable "alb_dns_name" {
  description = "DNS name of the ALB origin."
  type        = string
}

variable "alb_zone_id" {
  description = "Zone ID of the ALB origin."
  type        = string
}

variable "tags" {
  description = "Tags to apply to resources."
  type        = map(string)
}