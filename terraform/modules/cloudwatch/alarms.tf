locals {
  base_alarms = {
    # Application Load Balancer & Target Group
    alb_unhealthy_hosts = {
      description         = "ALB target group has at least 1 unhealthy EC2 instance"
      comparison_operator = "GreaterThanOrEqualToThreshold"
      evaluation_periods  = 2
      datapoints_to_alarm = 2
      metric_name         = "UnHealthyHostCount"
      namespace           = "AWS/ApplicationELB"
      period              = 60
      statistic           = "Maximum"
      threshold           = 1
      treat_missing_data  = "notBreaching"
      dimensions = {
        TargetGroup  = var.target_group_arn_suffix
        LoadBalancer = var.alb_arn_suffix
      }
    }

    alb_no_healthy_hosts = {
      description         = "CRITICAL: ALB target group has 0 healthy targets (service outage)"
      comparison_operator = "LessThanThreshold"
      evaluation_periods  = 2
      datapoints_to_alarm = 2
      metric_name         = "HealthyHostCount"
      namespace           = "AWS/ApplicationELB"
      period              = 60
      statistic           = "Minimum"
      threshold           = 1
      treat_missing_data  = "breaching"
      dimensions = {
        TargetGroup  = var.target_group_arn_suffix
        LoadBalancer = var.alb_arn_suffix
      }
    }

    alb_elb_5xx = {
      description         = "ALB is returning 5XX gateway/load balancer errors"
      comparison_operator = "GreaterThanOrEqualToThreshold"
      evaluation_periods  = 1
      datapoints_to_alarm = 1
      metric_name         = "HTTPCode_ELB_5XX_Count"
      namespace           = "AWS/ApplicationELB"
      period              = 60
      statistic           = "Sum"
      threshold           = var.alb_5xx_threshold
      treat_missing_data  = "notBreaching"
      dimensions = {
        LoadBalancer = var.alb_arn_suffix
      }
    }

    alb_target_5xx = {
      description         = "Backend targets are returning 5XX HTTP errors"
      comparison_operator = "GreaterThanOrEqualToThreshold"
      evaluation_periods  = 1
      datapoints_to_alarm = 1
      metric_name         = "HTTPCode_Target_5XX_Count"
      namespace           = "AWS/ApplicationELB"
      period              = 60
      statistic           = "Sum"
      threshold           = var.alb_5xx_threshold
      treat_missing_data  = "notBreaching"
      dimensions = {
        TargetGroup  = var.target_group_arn_suffix
        LoadBalancer = var.alb_arn_suffix
      }
    }

    alb_target_4xx_spike = {
      description         = "Elevated 4XX client error rate from backend targets"
      comparison_operator = "GreaterThanOrEqualToThreshold"
      evaluation_periods  = 1
      datapoints_to_alarm = 1
      metric_name         = "HTTPCode_Target_4XX_Count"
      namespace           = "AWS/ApplicationELB"
      period              = 300
      statistic           = "Sum"
      threshold           = var.alb_4xx_threshold
      treat_missing_data  = "notBreaching"
      dimensions = {
        TargetGroup  = var.target_group_arn_suffix
        LoadBalancer = var.alb_arn_suffix
      }
    }

    alb_high_latency_p95 = {
      description         = "ALB target response time p95 exceeded threshold"
      comparison_operator = "GreaterThanOrEqualToThreshold"
      evaluation_periods  = 3
      datapoints_to_alarm = 2
      metric_name         = "TargetResponseTime"
      namespace           = "AWS/ApplicationELB"
      period              = 60
      extended_statistic  = "p95"
      threshold           = var.alb_latency_p95_threshold_seconds
      treat_missing_data  = "notBreaching"
      dimensions = {
        TargetGroup  = var.target_group_arn_suffix
        LoadBalancer = var.alb_arn_suffix
      }
    }

    alb_target_connection_errors = {
      description         = "ALB failed to establish TCP connections to backend targets"
      comparison_operator = "GreaterThanOrEqualToThreshold"
      evaluation_periods  = 2
      datapoints_to_alarm = 2
      metric_name         = "TargetConnectionErrorCount"
      namespace           = "AWS/ApplicationELB"
      period              = 60
      statistic           = "Sum"
      threshold           = 1
      treat_missing_data  = "notBreaching"
      dimensions = {
        TargetGroup  = var.target_group_arn_suffix
        LoadBalancer = var.alb_arn_suffix
      }
    }

    # Auto Scaling Group & EC2 Compute
    asg_high_cpu = {
      description         = "ASG average EC2 CPU utilization exceeded threshold"
      comparison_operator = "GreaterThanOrEqualToThreshold"
      evaluation_periods  = 3
      datapoints_to_alarm = 2
      metric_name         = "CPUUtilization"
      namespace           = "AWS/EC2"
      period              = 60
      statistic           = "Average"
      threshold           = var.cpu_high_threshold
      treat_missing_data  = "notBreaching"
      dimensions = {
        AutoScalingGroupName = var.asg_name
      }
    }

    asg_status_check_failed = {
      description         = "EC2 instance or system status check failed in ASG"
      comparison_operator = "GreaterThanOrEqualToThreshold"
      evaluation_periods  = 2
      datapoints_to_alarm = 2
      metric_name         = "StatusCheckFailed"
      namespace           = "AWS/EC2"
      period              = 60
      statistic           = "Maximum"
      threshold           = 1
      treat_missing_data  = "notBreaching"
      dimensions = {
        AutoScalingGroupName = var.asg_name
      }
    }

    asg_low_in_service_instances = {
      description         = "ASG in-service instance count dropped below configured minimum"
      comparison_operator = "LessThanThreshold"
      evaluation_periods  = 2
      datapoints_to_alarm = 2
      metric_name         = "GroupInServiceInstances"
      namespace           = "AWS/AutoScaling"
      period              = 60
      statistic           = "Minimum"
      threshold           = var.asg_min_size
      treat_missing_data  = "breaching"
      dimensions = {
        AutoScalingGroupName = var.asg_name
      }
    }

    # CloudWatch Agent OS Metrics (Memory, Disk, Swap)
    cwagent_high_memory = {
      description         = "ASG average memory utilization exceeded threshold"
      comparison_operator = "GreaterThanOrEqualToThreshold"
      evaluation_periods  = 3
      datapoints_to_alarm = 2
      metric_name         = "mem_used_percent"
      namespace           = "CWAgent"
      period              = 60
      statistic           = "Average"
      threshold           = var.memory_high_threshold
      treat_missing_data  = "notBreaching"
      dimensions = {
        AutoScalingGroupName = var.asg_name
      }
    }

    cwagent_high_disk = {
      description         = "Root filesystem (/) disk usage exceeded threshold on an ASG instance"
      comparison_operator = "GreaterThanOrEqualToThreshold"
      evaluation_periods  = 3
      datapoints_to_alarm = 2
      metric_name         = "disk_used_percent"
      namespace           = "CWAgent"
      period              = 60
      statistic           = "Maximum"
      threshold           = var.disk_high_threshold
      treat_missing_data  = "notBreaching"
      dimensions = {
        AutoScalingGroupName = var.asg_name
        path                 = "/"
      }
    }

    cwagent_high_swap = {
      description         = "ASG average swap utilization exceeded threshold"
      comparison_operator = "GreaterThanOrEqualToThreshold"
      evaluation_periods  = 5
      datapoints_to_alarm = 3
      metric_name         = "swap_used_percent"
      namespace           = "CWAgent"
      period              = 60
      statistic           = "Average"
      threshold           = var.swap_high_threshold
      treat_missing_data  = "notBreaching"
      dimensions = {
        AutoScalingGroupName = var.asg_name
      }
    }

    # Application Container Log Metric Alarms
    app_error_logs = {
      description         = "Application Docker logs recorded elevated [ERROR] events"
      comparison_operator = "GreaterThanOrEqualToThreshold"
      evaluation_periods  = 1
      datapoints_to_alarm = 1
      metric_name         = "ApplicationErrorCount"
      namespace           = local.app_metric_namespace
      period              = 300
      statistic           = "Sum"
      threshold           = var.app_error_log_threshold
      treat_missing_data  = "notBreaching"
      dimensions          = {}
    }

    app_panic_logs = {
      description         = "CRITICAL: Application recovered from a Go runtime panic"
      comparison_operator = "GreaterThanOrEqualToThreshold"
      evaluation_periods  = 1
      datapoints_to_alarm = 1
      metric_name         = "ApplicationPanicCount"
      namespace           = local.app_metric_namespace
      period              = 60
      statistic           = "Sum"
      threshold           = 1
      treat_missing_data  = "notBreaching"
      dimensions          = {}
    }
  }

  burstable_cpu_alarms = local.is_burstable_instance ? {
    asg_low_cpu_credits = {
      description         = "Burstable EC2 instance CPUCreditBalance dropped below safe threshold"
      comparison_operator = "LessThanThreshold"
      evaluation_periods  = 3
      datapoints_to_alarm = 2
      metric_name         = "CPUCreditBalance"
      namespace           = "AWS/EC2"
      period              = 60
      statistic           = "Minimum"
      threshold           = var.cpu_credit_low_threshold
      treat_missing_data  = "notBreaching"
      dimensions = {
        AutoScalingGroupName = var.asg_name
      }
    }
  } : {}

  nat_gateway_alarms = var.nat_gateway_id != "" ? {
    nat_port_allocation_errors = {
      description         = "NAT Gateway experienced SNAT port allocation errors"
      comparison_operator = "GreaterThanOrEqualToThreshold"
      evaluation_periods  = 2
      datapoints_to_alarm = 2
      metric_name         = "ErrorPortAllocation"
      namespace           = "AWS/NATGateway"
      period              = 60
      statistic           = "Sum"
      threshold           = 1
      treat_missing_data  = "notBreaching"
      dimensions = {
        NatGatewayId = var.nat_gateway_id
      }
    }

    nat_packets_dropped = {
      description         = "NAT Gateway dropped packets above threshold"
      comparison_operator = "GreaterThanOrEqualToThreshold"
      evaluation_periods  = 3
      datapoints_to_alarm = 2
      metric_name         = "PacketsDropCount"
      namespace           = "AWS/NATGateway"
      period              = 60
      statistic           = "Sum"
      threshold           = 10
      treat_missing_data  = "notBreaching"
      dimensions = {
        NatGatewayId = var.nat_gateway_id
      }
    }
  } : {}

  vpc_flow_alarms = var.enable_vpc_flow_logs ? {
    vpc_rejected_traffic_spike = {
      description         = "Spike in REJECT traffic recorded in VPC Flow Logs"
      comparison_operator = "GreaterThanOrEqualToThreshold"
      evaluation_periods  = 1
      datapoints_to_alarm = 1
      metric_name         = "VPCRejectedPacketCount"
      namespace           = local.network_metric_namespace
      period              = 300
      statistic           = "Sum"
      threshold           = var.vpc_rejected_packet_threshold
      treat_missing_data  = "notBreaching"
      dimensions          = {}
    }
  } : {}

  discord_lambda_alarms = var.enable_discord_notifications ? {
    discord_notifier_lambda_errors = {
      description         = "Discord notification Lambda function encountered invocation errors"
      comparison_operator = "GreaterThanOrEqualToThreshold"
      evaluation_periods  = 1
      datapoints_to_alarm = 1
      metric_name         = "Errors"
      namespace           = "AWS/Lambda"
      period              = 60
      statistic           = "Sum"
      threshold           = 1
      treat_missing_data  = "notBreaching"
      dimensions = {
        FunctionName = aws_lambda_function.discord_notifier[0].function_name
      }
    }
  } : {}

  metric_alarms = merge(
    local.base_alarms,
    local.burstable_cpu_alarms,
    local.nat_gateway_alarms,
    local.vpc_flow_alarms,
    local.discord_lambda_alarms,
  )
}

resource "aws_cloudwatch_metric_alarm" "this" {
  for_each = local.metric_alarms

  alarm_name          = "${local.name_prefix}-${replace(each.key, "_", "-")}"
  alarm_description   = each.value.description
  comparison_operator = each.value.comparison_operator
  evaluation_periods  = each.value.evaluation_periods
  datapoints_to_alarm = each.value.datapoints_to_alarm
  metric_name         = each.value.metric_name
  namespace           = each.value.namespace
  period              = each.value.period
  statistic           = try(each.value.statistic, null)
  extended_statistic  = try(each.value.extended_statistic, null)
  threshold           = each.value.threshold
  treat_missing_data  = each.value.treat_missing_data
  dimensions          = length(each.value.dimensions) > 0 ? each.value.dimensions : null

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-${replace(each.key, "_", "-")}"
  })
}
