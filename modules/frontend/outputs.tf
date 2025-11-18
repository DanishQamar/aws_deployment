output "ui_bucket_domain_name" {
  description = "The domain name of the S3 bucket for the UI."
  # --- FIX: Changed from .bucket_domain_name to .bucket_regional_domain_name ---
  value = aws_s3_bucket.ui_bucket.bucket_regional_domain_name
}

output "oai_path" {
  description = "The path for the OAI (e.g., origin-access-identity/cloudfront/E12345)"
  value       = aws_cloudfront_origin_access_identity.oai.cloudfront_access_identity_path
}

# --- ADD THIS NEW OUTPUT ---
output "ui_bucket_name" {
  description = "The name (ID) of the S3 bucket."
  value       = aws_s3_bucket.ui_bucket.id
}
