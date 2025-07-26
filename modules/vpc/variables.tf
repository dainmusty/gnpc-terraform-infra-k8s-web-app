variable "ResourcePrefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
}

variable "enable_dns_hostnames" {
  description = "Enable DNS hostnames for the VPC"
  type        = bool
}

variable "enable_dns_support" {
  description = "Enable DNS support for the VPC"
  type        = bool
}

variable "instance_tenancy" {
  description = "Instance tenancy for the VPC"
  type        = string
}

variable "public_subnet_cidr" {
  description = "List of CIDR blocks for public subnets"
  type        = list(string)
}

variable "private_subnet_cidr" {
  description = "List of CIDR blocks for private subnets"
  type        = list(string)
}

variable "public_ip_on_launch" {
  description = "Enable public IP on launch for public subnets"
  type        = bool
}

variable "PublicRT_cidr" {
  description = "CIDR block for the public route table"
  type        = string
}

variable "PrivateRT_cidr" {
  description = "CIDR block for the private route table"
  type        = string
  
}
variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "eip_associate_with_private_ip" {
  description = "Associate Elastic IP with private IP"
  type        = bool
}