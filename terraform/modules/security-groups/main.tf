# 1. Application Load Balancer Security Group (Public HTTP Ingress -> EC2 8080 Egress)
resource "aws_security_group" "alb" {
  name        = "${var.project_name}-${var.environment}-alb-sg"
  description = "Security group for internet-facing Application Load Balancer"
  vpc_id      = var.vpc_id

  # Inbound HTTP (80) from internet users
  # trivy:ignore:AVD-AWS-0107 -- Internet-facing ALB must accept public HTTP traffic on port 80
  ingress {
    description = "Allow public inbound HTTP traffic to ALB"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Outbound HTTP (8080) to backend EC2 Docker container
  # trivy:ignore:AVD-AWS-0104 -- Allow ALB to forward traffic and health checks to target instances on port 8080
  egress {
    description = "Allow ALB outbound HTTP traffic to EC2 container port 8080"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name        = "${var.project_name}-${var.environment}-alb-sg"
    Environment = var.environment
  })
}

# 2. Private EC2 Server Security Group (Only accepts port 8080 from ALB)
resource "aws_security_group" "server" {
  name        = "${var.project_name}-${var.environment}-server-sg"
  description = "Security group for EC2 instance running API docker container"
  vpc_id      = var.vpc_id

  # Inbound port 8080 strictly from the Application Load Balancer Security Group
  ingress {
    description     = "Allow inbound container traffic on 8080 strictly from the ALB security group"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

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
    Name        = "${var.project_name}-${var.environment}-server-sg"
    Environment = var.environment
  })
}
