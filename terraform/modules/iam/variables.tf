variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Deployment environment (e.g. dev, staging, prod)"
  type        = string
}

variable "enable_cloudwatch_agent" {
  description = "Attach CloudWatchAgentServerPolicy so EC2 instances can push metrics and logs to CloudWatch"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Common resource tags"
  type        = map(string)
  default     = {}
}

