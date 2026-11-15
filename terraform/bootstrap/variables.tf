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
  description = "Project prefix identifier for naming state storage resources"
}

variable "environments" {
  type        = list(string)
  description = "List of environments to provision remote state"
  default     = ["staging", "prod"]
}

variable "tags" {
  type        = map(string)
  description = "Custom tags to attach to bootstrap state storage resources"
  default     = {}
}
