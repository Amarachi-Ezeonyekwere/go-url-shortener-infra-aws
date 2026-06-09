variable "cidr_block" {
  type        = string
  description = "the CIDR block of the VPC"
}
variable "public_subnet_cidr" {
  type        = string
  description = "the CIDR block for the subnet"
}
variable "availability_zone" {
  type        = string
  description = "the availability zone for the subnet"
}