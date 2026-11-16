data "aws_iam_policy_document" "monitoring_kms" {
  # Allow account administrators to manage the KMS key
  statement {
    sid    = "EnableIAMUserPermissions"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${local.account_id}:root"]
    }

    actions   = ["kms:*"]
    resources = ["*"]
  }

  # Allow CloudWatch Logs to encrypt and decrypt log groups in this region/account
  statement {
    sid    = "AllowCloudWatchLogsEncryption"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["logs.${var.aws_region}.amazonaws.com"]
    }

    actions = [
      "kms:Encrypt*",
      "kms:Decrypt*",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:Describe*",
    ]

    resources = ["*"]

    condition {
      test     = "ArnLike"
      variable = "kms:EncryptionContext:aws:logs:arn"
      values   = ["arn:aws:logs:${var.aws_region}:${local.account_id}:log-group:*"]
    }
  }

  # Allow CloudWatch Alarms to generate data keys when publishing to the KMS-encrypted SNS topic
  statement {
    sid    = "AllowCloudWatchAlarmsUseOfKey"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["cloudwatch.amazonaws.com"]
    }

    actions = [
      "kms:Decrypt",
      "kms:GenerateDataKey*",
    ]

    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [local.account_id]
    }

    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = ["arn:aws:cloudwatch:${var.aws_region}:${local.account_id}:alarm:*"]
    }
  }

  # Allow SNS service to decrypt/generate data keys for topic encryption and delivery
  statement {
    sid    = "AllowSNSUseOfKey"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["sns.amazonaws.com"]
    }

    actions = [
      "kms:Decrypt",
      "kms:GenerateDataKey*",
    ]

    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [local.account_id]
    }
  }
}

resource "aws_kms_key" "monitoring" {
  description             = "Customer Managed KMS Key for ${local.name_prefix} CloudWatch Logs, SNS alerts, and Lambda"
  deletion_window_in_days = var.kms_deletion_window_in_days
  enable_key_rotation     = true
  policy                  = data.aws_iam_policy_document.monitoring_kms.json

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-monitoring-kms"
  })
}

resource "aws_kms_alias" "monitoring" {
  name          = "alias/${local.name_prefix}-monitoring"
  target_key_id = aws_kms_key.monitoring.key_id
}
