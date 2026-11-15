resource "aws_instance" "this" {
  # Use a manually pinned AMI based on user provided variable or the latest AMI from the data source.
  ami           = var.ami_id != "" ? var.ami_id : data.aws_ami.debian.id
  instance_type = var.instance_type
  subnet_id     = var.subnet_id

  # Network and access configuration
  vpc_security_group_ids = var.security_group_ids
  iam_instance_profile   = var.iam_instance_profile
  key_name               = var.key_name

  # Bootstrap configuration
  user_data = var.user_data
  # Replace EC2 when bootstrap configuration changes.
  user_data_replace_on_change = true

  # AWS detailed monitoring (additional cost).
  monitoring = var.enable_monitoring

  # Enforce IMDSv2.
  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"

    # Use 1 by default. Use 2 if containerized workloads
    # need to access EC2 instance metadata.
    http_put_response_hop_limit = 2

    instance_metadata_tags = "enabled"
  }
  # Encrypted root EBS volume.
  root_block_device {
    volume_size           = var.root_volume_size
    volume_type           = var.root_volume_type
    encrypted             = true
    delete_on_termination = true

    tags = merge(var.tags, {
      Name = "${var.instance_name}-root-vol"
    })
  }

  # Instance tags.
  tags = merge(var.tags, {
    Name = var.instance_name
  })

  lifecycle {
    # Create replacement before destroying the existing instance..
    create_before_destroy = true
  }
}
