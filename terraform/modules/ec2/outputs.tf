output "instance_id" {
  description = "The ID of the EC2 instance"
  value       = aws_instance.this.id
}

output "arn" {
  description = "The ARN of the EC2 instance"
  value       = aws_instance.this.arn
}

output "private_ip" {
  description = "The private IP address of the EC2 instance"
  value       = aws_instance.this.private_ip
}

output "public_ip" {
  description = "The public IP address of the EC2 instance (Elastic IP if allocated)"
  value       = var.allocate_eip ? aws_eip.this[0].public_ip : aws_instance.this.public_ip
}

output "elastic_ip_allocation_id" {
  description = "The allocation ID of the Elastic IP attached to the EC2 instance"
  value       = var.allocate_eip ? aws_eip.this[0].id : null
}

output "instance_name" {
  description = "The name of the EC2 instance"
  value       = var.instance_name
}
