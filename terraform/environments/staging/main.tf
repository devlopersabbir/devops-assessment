# Local Variable
locals {
  name_prefix = "${var.project_name}-${var.environment}"

  # User data: Ensure AWS SSM Agent is installed and running on Debian 12/13
  ec2_bootstrap_user_data = <<-EOF
    #!/bin/bash
    set -euxo pipefail

    if ! systemctl is-active --quiet amazon-ssm-agent; then
      apt-get update -y
      apt-get install -y curl wget
      ARCH="$(dpkg --print-architecture)"
      curl -fsSL "https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/debian_$${ARCH}/amazon-ssm-agent.deb" -o /tmp/amazon-ssm-agent.deb
      dpkg -i /tmp/amazon-ssm-agent.deb
      rm -f /tmp/amazon-ssm-agent.deb
      systemctl enable --now amazon-ssm-agent
    fi
  EOF
}

# custom vpc
module "vpc" {
  source = "../../modules/vpc"

  project_name         = var.project_name
  environment          = var.environment
  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
}

# Security Groups Module
module "security_groups" {
  source = "../../modules/security-groups"

  project_name = var.project_name
  environment  = var.environment
  vpc_id       = module.vpc.vpc_id
}

# IAM Roles, Instance Profiles
module "iam" {
  source = "../../modules/iam"

  project_name = var.project_name
  environment  = var.environment
}

# ec2 instance
module "ec2" {
  source = "../../modules/ec2"

  instance_name        = "${local.name_prefix}-server"
  ami_id               = var.ami_id
  instance_type        = var.instance_type
  subnet_id            = module.vpc.private_subnet_ids[0]
  security_group_ids   = [module.security_groups.security_group_id]
  iam_instance_profile = module.iam.instance_profile_name
  key_name             = var.key_name
  root_volume_size     = var.root_volume_size
  user_data            = local.ec2_bootstrap_user_data
}
