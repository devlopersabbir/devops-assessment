variable "project_name" {
  type        = string
  description = "Project name prefix used for naming CloudWatch monitoring resources"
}

variable "environment" {
  type        = string
  description = "Deployment environment name (e.g., staging, prod)"
}

variable "aws_region" {
  type        = string
  description = "AWS region where the monitored infrastructure is deployed"
}

variable "vpc_id" {
  type        = string
  description = "VPC ID to monitor with VPC Flow Logs"
}

variable "nat_gateway_id" {
  type        = string
  description = "NAT Gateway ID to monitor"
  default     = ""
}

variable "enable_nat_gateway_monitoring" {
  type        = bool
  description = "Enable NAT Gateway alarms and dashboard widget"
  default     = true
}

variable "alb_arn_suffix" {
  type        = string
  description = "ARN suffix of the Application Load Balancer (e.g., app/name/id)"
}

variable "target_group_arn_suffix" {
  type        = string
  description = "ARN suffix of the ALB Target Group (e.g., targetgroup/name/id)"
}

variable "asg_name" {
  type        = string
  description = "Name of the Auto Scaling Group to monitor"
}

variable "asg_min_size" {
  type        = number
  description = "Minimum expected in-service instance count in the Auto Scaling Group"
  default     = 1
}

variable "instance_type" {
  type        = string
  description = "EC2 instance type used in the ASG (enables CPU credit alarms for burstable T-family instances)"
  default     = "t3.micro"
}

variable "agent_ssm_parameter_name" {
  type        = string
  description = "SSM Parameter Store name for the CloudWatch Agent JSON configuration (must start with AmazonCloudWatch- to match CloudWatchAgentServerPolicy)"
  default     = ""
}

variable "log_retention_days" {
  type        = number
  description = "Number of days to retain logs in CloudWatch Log Groups"
  default     = 30

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653], var.log_retention_days)
    error_message = "log_retention_days must be a valid non-zero CloudWatch Logs retention period."
  }
}

variable "kms_deletion_window_in_days" {
  type        = number
  description = "Waiting period (7-30 days) before AWS KMS deletes the monitoring CMK after destruction"
  default     = 7

  validation {
    condition     = var.kms_deletion_window_in_days >= 7 && var.kms_deletion_window_in_days <= 30
    error_message = "kms_deletion_window_in_days must be between 7 and 30."
  }
}

variable "enable_vpc_flow_logs" {
  type        = bool
  description = "Enable VPC Flow Logs delivery to CloudWatch Logs"
  default     = true
}

variable "vpc_flow_logs_traffic_type" {
  type        = string
  description = "Type of VPC traffic to capture in Flow Logs (ALL, ACCEPT, or REJECT)"
  default     = "ALL"

  validation {
    condition     = contains(["ALL", "ACCEPT", "REJECT"], var.vpc_flow_logs_traffic_type)
    error_message = "vpc_flow_logs_traffic_type must be one of: ALL, ACCEPT, REJECT."
  }
}

variable "enable_discord_notifications" {
  type        = bool
  description = "Deploy a Lambda forwarder subscribed to the SNS alert topic to send formatted embeds to Discord"
  default     = true
}

variable "discord_webhook_url" {
  type        = string
  description = "Discord webhook URL for CloudWatch alarm notifications"
  default     = ""
  sensitive   = true
}

variable "alert_emails" {
  type        = list(string)
  description = "Optional list of email addresses subscribed to the CloudWatch SNS alerts topic"
  default     = []
}

variable "cpu_high_threshold" {
  type        = number
  description = "EC2 ASG average CPU utilization percentage threshold for high CPU alarm"
  default     = 80
}

variable "memory_high_threshold" {
  type        = number
  description = "CWAgent memory used percentage threshold for high memory alarm"
  default     = 85
}

variable "disk_high_threshold" {
  type        = number
  description = "CWAgent root filesystem (/) disk used percentage threshold for high disk alarm"
  default     = 80
}

variable "swap_high_threshold" {
  type        = number
  description = "CWAgent swap used percentage threshold for high swap usage alarm"
  default     = 50
}

variable "cpu_credit_low_threshold" {
  type        = number
  description = "Minimum CPUCreditBalance threshold for burstable EC2 instances"
  default     = 15
}

variable "alb_5xx_threshold" {
  type        = number
  description = "Number of ALB or Target 5XX responses per minute to trigger an alarm"
  default     = 5
}

variable "alb_4xx_threshold" {
  type        = number
  description = "Number of Target 4XX responses over 5 minutes to trigger a client-error spike alarm"
  default     = 50
}

variable "alb_latency_p95_threshold_seconds" {
  type        = number
  description = "ALB p95 target response time threshold in seconds"
  default     = 1.0
}

variable "app_error_log_threshold" {
  type        = number
  description = "Number of [ERROR] lines in Docker container logs over 5 minutes to trigger an alarm"
  default     = 5
}

variable "vpc_rejected_packet_threshold" {
  type        = number
  description = "Number of REJECT entries in VPC Flow Logs over 5 minutes to trigger a network alarm"
  default     = 500
}

variable "tags" {
  type        = map(string)
  description = "Additional tags to attach to monitoring resources"
  default     = {}
}
