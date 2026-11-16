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

output "instance_id" {
  description = "The ID of the staging EC2 instance"
  value       = module.ec2.instance_id
}

output "instance_name" {
  description = "The Name tag of the staging EC2 instance"
  value       = module.ec2.instance_name
}

output "private_ip" {
  description = "The private IP address of the staging EC2 instance"
  value       = module.ec2.private_ip
}

output "public_ip" {
  description = "The static public IP (Elastic IP) of the staging EC2 instance"
  value       = module.ec2.public_ip
}

output "app_url" {
  description = "Public HTTP URL to access the staging application directly via static IP"
  value       = "http://${module.ec2.public_ip}:8080"
}
