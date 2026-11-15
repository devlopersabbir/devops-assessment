data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "server" {
  name               = "${var.project_name}-${var.environment}-server-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-server-role"
  })
}

# Attach AWS-managed policy for SSM Session Manager access (no SSH/bastion required)
resource "aws_iam_role_policy_attachment" "ssm_managed_instance_core" {
  role       = aws_iam_role.server.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Attach AWS-managed policy for CloudWatch Agent metrics, logs, and SSM parameter config
resource "aws_iam_role_policy_attachment" "cloudwatch_agent_server" {
  count = var.enable_cloudwatch_agent ? 1 : 0

  role       = aws_iam_role.server.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_instance_profile" "server" {
  name = "${var.project_name}-${var.environment}-server-profile"
  role = aws_iam_role.server.name

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-server-profile"
  })
}
