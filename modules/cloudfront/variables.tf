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

# --- ADD THESE NEW VARIABLES ---

variable "s3_bucket_id" {
  description = "ID (domain name) of the S3 bucket for the UI."
  type        = string
}

variable "oai_path" {
  description = "The OAI path for CloudFront, e.g., origin-access-identity/cloudfront/E12345"
  type        = string
}