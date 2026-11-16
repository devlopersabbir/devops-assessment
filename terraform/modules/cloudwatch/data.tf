data "aws_caller_identity" "current" {}

data "archive_file" "discord_notifier" {
  count = var.enable_discord_notifications ? 1 : 0

  type        = "zip"
  source_file = "${path.module}/lambda/discord_notifier.py"
  output_path = "${path.module}/.build/discord_notifier.zip"
}

locals {
  name_prefix = "${var.project_name}-${var.environment}"
  account_id  = data.aws_caller_identity.current.account_id

  cw_agent_ssm_parameter_name = (
    var.agent_ssm_parameter_name != ""
    ? var.agent_ssm_parameter_name
    : "AmazonCloudWatch-${local.name_prefix}-agent-config"
  )

  sns_topic_name        = "${local.name_prefix}-cloudwatch-alerts"
  is_burstable_instance = can(regex("^t[234]", var.instance_type))

  app_metric_namespace     = "${var.project_name}/${var.environment}/Application"
  network_metric_namespace = "${var.project_name}/${var.environment}/Network"

  common_tags = merge(var.tags, {
    Environment = var.environment
  })
}
