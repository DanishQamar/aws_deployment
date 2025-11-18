# modules/frontend/main.tf

resource "aws_s3_bucket" "ui_bucket" {
  bucket        = "${var.project_name}-${var.environment}-ui-bucket"
  force_destroy = true
}
# This explicitly blocks all public access to the S3 bucket,
# ensuring that content is ONLY served through CloudFront.
resource "aws_s3_bucket_public_access_block" "ui_bucket_access_block" {
  bucket = aws_s3_bucket.ui_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_cloudfront_origin_access_identity" "oai" {
  comment = "OAI for ${aws_s3_bucket.ui_bucket.id}"
}

resource "aws_s3_bucket_policy" "bucket_policy" {
  bucket = aws_s3_bucket.ui_bucket.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          AWS = aws_cloudfront_origin_access_identity.oai.iam_arn
        },
        Action   = "s3:GetObject",
        Resource = "${aws_s3_bucket.ui_bucket.arn}/*"
      }
    ]
  })
}

output "ui_bucket_id" { value = aws_s3_bucket.ui_bucket.id }
output "oai_iam_arn" { value = aws_cloudfront_origin_access_identity.oai.iam_arn }
output "oai_id" { value = aws_cloudfront_origin_access_identity.oai.id }
