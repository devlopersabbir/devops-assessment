resource "aws_security_group" "server" {
  name        = "${var.project_name}-${var.environment}-server-sg"
  description = "Security group for EC2 instance running API docker container"
  vpc_id      = var.vpc_id

  # Outbound HTTPS (443) for AWS SSM Session Manager, package updates, and container registry pulls
  # trivy:ignore:AVD-AWS-0104 -- Outbound HTTPS via NAT Gateway is required for SSM Session Manager and OS/Docker updates
  egress {
    description = "Allow outbound HTTPS traffic for SSM Session Manager and package updates"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Outbound HTTP (80) for Debian apt repository mirrors
  # trivy:ignore:AVD-AWS-0104 -- Outbound HTTP via NAT Gateway is required for Debian apt package mirrors
  egress {
    description = "Allow outbound HTTP traffic for Debian apt package mirrors"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-server-sg"
  })
}
