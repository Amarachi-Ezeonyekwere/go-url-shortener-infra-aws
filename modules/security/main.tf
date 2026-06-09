resource "aws_security_group" "main" {
  name        = "security_group"
  description = "security group for the VPC"
  vpc_id      = aws_vpc.main.id
  tags = {
    Name = "main"
  }
}

resource "aws_vpc_security_group_ingress_rule" "main" {
  security_group_id = aws_security_group.main.id

  cidr_ipv4   = var.cidr_ipv4_ingress_security_group
  from_port   = 80
  ip_protocol = "tcp"
  to_port     = 80
}

resource "aws_vpc_security_group_egress_rule" "main" {
  security_group_id = aws_security_group.main.id

  cidr_ipv4   = var.cidr_ipv4_egress_security_group
  ip_protocol = "-1"
}