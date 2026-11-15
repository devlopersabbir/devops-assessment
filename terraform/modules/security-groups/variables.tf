variable "project_name" {
  type        = string
  description = "Project name prefix used for naming the VPC"
}

variable "environment" {
  type        = string
  description = "Deployment environment name (e.g., staging, prod)"
}


variable "vpc_id" {
  description = "VPC ID where the security groups will be created"
  type        = string
}

variable "tags" {
  description = "Common resource tags"
  type        = map(string)
  default     = {}
}