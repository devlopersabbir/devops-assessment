variable "project_name" {
  type        = string
  description = "Project name prefix used for naming ASG resources"
}

variable "environment" {
  type        = string
  description = "Deployment environment name (e.g., staging, prod)"
}

variable "ami_id" {
  type        = string
  description = "AMI ID to use for instances. If empty, defaults to latest Debian AMI"
  default     = ""
}

variable "instance_type" {
  type        = string
  description = "EC2 instance type for the Launch Template"
  default     = "t3.micro"
}

variable "private_subnet_ids" {
  type        = list(string)
  description = "List of Private Subnet IDs across Availability Zones for the ASG"
}

variable "security_group_ids" {
  type        = list(string)
  description = "List of Security Group IDs to attach to the EC2 instances"
}

variable "iam_instance_profile" {
  type        = string
  description = "IAM Instance Profile name to attach to the EC2 instances"
  default     = null
}

variable "target_group_arns" {
  type        = list(string)
  description = "List of ALB Target Group ARNs to attach to the Auto Scaling Group"
  default     = []
}

variable "key_name" {
  type        = string
  description = "Optional AWS key pair name (SSM Session Manager is preferred)"
  default     = null
}

variable "root_volume_size" {
  type        = number
  description = "Root EBS volume size in GB"
  default     = 20
}

variable "root_volume_type" {
  type        = string
  description = "Root EBS volume type (e.g., gp3)"
  default     = "gp3"
}

variable "enable_monitoring" {
  type        = bool
  description = "Enable detailed CloudWatch monitoring on instances"
  default     = false
}

variable "user_data" {
  type        = string
  description = "Plaintext user data script (automatically base64-encoded for Launch Template)"
  default     = null
}

variable "min_size" {
  type        = number
  description = "Minimum number of instances in the Auto Scaling Group"
  default     = 1
}

variable "max_size" {
  type        = number
  description = "Maximum number of instances in the Auto Scaling Group"
  default     = 3
}

variable "desired_capacity" {
  type        = number
  description = "Desired number of instances in the Auto Scaling Group"
  default     = 2
}

variable "health_check_type" {
  type        = string
  description = "Health check type for the ASG (EC2 or ELB)"
  default     = "EC2"
}

variable "cpu_target_value" {
  type        = number
  description = "Target average CPU utilization percentage for auto-scaling"
  default     = 70
}

variable "enabled_metrics" {
  type        = list(string)
  description = "List of Auto Scaling Group metrics to collect in CloudWatch"
  default = [
    "GroupMinSize",
    "GroupMaxSize",
    "GroupDesiredCapacity",
    "GroupInServiceInstances",
    "GroupPendingInstances",
    "GroupStandbyInstances",
    "GroupTerminatingInstances",
    "GroupTotalInstances",
  ]
}

variable "metrics_granularity" {
  type        = string
  description = "Granularity at which Auto Scaling Group metrics are collected"
  default     = "1Minute"
}

variable "tags" {
  type        = map(string)
  description = "Additional tags to attach to ASG resources"
  default     = {}
}
