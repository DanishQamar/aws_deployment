output "alb_dns_name" {
  value = var.create_alb ? aws_lb.main[0].dns_name : null
}