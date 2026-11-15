output "instance_profile_name" {
  description = "Name of the Backend IAM instance profile"
  value       = aws_iam_instance_profile.server.name
}

output "instance_profile_arn" {
  description = "ARN of the Backend IAM instance profile"
  value       = aws_iam_instance_profile.server.arn
}