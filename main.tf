terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.49.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Networking

module "networking" {
    source = "./modules/networking"

    vpc_cidr = var.vpc_cidr
    public_subnet_cidr = var.public_subnet_cidr
    availability_zone = var.availability_zone
}

# Security

module "security" {
    source = "./modules/security"
    vpc_id = module.networking.vpc_id
}

# IAM 

module "iam" {
    source = "./modules/iam"
    aws_region = var.aws_region
}

module "compute" {
    source = "./module/compute"

  instance_type             = var.instance_type
  key_name                  = var.key_name
  ecr_repository_url        = var.ecr_repository_url
  aws_region                = var.aws_region
  subnet_id                 = module.networking.public_subnet_id   
  security_group_id         = module.security.ec2_sg_id            
  ec2_instance_profile_name = module.iam.ec2_instance_profile_name 
}