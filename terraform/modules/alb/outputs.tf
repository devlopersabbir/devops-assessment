output "alb_id" {
  description = "The ID of the Application Load Balancer"
  value       = aws_lb.this.id
}

output "alb_arn" {
  description = "The ARN of the Application Load Balancer"
  value       = aws_lb.this.arn
}

output "alb_dns_name" {
  description = "The public DNS name of the Application Load Balancer"
  value       = aws_lb.this.dns_name
}

output "target_group_arn" {
  description = "The ARN of the ALB Target Group"
  value       = aws_lb_target_group.this.arn
}
