# ------------ Common ----------- #
variable "aws_region" {
  type        = string
  description = "AWS deployment region for remote state storage"
}

variable "aws_profile" {
  type        = string
  description = "AWS CLI named profile to use (leave empty for default / STS session credentials)"
  default     = ""
}

variable "project_name" {
  type        = string
  description = "Project name prefix used for naming the VPC"
}

variable "environment" {
  type        = string
  description = "Deployment environment name (e.g., staging, prod)"
}

# ------------ AWS VPC ----------- #
variable "vpc_cidr" {
  type        = string
  description = "IPv4 CIDR block for the VPC"

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "vpc_cidr must be a valid IPv4 CIDR block (e.g., 10.0.0.0/16)."
  }
}

variable "public_subnet_cidrs" {
  type        = list(string)
  description = "List of CIDR blocks for public subnets (NAT Gateway, ALB)"
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  type        = list(string)
  description = "List of CIDR blocks for private subnets across Availability Zones"
  default     = ["10.0.10.0/24", "10.0.11.0/24"]
}

variable "enable_dns_support" {
  type        = bool
  description = "Whether to enable DNS resolution support in the VPC"
  default     = true
}

variable "enable_dns_hostnames" {
  type        = bool
  description = "Whether to enable DNS hostnames in the VPC"
  default     = true
}

variable "tags" {
  type        = map(string)
  description = "Additional tags to attach to resources"
  default     = {}
}

# ------------ AWS ASG / EC2 ----------- #
variable "instance_name" {
  description = "Name tag of the EC2 instance"
  type        = string
  default     = "devops-assessment-staging-ec2"
}

variable "ami_id" {
  description = "AMI ID to use for the instance. If empty, defaults to Debian AMI"
  type        = string
  default     = ""
}

variable "instance_type" {
  description = "Type of EC2 instance to launch"
  type        = string
  default     = "t3.micro"
}

variable "key_name" {
  description = "AWS key pair name for SSH access (optional; SSM Session Manager is preferred)"
  type        = string
  default     = null
}

variable "root_volume_size" {
  description = "Root volume size in GB"
  type        = number
  default     = 20
}

variable "root_volume_type" {
  description = "Root volume EBS type (e.g. gp3)"
  type        = string
  default     = "gp3"
}

variable "enable_monitoring" {
  description = "Enable detailed 1-minute CloudWatch monitoring on EC2 instances"
  type        = bool
  default     = true
}

variable "user_data" {
  description = "User data script to bootstrap the instance (e.g. install Docker, SSM)"
  type        = string
  default     = null
}

variable "asg_min_size" {
  description = "Minimum number of instances in the Auto Scaling Group"
  type        = number
  default     = 1
}

variable "asg_max_size" {
  description = "Maximum number of instances in the Auto Scaling Group"
  type        = number
  default     = 3
}

variable "asg_desired_capacity" {
  description = "Desired number of instances in the Auto Scaling Group"
  type        = number
  default     = 2
}

# ------------ AWS CloudWatch Monitoring ----------- #
variable "enable_cloudwatch_agent" {
  description = "Install and configure CloudWatch Agent on EC2 instances for OS and Docker log/metric collection"
  type        = bool
  default     = true
}

variable "log_retention_days" {
  description = "Number of days to retain logs in CloudWatch Log Groups"
  type        = number
  default     = 30
}

variable "kms_deletion_window_in_days" {
  description = "Waiting period in days before KMS deletes the monitoring CMK upon destruction"
  type        = number
  default     = 7
}

variable "enable_vpc_flow_logs" {
  description = "Enable VPC Flow Logs shipping to CloudWatch Logs"
  type        = bool
  default     = true
}

variable "enable_discord_notifications" {
  description = "Deploy Lambda forwarder to send CloudWatch Alarm notifications to Discord"
  type        = bool
  default     = true
}

variable "discord_webhook_url" {
  description = "Discord webhook URL for CloudWatch alarm notifications (set via tfvars or TF_VAR_discord_webhook_url)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "alert_emails" {
  description = "Optional list of email addresses to subscribe to CloudWatch Alarm SNS notifications"
  type        = list(string)
  default     = []
}
