resource "aws_s3_bucket" "prod_ui_bucket" {
  bucket = "zip-codes-ui-bucket-prod"

  tags = {
    Name        = "UI Bucket - Production"
    Environment = "PROD"
  }
}

resource "aws_s3_bucket_ownership_controls" "website_bucket_controls" {
  bucket = aws_s3_bucket.prod_ui_bucket.id

  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_versioning" "prod_bucket_versioning" {
  bucket = aws_s3_bucket.prod_ui_bucket.id
  versioning_configuration {
    status = "Disabled"
  }
}

resource "aws_s3_bucket_acl" "website_bucket_acl" {
  depends_on = [aws_s3_bucket_ownership_controls.website_bucket_controls]

  bucket = aws_s3_bucket.prod_ui_bucket.id
  acl    = "private"
}


resource "aws_s3_bucket_policy" "bucket_policy" {
  bucket = aws_s3_bucket.prod_ui_bucket.id

  policy = jsonencode({
    Version   = "2012-10-17"
    Id        = "MyPolicy"
    Statement = [
      {
        Sid       = "1"
        Effect    = "Allow"
        Principal = {
          AWS = "arn:aws:iam::cloudfront:user/CloudFront Origin Access Identity ${aws_cloudfront_origin_access_identity.oai.id}"
        }
        Action   = "s3:GetObject"
        Resource = "arn:aws:s3:::${aws_s3_bucket.prod_ui_bucket.id}/*"
      }
    ]
  })
}
