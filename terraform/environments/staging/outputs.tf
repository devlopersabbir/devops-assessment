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

output "ec2_instance_id" {
  description = "The ID of the staging EC2 instance"
  value       = module.ec2.instance_id
}

output "ec2_private_ip" {
  description = "The private IP address of the staging EC2 instance"
  value       = module.ec2.private_ip
}

output "ssm_session_command" {
  description = "AWS CLI command to connect to the EC2 instance via SSM Session Manager"
  value       = "aws ssm start-session --target ${module.ec2.instance_id} --region ${var.aws_region}${var.aws_profile != "" ? " --profile ${var.aws_profile}" : ""}"
}

output "alb_dns_name" {
  description = "Public DNS name of the Application Load Balancer"
  value       = module.alb.alb_dns_name
}

output "alb_url" {
  description = "Public HTTP URL of the Application Load Balancer"
  value       = "http://${module.alb.alb_dns_name}"
}
