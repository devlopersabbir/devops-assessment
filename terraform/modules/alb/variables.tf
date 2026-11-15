variable "project_name" {
  type        = string
  description = "Project name prefix used for naming ALB resources"
}

variable "environment" {
  type        = string
  description = "Deployment environment name (e.g., staging, prod)"
}

variable "vpc_id" {
  type        = string
  description = "VPC ID where the Target Group will be created"
}

variable "public_subnet_ids" {
  type        = list(string)
  description = "List of Public Subnet IDs (at least 2 across different AZs) for the ALB"
}

variable "alb_security_group_id" {
  type        = string
  description = "Security Group ID attached to the Application Load Balancer"
}

variable "target_instance_id" {
  type        = string
  description = "EC2 Instance ID to register with the ALB Target Group"
}

variable "target_port" {
  type        = number
  description = "Port on the EC2 instance receiving traffic from the ALB (Caddy listens on 80)"
  default     = 80
}

variable "health_check_path" {
  type        = string
  description = "HTTP path used by the ALB Target Group health check"
  default     = "/health"
}

variable "tags" {
  type        = map(string)
  description = "Additional tags to attach to ALB resources"
  default     = {}
}
