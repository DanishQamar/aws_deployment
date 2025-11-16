output "alb_dns_name" {
  description = "The DNS name of the Application Load Balancer for Service 1."
  value = var.create_alb ? aws_lb.main[0].dns_name : null
}

output "alb_zone_id" {
  description = "The zone ID of the Application Load Balancer for Service 1."
  value       = var.create_alb ? aws_lb.main[0].zone_id : null
}