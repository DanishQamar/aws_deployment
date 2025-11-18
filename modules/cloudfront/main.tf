# modules/cloudfront/main.tf

resource "aws_cloudfront_distribution" "s3_distribution" {

  # 1. S3 Origin (for the UI)
  origin {
    domain_name = var.s3_bucket_id # e.g., "my-project-ui-bucket.s3.amazonaws.com"
    origin_id   = "s3-origin"

    s3_origin_config {
      origin_access_identity = var.oai_path # e.g., "origin-access-identity/cloudfront/E12345678"
    }
  }

  # 2. ALB Origin (for the API)
  origin {
    domain_name = var.alb_dns_name
    origin_id   = "alb-origin"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  enabled             = true
  default_root_object = "index.html"

  # 3. Default Behavior (serves from S3)
  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "s3-origin" # Default to S3

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }
    viewer_protocol_policy = "redirect-to-https"
  }

  # 4. API Behavior (serves from ALB)
  # This routes all API calls to the ALB origin
  ordered_cache_behavior {
    path_pattern     = "/submit-job*" # Or "/api/*" if you prefix your routes
    allowed_methods  = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "alb-origin"

    forwarded_values {
      query_string = true
      headers      = ["Origin", "Access-Control-Request-Method", "Access-Control-Request-Headers"]
      cookies {
        forward = "all" # Forward all cookies to the backend
      }
    }
    viewer_protocol_policy = "redirect-to-https"
  }

  ordered_cache_behavior {
    path_pattern     = "/jobs*"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "alb-origin" # Point to the ALB

    forwarded_values {
      query_string = true
      headers      = ["Origin"]
      cookies {
        forward = "all"
      }
    }
    viewer_protocol_policy = "redirect-to-https"
  }

  # --- ADD THIS NEW BLOCK FOR SCALING ---
  ordered_cache_behavior {
    path_pattern     = "/update-scaling*"
    allowed_methods  = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "alb-origin" # Point to the ALB

    forwarded_values {
      query_string = true
      headers      = ["Origin"]
      cookies {
        forward = "all"
      }
    }
    viewer_protocol_policy = "redirect-to-https"
  }
  # --- END NEW BLOCK ---

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
  tags = var.tags
}