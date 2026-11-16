# Local Variable
locals {
  ec2_bootstrap_user_data = join("\n", compact([
    replace(file("${path.module}/../../scripts/install-ssm-agent.sh"), "\r\n", "\n"),
    replace(file("${path.module}/../../scripts/initialize-server.sh"), "\r\n", "\n"),
  ]))
}

# 1. Custom VPC (Simple Public Subnet + Internet Gateway, No NAT Gateway)
module "vpc" {
  source = "../../modules/vpc"

  project_name         = var.project_name
  environment          = var.environment
  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = []
  enable_nat_gateway   = false
}

# 2. Security Groups Module (Direct Public EC2 Server SG, No ALB)
module "security_groups" {
  source = "../../modules/security-groups"

  project_name = var.project_name
  environment  = var.environment
  vpc_id       = module.vpc.vpc_id
  enable_alb   = false
}

# 3. IAM Roles & Instance Profiles (SSM Session Manager Only, No CloudWatch Agent)
module "iam" {
  source = "../../modules/iam"

  project_name            = var.project_name
  environment             = var.environment
  enable_cloudwatch_agent = false
}

# 4. Single EC2 Instance with Static Public Elastic IP (Public Subnet)
module "ec2" {
  source = "../../modules/ec2"

  instance_name        = var.instance_name
  ami_id               = var.ami_id
  instance_type        = var.instance_type
  subnet_id            = module.vpc.public_subnet_ids[0]
  security_group_ids   = [module.security_groups.security_group_id]
  iam_instance_profile = module.iam.instance_profile_name
  key_name             = var.key_name
  allocate_eip         = var.allocate_eip
  root_volume_size     = var.root_volume_size
  root_volume_type     = var.root_volume_type
  enable_monitoring    = var.enable_monitoring
  user_data            = local.ec2_bootstrap_user_data
  tags                 = var.tags

  depends_on = [
    module.vpc,
    module.iam,
    module.security_groups,
  ]
}
