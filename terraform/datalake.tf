# 1. Create the secure Data Lake S3 Bucket
resource "aws_s3_bucket" "data_lake" {
  bucket        = "ps-ingress-data-lake-${random_string.suffix.result}"
  force_destroy = true # Allows clean teardown via terraform destroy

  tags = {
    Environment = "production"
    Layer       = "storage"
  }
}

# Generate a unique suffix to prevent S3 bucket naming collisions
resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

# 2. Enforce absolute private access on the S3 Bucket (Public Sector Hardening)
resource "aws_s3_bucket_public_access_block" "data_lake_privacy" {
  bucket = aws_s3_bucket.data_lake.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
