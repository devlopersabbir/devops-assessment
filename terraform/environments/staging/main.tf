# Local Variable
locals {
  name_prefix = "${var.project_name}-${var.environment}"
  ec2_bootstrap_user_data = join("\n", [
    replace(file("${path.module}/../../scripts/ec2-user-data.sh"), "\r\n", "\n"),
    replace(file("${path.module}/../../scripts/initialize-server.sh"), "\r\n", "\n"),
  ])
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

  depends_on = [
    module.vpc,
    module.iam,
    module.security_groups,
  ]
}
