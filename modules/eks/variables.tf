# EKS Cluster Variables
variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "kube_version" {
  description = "Kubernetes version for the EKS cluster"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
}

variable "availability_zone_1" {
  description = "First availability zone"
  type        = string
}

variable "availability_zone_2" {
  description = "Second availability zone"
  type        = string
}

variable "availability_zone_3" {
  description = "Third availability zone"
  type        = string
  default     = ""
}

variable "availability_zone_4" {
  description = "Fourth availability zone"
  type        = string
  default     = ""
}

variable "public_subnet_1_cidr" {
  description = "CIDR block for public subnet 1"
  type        = string
}

variable "public_subnet_2_cidr" {
  description = "CIDR block for public subnet 2"
  type        = string
}

variable "private_subnet_1_cidr" {
  description = "CIDR block for private subnet 1"
  type        = string
}

variable "private_subnet_2_cidr" {
  description = "CIDR block for private subnet 2"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
}


# EKS Node Group Variables
variable "node_group_name" {
  description = "Name of the EKS node group"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type for the node group"
  type        = string
}

variable "ami_type" {
  description = "AMI type for the node group"
  type        = string
}

variable "desired_capacity" {
  description = "Desired number of nodes in the node group"
  type        = number
}

variable "min_size" {
  description = "Minimum number of nodes in the node group"
  type        = number
}

variable "max_size" {
  description = "Maximum number of nodes in the node group"
  type        = number
}

variable "volume_size" {
  description = "EBS volume size for each node"
  type        = number
}

variable "volume_iops" {
  description = "EBS volume IOPS for each node"
  type        = number
  default     = 0
}

variable "volume_throughput" {
  description = "EBS volume throughput for each node"
  type        = number
  default     = 0
}