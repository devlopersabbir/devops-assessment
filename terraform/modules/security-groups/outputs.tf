output "security_group_id" {
  description = "ID of the EC2 server security group"
  value       = aws_security_group.server.id
}

output "alb_security_group_id" {
  description = "ID of the Application Load Balancer security group"
  value       = aws_security_group.alb.id
}
