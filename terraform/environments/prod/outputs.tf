output "vpc_id" {
  description = "The ID of the prod VPC"
  value       = module.vpc.vpc_id
}

output "vpc_arn" {
  description = "The ARN of the prod VPC"
  value       = module.vpc.vpc_arn
}

output "vpc_cidr_block" {
  description = "The CIDR block of the prod VPC"
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

output "cloudwatch_dashboard_url" {
  description = "AWS Console URL for the CloudWatch monitoring dashboard"
  value       = module.cloudwatch.dashboard_url
}

output "sns_alerts_topic_arn" {
  description = "ARN of the encrypted SNS topic receiving CloudWatch alarms"
  value       = module.cloudwatch.sns_topic_arn
}

output "monitoring_kms_key_arn" {
  description = "ARN of the Customer Managed KMS key for monitoring encryption"
  value       = module.cloudwatch.kms_key_arn
}

output "cw_agent_ssm_parameter_name" {
  description = "SSM Parameter Store name for the CloudWatch Agent configuration"
  value       = module.cloudwatch.agent_ssm_parameter_name
}

output "cloudwatch_log_groups" {
  description = "Map of CloudWatch Log Group names"
  value       = module.cloudwatch.log_group_names
}

output "discord_notifier_lambda_name" {
  description = "Name of the Discord webhook Lambda forwarder"
  value       = module.cloudwatch.discord_notifier_lambda_name
}
