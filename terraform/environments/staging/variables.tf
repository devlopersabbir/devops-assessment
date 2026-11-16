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
  description = "IPv4 CIDR block for the staging VPC"

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "vpc_cidr must be a valid IPv4 CIDR block (e.g., 10.1.0.0/16)."
  }
}

variable "public_subnet_cidrs" {
  type        = list(string)
  description = "List of CIDR blocks for public subnets in staging"
  default     = ["10.1.1.0/24"]
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

# ------------ AWS EC2 ----------- #
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

variable "allocate_eip" {
  description = "Allocate and attach a static Elastic IP to the staging EC2 instance"
  type        = bool
  default     = true
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
  description = "Enable detailed CloudWatch monitoring on the EC2 instance"
  type        = bool
  default     = false
}

variable "user_data" {
  description = "User data script to bootstrap the instance (e.g. install Docker, SSM)"
  type        = string
  default     = null
}
