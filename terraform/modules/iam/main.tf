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

resource "aws_iam_instance_profile" "server" {
  name = "${var.project_name}-${var.environment}-server-profile"
  role = aws_iam_role.server.name

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-server-profile"
  })
}
