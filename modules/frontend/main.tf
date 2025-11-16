# modules/frontend/main.tf

resource "aws_s3_bucket" "ui_bucket" {
  bucket = "${var.project_name}-${var.environment}-ui-bucket"
  force_destroy = true
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
        Effect    = "Allow",
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