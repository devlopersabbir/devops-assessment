# Encrypted SNS Topic for CloudWatch Alarms
resource "aws_sns_topic" "alerts" {
  name              = local.sns_topic_name
  kms_master_key_id = aws_kms_key.monitoring.id

  tags = merge(local.common_tags, {
    Name = local.sns_topic_name
  })
}

data "aws_iam_policy_document" "sns_alerts_policy" {
  statement {
    sid    = "AllowCloudWatchAlarmsToPublish"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["cloudwatch.amazonaws.com"]
    }

    actions   = ["sns:Publish"]
    resources = [aws_sns_topic.alerts.arn]

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [local.account_id]
    }
  }
}

resource "aws_sns_topic_policy" "alerts" {
  arn    = aws_sns_topic.alerts.arn
  policy = data.aws_iam_policy_document.sns_alerts_policy.json
}

# Optional Email Subscriptions
resource "aws_sns_topic_subscription" "email" {
  for_each = toset(var.alert_emails)

  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = each.value
}

# Discord Webhook Lambda Forwarder (SNS -> Lambda -> Discord)
data "aws_iam_policy_document" "lambda_assume_role" {
  count = var.enable_discord_notifications ? 1 : 0

  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "discord_notifier" {
  count = var.enable_discord_notifications ? 1 : 0

  name               = "${local.name_prefix}-discord-notifier-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role[0].json

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-discord-notifier-role"
  })
}

data "aws_iam_policy_document" "discord_notifier_logs_and_kms" {
  count = var.enable_discord_notifications ? 1 : 0

  statement {
    sid    = "AllowLambdaCloudWatchLogs"
    effect = "Allow"

    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]

    resources = ["${aws_cloudwatch_log_group.lambda_discord[0].arn}:*"]
  }

  statement {
    sid    = "AllowDecryptLambdaEnvVars"
    effect = "Allow"

    actions   = ["kms:Decrypt"]
    resources = [aws_kms_key.monitoring.arn]
  }
}

resource "aws_iam_role_policy" "discord_notifier_logs_and_kms" {
  count = var.enable_discord_notifications ? 1 : 0

  name   = "${local.name_prefix}-discord-notifier-policy"
  role   = aws_iam_role.discord_notifier[0].id
  policy = data.aws_iam_policy_document.discord_notifier_logs_and_kms[0].json
}

data "aws_iam_policy_document" "discord_notifier_xray" {
  count = var.enable_discord_notifications ? 1 : 0

  statement {
    sid    = "AllowXRayActiveTracing"
    effect = "Allow"

    actions = [
      "xray:PutTraceSegments",
      "xray:PutTelemetryRecords",
    ]

    resources = ["*"]
  }
}

# trivy:ignore:AVD-AWS-0057 -- AWS X-Ray PutTraceSegments/PutTelemetryRecords do not support resource-level ARN scoping
resource "aws_iam_role_policy" "discord_notifier_xray" {
  count = var.enable_discord_notifications ? 1 : 0

  name   = "${local.name_prefix}-discord-notifier-xray-policy"
  role   = aws_iam_role.discord_notifier[0].id
  policy = data.aws_iam_policy_document.discord_notifier_xray[0].json
}

resource "aws_lambda_function" "discord_notifier" {
  count = var.enable_discord_notifications ? 1 : 0

  function_name    = "${local.name_prefix}-discord-notifier"
  description      = "Forwards CloudWatch Alarm notifications from SNS to Discord"
  role             = aws_iam_role.discord_notifier[0].arn
  runtime          = "python3.13"
  handler          = "discord_notifier.lambda_handler"
  filename         = data.archive_file.discord_notifier[0].output_path
  source_code_hash = data.archive_file.discord_notifier[0].output_base64sha256
  timeout          = 10
  memory_size      = 128
  kms_key_arn      = aws_kms_key.monitoring.arn

  tracing_config {
    mode = "Active"
  }

  environment {
    variables = {
      DISCORD_WEBHOOK_URL = var.discord_webhook_url
      PROJECT_NAME        = var.project_name
      ENVIRONMENT         = var.environment
    }
  }

  depends_on = [
    aws_cloudwatch_log_group.lambda_discord,
    aws_iam_role_policy.discord_notifier_logs_and_kms,
    aws_iam_role_policy.discord_notifier_xray,
  ]

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-discord-notifier"
  })
}

resource "aws_lambda_permission" "sns_discord" {
  count = var.enable_discord_notifications ? 1 : 0

  statement_id  = "AllowExecutionFromSNS"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.discord_notifier[0].function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.alerts.arn
}

resource "aws_sns_topic_subscription" "discord" {
  count = var.enable_discord_notifications ? 1 : 0

  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.discord_notifier[0].arn
}
