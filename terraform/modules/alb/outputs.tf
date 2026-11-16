output "alb_id" {
  description = "The ID of the Application Load Balancer"
  value       = aws_lb.this.id
}

output "alb_arn" {
  description = "The ARN of the Application Load Balancer"
  value       = aws_lb.this.arn
}

output "alb_arn_suffix" {
  description = "The ARN suffix of the Application Load Balancer for CloudWatch metrics"
  value       = aws_lb.this.arn_suffix
}

output "alb_name" {
  description = "The name of the Application Load Balancer"
  value       = aws_lb.this.name
}

output "alb_dns_name" {
  description = "The public DNS name of the Application Load Balancer"
  value       = aws_lb.this.dns_name
}

output "target_group_arn" {
  description = "The ARN of the ALB Target Group"
  value       = aws_lb_target_group.this.arn
}

output "target_group_arn_suffix" {
  description = "The ARN suffix of the ALB Target Group for CloudWatch metrics"
  value       = aws_lb_target_group.this.arn_suffix
}

output "target_group_name" {
  description = "The name of the ALB Target Group"
  value       = aws_lb_target_group.this.name
}
