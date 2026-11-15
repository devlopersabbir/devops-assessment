# Local Variable
locals {
  name_prefix = "${var.project_name}-${var.environment}"
  ec2_bootstrap_user_data = join("\n", [
    replace(file("${path.module}/../../scripts/ec2-user-data.sh"), "\r\n", "\n"),
    replace(file("${path.module}/../../scripts/initialize-server.sh"), "\r\n", "\n"),
  ])
}

# 1. Custom VPC (Multi-AZ Public & Private Subnets + NAT Gateway)
module "vpc" {
  source = "../../modules/vpc"

  project_name         = var.project_name
  environment          = var.environment
  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
}

# 2. Security Groups Module (ALB SG + Private EC2 Server SG)
module "security_groups" {
  source = "../../modules/security-groups"

  project_name = var.project_name
  environment  = var.environment
  vpc_id       = module.vpc.vpc_id
}

# 3. IAM Roles & Instance Profiles (SSM Session Manager)
module "iam" {
  source = "../../modules/iam"

  project_name = var.project_name
  environment  = var.environment
}

# 4. Application Load Balancer Module (Public Subnets)
module "alb" {
  source = "../../modules/alb"

  project_name          = var.project_name
  environment           = var.environment
  vpc_id                = module.vpc.vpc_id
  public_subnet_ids     = module.vpc.public_subnet_ids
  alb_security_group_id = module.security_groups.alb_security_group_id
}

# 5. Auto Scaling Group Module (Private Subnets across Availability Zones)
module "asg" {
  source = "../../modules/asg"

  project_name         = var.project_name
  environment          = var.environment
  ami_id               = var.ami_id
  instance_type        = var.instance_type
  private_subnet_ids   = module.vpc.private_subnet_ids
  security_group_ids   = [module.security_groups.security_group_id]
  iam_instance_profile = module.iam.instance_profile_name
  target_group_arns    = [module.alb.target_group_arn]
  key_name             = var.key_name
  root_volume_size     = var.root_volume_size
  root_volume_type     = var.root_volume_type
  enable_monitoring    = var.enable_monitoring
  user_data            = local.ec2_bootstrap_user_data

  min_size         = var.asg_min_size
  max_size         = var.asg_max_size
  desired_capacity = var.asg_desired_capacity

  depends_on = [
    module.vpc,
    module.iam,
    module.security_groups,
    module.alb,
  ]
}
