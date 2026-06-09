variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
}

variable "public_subnet_cidr" {
  description = "CIDR block for the public subnet"
  type        = string
}

variable "availability_zone" {
  description = "AZ for the subnet and EC2 instance"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t2.micro"
}

variable "key_name" {
  description = "AWS key pair name for SSH access"
  type        = string
}

variable "ecr_repository_url" {
  description = "Full ECR repository URL"
  type        = string
}

variable "cidr_ipv4_ingress_security_group" {
  type        = string
  description = "The CIDR block allowed for ingress traffic"
}

variable "cidr_ipv4_egress_security_group" {
  type        = string
  description = "The CIDR block allowed for egress traffic"
}