output "kms_key_id" {
  description = "ID of the Customer Managed KMS key used for monitoring encryption"
  value       = aws_kms_key.monitoring.key_id
}

output "kms_key_arn" {
  description = "ARN of the Customer Managed KMS key used for monitoring encryption"
  value       = aws_kms_key.monitoring.arn
}

output "kms_key_alias" {
  description = "Alias of the Customer Managed KMS key used for monitoring encryption"
  value       = aws_kms_alias.monitoring.name
}

output "sns_topic_arn" {
  description = "ARN of the encrypted SNS topic receiving CloudWatch alarm notifications"
  value       = aws_sns_topic.alerts.arn
}

output "dashboard_name" {
  description = "Name of the CloudWatch overview dashboard"
  value       = aws_cloudwatch_dashboard.main.dashboard_name
}

output "dashboard_url" {
  description = "AWS Console URL for the CloudWatch overview dashboard"
  value       = "https://${var.aws_region}.console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#dashboards:name=${aws_cloudwatch_dashboard.main.dashboard_name}"
}

output "agent_ssm_parameter_name" {
  description = "Name of the SSM Parameter storing the CloudWatch Agent JSON configuration"
  value       = aws_ssm_parameter.cw_agent_config.name
}

output "log_group_names" {
  description = "Map of CloudWatch Log Group names created by this module"
  value = merge(
    {
      docker     = aws_cloudwatch_log_group.docker.name
      syslog     = aws_cloudwatch_log_group.syslog.name
      cloud_init = aws_cloudwatch_log_group.cloud_init.name
      ssm_agent  = aws_cloudwatch_log_group.ssm_agent.name
    },
    var.enable_vpc_flow_logs ? {
      vpc_flow_logs = aws_cloudwatch_log_group.vpc_flow_logs[0].name
    } : {},
    var.enable_discord_notifications ? {
      discord_lambda = aws_cloudwatch_log_group.lambda_discord[0].name
    } : {},
  )
}

output "discord_notifier_lambda_name" {
  description = "Name of the Discord webhook Lambda forwarder (null if disabled)"
  value       = var.enable_discord_notifications ? aws_lambda_function.discord_notifier[0].function_name : null
}

output "discord_notifier_lambda_arn" {
  description = "ARN of the Discord webhook Lambda forwarder (null if disabled)"
  value       = var.enable_discord_notifications ? aws_lambda_function.discord_notifier[0].arn : null
}

output "alarm_arns" {
  description = "Map of CloudWatch alarm keys to their ARNs"
  value       = { for k, alarm in aws_cloudwatch_metric_alarm.this : k => alarm.arn }
}
