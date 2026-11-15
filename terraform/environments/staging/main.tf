# Local Variable
locals {
  name_prefix                 = "${var.project_name}-${var.environment}"
  cw_agent_ssm_parameter_name = "AmazonCloudWatch-${local.name_prefix}-agent-config"
  ec2_bootstrap_user_data = join("\n", compact([
    replace(file("${path.module}/../../scripts/ec2-user-data.sh"), "\r\n", "\n"),
    replace(file("${path.module}/../../scripts/initialize-server.sh"), "\r\n", "\n"),
    var.enable_cloudwatch_agent ? "export CW_AGENT_SSM_PARAM='${local.cw_agent_ssm_parameter_name}'" : "",
    var.enable_cloudwatch_agent ? replace(file("${path.module}/../../scripts/install-cloudwatch-agent.sh"), "\r\n", "\n") : "",
  ]))
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

# 3. IAM Roles & Instance Profiles (SSM Session Manager + CloudWatch Agent)
module "iam" {
  source = "../../modules/iam"

  project_name            = var.project_name
  environment             = var.environment
  enable_cloudwatch_agent = var.enable_cloudwatch_agent
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

# 6. CloudWatch Monitoring Module (Dashboard, Alarms, Logs, VPC Flow Logs, KMS, SNS -> Discord)
module "cloudwatch" {
  source = "../../modules/cloudwatch"

  project_name                 = var.project_name
  environment                  = var.environment
  aws_region                   = var.aws_region
  vpc_id                       = module.vpc.vpc_id
  nat_gateway_id               = module.vpc.nat_gateway_id
  alb_arn_suffix               = module.alb.alb_arn_suffix
  target_group_arn_suffix      = module.alb.target_group_arn_suffix
  asg_name                     = module.asg.asg_name
  asg_min_size                 = var.asg_min_size
  instance_type                = var.instance_type
  agent_ssm_parameter_name     = local.cw_agent_ssm_parameter_name
  log_retention_days           = var.log_retention_days
  kms_deletion_window_in_days  = var.kms_deletion_window_in_days
  enable_vpc_flow_logs         = var.enable_vpc_flow_logs
  enable_discord_notifications = var.enable_discord_notifications
  discord_webhook_url          = var.discord_webhook_url
  alert_emails                 = var.alert_emails
  tags                         = var.tags

  depends_on = [
    module.vpc,
    module.alb,
    module.asg,
  ]
}
