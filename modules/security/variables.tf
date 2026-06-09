variable "cidr_ipv4_ingress_security_group" {
    type = string
    description = "The IPv4 CIDR block permitted to access resources via HTTP (Port 80)"
}

variable "cidr_ipv4_egress_security_group" {
    type = string
    description = "Allow all outboud traffic"
}