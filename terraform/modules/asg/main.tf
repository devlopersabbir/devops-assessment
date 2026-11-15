# 1. EC2 Launch Template
resource "aws_launch_template" "this" {
  name_prefix            = "${var.project_name}-${var.environment}-lt-"
  image_id               = var.ami_id != "" ? var.ami_id : data.aws_ami.debian.id
  instance_type          = var.instance_type
  key_name               = var.key_name
  vpc_security_group_ids = var.security_group_ids
  user_data              = var.user_data != null ? base64encode(var.user_data) : null
  update_default_version = true

  dynamic "iam_instance_profile" {
    for_each = var.iam_instance_profile != null ? [var.iam_instance_profile] : []
    content {
      name = iam_instance_profile.value
    }
  }

  monitoring {
    enabled = var.enable_monitoring
  }

  # Enforce IMDSv2 for security
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
    instance_metadata_tags      = "enabled"
  }

  # Encrypted Root EBS Volume
  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size           = var.root_volume_size
      volume_type           = var.root_volume_type
      encrypted             = true
      delete_on_termination = true
    }
  }

  tag_specifications {
    resource_type = "instance"
    tags = merge(var.tags, {
      Name        = "${var.project_name}-${var.environment}-server"
      Environment = var.environment
    })
  }

  tag_specifications {
    resource_type = "volume"
    tags = merge(var.tags, {
      Name        = "${var.project_name}-${var.environment}-server-vol"
      Environment = var.environment
    })
  }

  tags = merge(var.tags, {
    Name        = "${var.project_name}-${var.environment}-lt"
    Environment = var.environment
  })

  lifecycle {
    create_before_destroy = true
  }
}

# 2. Auto Scaling Group across Private Subnets
resource "aws_autoscaling_group" "this" {
  name                      = "${var.project_name}-${var.environment}-asg"
  vpc_zone_identifier       = var.private_subnet_ids
  target_group_arns         = var.target_group_arns
  health_check_type         = var.health_check_type
  health_check_grace_period = 300

  min_size            = var.min_size
  max_size            = var.max_size
  desired_capacity    = var.desired_capacity
  enabled_metrics     = var.enabled_metrics
  metrics_granularity = var.metrics_granularity

  launch_template {
    id      = aws_launch_template.this.id
    version = "$Latest"
  }

  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
    }
  }

  tag {
    key                 = "Name"
    value               = "${var.project_name}-${var.environment}-server"
    propagate_at_launch = true
  }

  tag {
    key                 = "Environment"
    value               = var.environment
    propagate_at_launch = true
  }

  # Allow the CPU target-tracking policy to manage desired_capacity without Terraform reverting it
  lifecycle {
    ignore_changes = [desired_capacity]
  }
}

# 3. CPU Target Tracking Auto Scaling Policy
resource "aws_autoscaling_policy" "cpu_target_tracking" {
  name                   = "${var.project_name}-${var.environment}-cpu-target-tracking"
  autoscaling_group_name = aws_autoscaling_group.this.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = var.cpu_target_value
  }
}
