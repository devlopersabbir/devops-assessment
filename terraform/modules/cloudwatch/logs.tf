# Encrypted CloudWatch Log Groups (Customer Managed KMS Key + 30-day retention)
resource "aws_cloudwatch_log_group" "docker" {
  name              = "/aws/ec2/${local.name_prefix}/docker"
  retention_in_days = var.log_retention_days
  kms_key_id        = aws_kms_key.monitoring.arn

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-docker-logs"
  })
}

resource "aws_cloudwatch_log_group" "syslog" {
  name              = "/aws/ec2/${local.name_prefix}/syslog"
  retention_in_days = var.log_retention_days
  kms_key_id        = aws_kms_key.monitoring.arn

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-syslog"
  })
}

resource "aws_cloudwatch_log_group" "cloud_init" {
  name              = "/aws/ec2/${local.name_prefix}/cloud-init"
  retention_in_days = var.log_retention_days
  kms_key_id        = aws_kms_key.monitoring.arn

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-cloud-init-logs"
  })
}

resource "aws_cloudwatch_log_group" "ssm_agent" {
  name              = "/aws/ec2/${local.name_prefix}/ssm-agent"
  retention_in_days = var.log_retention_days
  kms_key_id        = aws_kms_key.monitoring.arn

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-ssm-agent-logs"
  })
}

resource "aws_cloudwatch_log_group" "vpc_flow_logs" {
  count = var.enable_vpc_flow_logs ? 1 : 0

  name              = "/aws/vpc/${local.name_prefix}/flow-logs"
  retention_in_days = var.log_retention_days
  kms_key_id        = aws_kms_key.monitoring.arn

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-vpc-flow-logs"
  })
}

resource "aws_cloudwatch_log_group" "lambda_discord" {
  count = var.enable_discord_notifications ? 1 : 0

  name              = "/aws/lambda/${local.name_prefix}-discord-notifier"
  retention_in_days = var.log_retention_days
  kms_key_id        = aws_kms_key.monitoring.arn

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-discord-notifier-logs"
  })
}

# VPC Flow Logs (Network Traffic Monitoring)
data "aws_iam_policy_document" "vpc_flow_logs_assume_role" {
  count = var.enable_vpc_flow_logs ? 1 : 0

  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["vpc-flow-logs.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [local.account_id]
    }
  }
}

resource "aws_iam_role" "vpc_flow_logs" {
  count = var.enable_vpc_flow_logs ? 1 : 0

  name               = "${local.name_prefix}-vpc-flow-logs-role"
  assume_role_policy = data.aws_iam_policy_document.vpc_flow_logs_assume_role[0].json

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-vpc-flow-logs-role"
  })
}

data "aws_iam_policy_document" "vpc_flow_logs_publish" {
  count = var.enable_vpc_flow_logs ? 1 : 0

  statement {
    effect = "Allow"

    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogStreams",
    ]

    resources = [
      aws_cloudwatch_log_group.vpc_flow_logs[0].arn,
      "${aws_cloudwatch_log_group.vpc_flow_logs[0].arn}:*",
    ]
  }
}

resource "aws_iam_role_policy" "vpc_flow_logs" {
  count = var.enable_vpc_flow_logs ? 1 : 0

  name   = "${local.name_prefix}-vpc-flow-logs-policy"
  role   = aws_iam_role.vpc_flow_logs[0].id
  policy = data.aws_iam_policy_document.vpc_flow_logs_publish[0].json
}

resource "aws_flow_log" "vpc" {
  count = var.enable_vpc_flow_logs ? 1 : 0

  vpc_id                   = var.vpc_id
  iam_role_arn             = aws_iam_role.vpc_flow_logs[0].arn
  log_destination          = aws_cloudwatch_log_group.vpc_flow_logs[0].arn
  log_destination_type     = "cloud-watch-logs"
  traffic_type             = var.vpc_flow_logs_traffic_type
  max_aggregation_interval = 60

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-vpc-flow-log"
  })
}

# CloudWatch Agent Configuration in SSM Parameter Store
resource "aws_ssm_parameter" "cw_agent_config" {
  name        = local.cw_agent_ssm_parameter_name
  description = "CloudWatch Agent JSON configuration for ${local.name_prefix} EC2 and Docker monitoring"
  type        = "String"

  value = jsonencode({
    agent = {
      metrics_collection_interval = 60
      run_as_user                 = "root"
    }
    metrics = {
      namespace = "CWAgent"
      append_dimensions = {
        AutoScalingGroupName = "$${aws:AutoScalingGroupName}"
        InstanceId           = "$${aws:InstanceId}"
        InstanceType         = "$${aws:InstanceType}"
        ImageId              = "$${aws:ImageId}"
      }
      aggregation_dimensions = [
        ["AutoScalingGroupName"],
        ["AutoScalingGroupName", "path"],
        ["InstanceId"],
        ["InstanceId", "path"],
      ]
      metrics_collected = {
        mem = {
          measurement = [
            "mem_used_percent",
            "mem_available_percent",
            "mem_used",
            "mem_total",
          ]
          metrics_collection_interval = 60
        }
        disk = {
          measurement = [
            "used_percent",
            "inodes_free",
            "free",
            "total",
          ]
          resources                   = ["/"]
          drop_device                 = true
          ignore_file_system_types    = ["sysfs", "devtmpfs", "tmpfs", "overlay", "squashfs", "udev"]
          metrics_collection_interval = 60
        }
        swap = {
          measurement                 = ["swap_used_percent"]
          metrics_collection_interval = 60
        }
        diskio = {
          resources                   = ["*"]
          measurement                 = ["io_time", "read_bytes", "write_bytes", "reads", "writes"]
          metrics_collection_interval = 60
        }
        netstat = {
          measurement                 = ["tcp_established", "tcp_time_wait", "tcp_close_wait"]
          metrics_collection_interval = 60
        }
        processes = {
          measurement                 = ["running", "sleeping", "zombies", "total"]
          metrics_collection_interval = 60
        }
      }
    }
    logs = {
      logs_collected = {
        files = {
          collect_list = [
            {
              file_path         = "/var/lib/docker/containers/*/*-json.log"
              log_group_name    = aws_cloudwatch_log_group.docker.name
              log_stream_name   = "{instance_id}/docker"
              retention_in_days = var.log_retention_days
            },
            {
              file_path         = "/var/log/syslog"
              log_group_name    = aws_cloudwatch_log_group.syslog.name
              log_stream_name   = "{instance_id}/syslog"
              retention_in_days = var.log_retention_days
            },
            {
              file_path         = "/var/log/cloud-init-output.log"
              log_group_name    = aws_cloudwatch_log_group.cloud_init.name
              log_stream_name   = "{instance_id}/cloud-init"
              retention_in_days = var.log_retention_days
            },
            {
              file_path         = "/var/log/amazon/ssm/amazon-ssm-agent.log"
              log_group_name    = aws_cloudwatch_log_group.ssm_agent.name
              log_stream_name   = "{instance_id}/ssm-agent"
              retention_in_days = var.log_retention_days
            },
          ]
        }
      }
    }
  })

  tags = merge(local.common_tags, {
    Name = local.cw_agent_ssm_parameter_name
  })
}

# Log Metric Filters (Application Errors/Warnings/Panics & VPC Rejected Traffic)
resource "aws_cloudwatch_log_metric_filter" "app_errors" {
  name           = "${local.name_prefix}-app-errors"
  pattern        = "\"[ERROR]\""
  log_group_name = aws_cloudwatch_log_group.docker.name

  metric_transformation {
    name          = "ApplicationErrorCount"
    namespace     = local.app_metric_namespace
    value         = "1"
    default_value = "0"
    unit          = "Count"
  }
}

resource "aws_cloudwatch_log_metric_filter" "app_warnings" {
  name           = "${local.name_prefix}-app-warnings"
  pattern        = "\"[WARN]\""
  log_group_name = aws_cloudwatch_log_group.docker.name

  metric_transformation {
    name          = "ApplicationWarningCount"
    namespace     = local.app_metric_namespace
    value         = "1"
    default_value = "0"
    unit          = "Count"
  }
}

resource "aws_cloudwatch_log_metric_filter" "app_panics" {
  name           = "${local.name_prefix}-app-panics"
  pattern        = "\"Panic recovered\""
  log_group_name = aws_cloudwatch_log_group.docker.name

  metric_transformation {
    name          = "ApplicationPanicCount"
    namespace     = local.app_metric_namespace
    value         = "1"
    default_value = "0"
    unit          = "Count"
  }
}

resource "aws_cloudwatch_log_metric_filter" "vpc_rejected_traffic" {
  count = var.enable_vpc_flow_logs ? 1 : 0

  name           = "${local.name_prefix}-vpc-rejected-packets"
  pattern        = "[version, account, eni, source, destination, srcport, destport, protocol, packets, bytes, windowstart, windowend, action=\"REJECT\", flowlogstatus]"
  log_group_name = aws_cloudwatch_log_group.vpc_flow_logs[0].name

  metric_transformation {
    name          = "VPCRejectedPacketCount"
    namespace     = local.network_metric_namespace
    value         = "1"
    default_value = "0"
    unit          = "Count"
  }
}
