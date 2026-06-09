variable "instance_type" {
  description = "Type of Instance used"
  type        = string
}

variable "subnet_id" {
  description = "subnet ID of the instance"
  type        = string
}

variable "security_group_id" {
  description = "security group ID for the instance"
  type        = string
}

variable "ec2_instance_profile_name" {
  description = "profile name for the instance"
  type        = string
}

variable "aws_region" {
  description = "region for aws resources"
  type        = string
}

variable "ecr_repository_url" {
  description = "ecr repositiory url"
  type        = string
}

variable "key_name" {
  description = "AWS key pair name for SSH access to EC2"
  type        = string
}