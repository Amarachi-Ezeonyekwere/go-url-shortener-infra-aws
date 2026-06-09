output "vpc_id" {
  description = "The ID of the main VPC. Downstream resources will use this to build security groups."
  value       = aws_vpc.main.id
}

output "public_subnet_id" {
  description = "The ID of the public subnet."
  value       = aws_subnet.main.id
}

output "vpc_cidr_block" {
  description = "The internal IP range of the VPC. Useful for configuring firewall/security group rules later."
  value       = aws_vpc.main.cidr_block
}