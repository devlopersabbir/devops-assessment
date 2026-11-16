terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0, < 7.0"
    }
  }

  # Backend - S3 State (Terraform does not allow variables inside backend blocks)
  backend "s3" {
    bucket       = "devops-assessment-staging-tfstate-1"
    key          = "staging/terraform.tfstate"
    region       = "ap-south-1"
    profile      = "devops"
    encrypt      = true
    use_lockfile = true
  }
}
