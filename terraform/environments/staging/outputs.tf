output "vpc_id" {
  description = "The ID of the staging VPC"
  value       = module.vpc.vpc_id
}

output "vpc_arn" {
  description = "The ARN of the staging VPC"
  value       = module.vpc.vpc_arn
}

output "vpc_cidr_block" {
  description = "The CIDR block of the staging VPC"
  value       = module.vpc.vpc_cidr_block
}
