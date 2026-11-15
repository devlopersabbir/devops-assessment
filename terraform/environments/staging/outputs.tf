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

output "asg_name" {
  description = "The name of the Auto Scaling Group"
  value       = module.asg.asg_name
}

output "launch_template_id" {
  description = "The ID of the EC2 Launch Template"
  value       = module.asg.launch_template_id
}

output "alb_dns_name" {
  description = "Public DNS name of the Application Load Balancer"
  value       = module.alb.alb_dns_name
}

output "alb_url" {
  description = "Public HTTP URL of the Application Load Balancer"
  value       = "http://${module.alb.alb_dns_name}"
}
