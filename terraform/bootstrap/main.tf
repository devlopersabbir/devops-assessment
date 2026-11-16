# 1. S3 Bucket for Terraform Remote State
# trivy:ignore:AVD-AWS-0132 -- Using AES256 (SSE-S3) instead of a paid Customer Managed KMS key
resource "aws_s3_bucket" "terraform_state" {
  for_each = toset(var.environments)

  bucket = "${var.project_name}-${each.key}-tfstate-1"

  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Name        = "${var.project_name}-${each.key}-tfstate-1"
    Environment = each.key
  }
}

# 2. Bucket Versioning
resource "aws_s3_bucket_versioning" "terraform_state" {
  for_each = toset(var.environments)

  bucket = aws_s3_bucket.terraform_state[each.key].id

  versioning_configuration {
    status = "Enabled"
  }
}

# 3. Server-Side Encryption Configuration
# trivy:ignore:AVD-AWS-0132 -- Using AES256 (SSE-S3) instead of a paid Customer Managed KMS key
resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  for_each = toset(var.environments)

  bucket = aws_s3_bucket.terraform_state[each.key].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

# 4. Block All Public Access
resource "aws_s3_bucket_public_access_block" "terraform_state" {
  for_each = toset(var.environments)

  bucket = aws_s3_bucket.terraform_state[each.key].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
