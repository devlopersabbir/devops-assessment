locals {
  dashboard_name = "${local.name_prefix}-overview"

  nat_gateway_widget = var.enable_nat_gateway_monitoring ? [
    {
      type   = "metric"
      x      = 0
      y      = 24
      width  = 12
      height = 6
      properties = {
        title  = "NAT Gateway - Throughput, Connections & Drops"
        region = var.aws_region
        period = 60
        view   = "timeSeries"
        metrics = [
          ["AWS/NATGateway", "BytesOutToDestination", "NatGatewayId", var.nat_gateway_id, { stat = "Sum", label = "Bytes Out" }],
          [".", "BytesInFromSource", ".", ".", { stat = "Sum", label = "Bytes In" }],
          [".", "ActiveConnectionCount", ".", ".", { stat = "Maximum", yAxis = "right", label = "Active Connections" }],
          [".", "PacketsDropCount", ".", ".", { stat = "Sum", yAxis = "right", color = "#d62728", label = "Dropped Packets" }],
          [".", "ErrorPortAllocation", ".", ".", { stat = "Sum", yAxis = "right", color = "#9467bd", label = "Port Alloc Errors" }],
        ]
        yAxis = {
          left  = { min = 0 }
          right = { min = 0 }
        }
      }
    }
  ] : []

  vpc_flow_log_widget = var.enable_vpc_flow_logs ? [
    {
      type   = "log"
      x      = 12
      y      = 30
      width  = 12
      height = 6
      properties = {
        title  = "VPC Flow Logs - Top Rejected Sources"
        region = var.aws_region
        view   = "table"
        query  = "SOURCE '${aws_cloudwatch_log_group.vpc_flow_logs[0].name}' | filter action = 'REJECT' | stats count(*) as rejected_packets by srcAddr, dstPort, protocol | sort rejected_packets desc | limit 20"
      }
    }
  ] : []

  dashboard_widgets = concat(
    [
      # Row 0: Live Alarm Status Board
      {
        type   = "alarm"
        x      = 0
        y      = 0
        width  = 24
        height = 6
        properties = {
          title  = "${local.name_prefix} - Active Alarm Status"
          alarms = [for alarm in aws_cloudwatch_metric_alarm.this : alarm.arn]
        }
      },

      # Row 1: ALB Traffic, HTTP Status Codes & Latency
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        properties = {
          title  = "ALB - Request Volume & HTTP Status Codes"
          region = var.aws_region
          period = 60
          stat   = "Sum"
          view   = "timeSeries"
          metrics = [
            ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", var.alb_arn_suffix, { label = "Total Requests", color = "#1f77b4" }],
            [".", "HTTPCode_Target_2XX_Count", ".", ".", "TargetGroup", var.target_group_arn_suffix, { label = "Target 2XX", color = "#2ca02c" }],
            [".", "HTTPCode_Target_4XX_Count", ".", ".", ".", ".", { label = "Target 4XX", color = "#ff7f0e" }],
            [".", "HTTPCode_Target_5XX_Count", ".", ".", ".", ".", { label = "Target 5XX", color = "#d62728" }],
            [".", "HTTPCode_ELB_5XX_Count", "LoadBalancer", var.alb_arn_suffix, { label = "ALB 5XX", color = "#9467bd" }],
          ]
          yAxis = {
            left = { min = 0 }
          }
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 12
        height = 6
        properties = {
          title  = "ALB - Target Health & Response Latency"
          region = var.aws_region
          period = 60
          view   = "timeSeries"
          metrics = [
            ["AWS/ApplicationELB", "TargetResponseTime", "TargetGroup", var.target_group_arn_suffix, "LoadBalancer", var.alb_arn_suffix, { stat = "Average", label = "Latency Avg (s)", color = "#1f77b4" }],
            ["...", { stat = "p95", label = "Latency p95 (s)", color = "#ff7f0e" }],
            [".", "HealthyHostCount", "TargetGroup", var.target_group_arn_suffix, "LoadBalancer", var.alb_arn_suffix, { stat = "Minimum", yAxis = "right", label = "Healthy Hosts", color = "#2ca02c" }],
            [".", "UnHealthyHostCount", "TargetGroup", var.target_group_arn_suffix, "LoadBalancer", var.alb_arn_suffix, { stat = "Maximum", yAxis = "right", label = "Unhealthy Hosts", color = "#d62728" }],
          ]
          yAxis = {
            left  = { min = 0 }
            right = { min = 0 }
          }
        }
      },

      # Row 2: ASG Capacity & EC2 Compute
      {
        type   = "metric"
        x      = 0
        y      = 12
        width  = 12
        height = 6
        properties = {
          title  = "Auto Scaling Group - Instance Capacity"
          region = var.aws_region
          period = 60
          stat   = "Average"
          view   = "timeSeries"
          metrics = [
            ["AWS/AutoScaling", "GroupInServiceInstances", "AutoScalingGroupName", var.asg_name, { label = "In-Service", color = "#2ca02c" }],
            [".", "GroupDesiredCapacity", ".", ".", { label = "Desired", color = "#1f77b4" }],
            [".", "GroupPendingInstances", ".", ".", { label = "Pending", color = "#ff7f0e" }],
            [".", "GroupTerminatingInstances", ".", ".", { label = "Terminating", color = "#d62728" }],
          ]
          yAxis = {
            left = { min = 0 }
          }
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 12
        width  = 12
        height = 6
        properties = {
          title  = "EC2 ASG - CPU, Credits & Status Checks"
          region = var.aws_region
          period = 60
          view   = "timeSeries"
          metrics = [
            ["AWS/EC2", "CPUUtilization", "AutoScalingGroupName", var.asg_name, { stat = "Average", label = "CPU Avg %", color = "#1f77b4" }],
            ["...", { stat = "Maximum", label = "CPU Max %", color = "#ff7f0e" }],
            [".", "CPUCreditBalance", "AutoScalingGroupName", var.asg_name, { stat = "Minimum", yAxis = "right", label = "CPU Credit Balance", color = "#2ca02c" }],
            [".", "StatusCheckFailed", "AutoScalingGroupName", var.asg_name, { stat = "Maximum", yAxis = "right", label = "Status Check Failed", color = "#d62728" }],
          ]
          yAxis = {
            left  = { min = 0, max = 100 }
            right = { min = 0 }
          }
        }
      },

      # Row 3: CWAgent OS Metrics (Memory, Disk, Swap, TCP, Processes)
      {
        type   = "metric"
        x      = 0
        y      = 18
        width  = 12
        height = 6
        properties = {
          title  = "CWAgent - Memory, Root Disk & Swap Utilization"
          region = var.aws_region
          period = 60
          stat   = "Average"
          view   = "timeSeries"
          metrics = [
            ["CWAgent", "mem_used_percent", "AutoScalingGroupName", var.asg_name, { label = "Memory Used %", color = "#1f77b4" }],
            [".", "disk_used_percent", "AutoScalingGroupName", var.asg_name, "path", "/", { stat = "Maximum", label = "Root Disk / Used %", color = "#ff7f0e" }],
            [".", "swap_used_percent", "AutoScalingGroupName", var.asg_name, { label = "Swap Used %", color = "#9467bd" }],
          ]
          yAxis = {
            left = { min = 0, max = 100 }
          }
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 18
        width  = 12
        height = 6
        properties = {
          title  = "CWAgent - TCP Connections & OS Processes"
          region = var.aws_region
          period = 60
          stat   = "Average"
          view   = "timeSeries"
          metrics = [
            ["CWAgent", "netstat_tcp_established", "AutoScalingGroupName", var.asg_name, { label = "TCP Established", color = "#2ca02c" }],
            [".", "netstat_tcp_time_wait", ".", ".", { label = "TCP Time Wait", color = "#ff7f0e" }],
            [".", "processes_running", ".", ".", { yAxis = "right", label = "Processes Running", color = "#1f77b4" }],
            [".", "processes_zombies", ".", ".", { yAxis = "right", label = "Zombie Processes", color = "#d62728" }],
          ]
          yAxis = {
            left  = { min = 0 }
            right = { min = 0 }
          }
        }
      },

      # Row 4: Application & Network Log Metrics (+ NAT Gateway if enabled)
      {
        type   = "metric"
        x      = var.enable_nat_gateway_monitoring ? 12 : 0
        y      = 24
        width  = var.enable_nat_gateway_monitoring ? 12 : 24
        height = 6
        properties = {
          title  = "Application & Security Log Metrics"
          region = var.aws_region
          period = 60
          stat   = "Sum"
          view   = "timeSeries"
          metrics = concat(
            [
              [local.app_metric_namespace, "ApplicationErrorCount", { label = "App [ERROR] Logs", color = "#d62728" }],
              [".", "ApplicationWarningCount", { label = "App [WARN] Logs", color = "#ff7f0e" }],
              [".", "ApplicationPanicCount", { label = "App Panics", color = "#9467bd" }],
            ],
            var.enable_vpc_flow_logs ? [
              [local.network_metric_namespace, "VPCRejectedPacketCount", { yAxis = "right", label = "VPC Rejected Packets", color = "#8c564b" }],
            ] : [],
          )
          yAxis = {
            left  = { min = 0 }
            right = { min = 0 }
          }
        }
      },

      # Row 5: CloudWatch Logs Insights - Docker Application Logs
      {
        type   = "log"
        x      = 0
        y      = 30
        width  = var.enable_vpc_flow_logs ? 12 : 24
        height = 6
        properties = {
          title  = "Docker Application Logs - Recent Errors & Warnings"
          region = var.aws_region
          view   = "table"
          query  = "SOURCE '${aws_cloudwatch_log_group.docker.name}' | filter @message like /\\[ERROR\\]|\\[WARN\\]|Panic/ | fields @timestamp, @logStream, @message | sort @timestamp desc | limit 25"
        }
      },
    ],
    local.nat_gateway_widget,
    local.vpc_flow_log_widget,
  )
}

resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = local.dashboard_name

  dashboard_body = jsonencode({
    widgets = local.dashboard_widgets
  })
}
