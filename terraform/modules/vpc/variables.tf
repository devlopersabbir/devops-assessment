variable "project_name" {
  type        = string
  description = "Project name prefix used for naming the VPC"
}

variable "environment" {
  type        = string
  description = "Deployment environment name (e.g., staging, prod)"
}

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
  description = "List of CIDR blocks for private subnets"
  default     = ["10.0.10.0/24"]
}

variable "azs" {
  type        = list(string)
  description = "List of Availability Zones to deploy subnets into (defaults to available AZs in the current region)"
  default     = []
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
  description = "Additional tags to attach to the VPC"
  default     = {}
}
