variables "cidr_block" {
    type = string
    description = "the CIDR block of the VPC"
}
variables "public_subnet_cidr" {
    type = string
    description = "the CIDR block for the subnet"
}
variables "availability_zone" {
    type =  string
    description = "the availability zone for the subnet"
}