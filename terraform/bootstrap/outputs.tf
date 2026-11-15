output "state_bucket_names" {
  description = "Map of environment names to their Terraform state S3 bucket names"
  value = {
    for env, bucket in aws_s3_bucket.terraform_state : env => bucket.id
  }
}

output "state_bucket_arns" {
  description = "Map of environment names to their Terraform state S3 bucket ARNs"
  value = {
    for env, bucket in aws_s3_bucket.terraform_state : env => bucket.arn
  }
}

output "state_bucket_region" {
  description = "AWS region where the remote state S3 buckets are provisioned"
  value       = var.aws_region
}
