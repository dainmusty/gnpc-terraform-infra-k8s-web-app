variable "ami" {
  description = "The AMI ID to use for the instances."
  type        = string
}

variable "instance_type" {
  description = "The instance type to use for the instances."
  type        = string
}

variable "subnet_id" {
  description = "The subnet ID where the instances will be launched."
  type        = string
}

variable "security_group_ids" {
  description = "A list of security group IDs to associate with the instances."
  type        = list(string)
}

variable "ResourcePrefix" {
  description = "The prefix to use for naming resources."
  type        = string
}

variable "vpc_id" {
  description = "The VPC ID for the security group"
  type        = string
}

variable "key_name" {
  description = "The name of the key pair to use for the instances."
  type        = string
}
 
variable "grafana_tags" {
  description = "A map of tags to assign to the instances."
  type        = map(string)
  default     = {}
}

variable "prometheus_tags" {
  description = "A map of tags to assign to the instances."
  type        = map(string)
  default     = {}
}


variable "aws_region" {
  description = "The AWS region where the resources are deployed."
  type        = string
}


variable "monitoring_sg_id" {
  description = "The ID of the monitoring security group."
  type        = string
  
}

variable "grafana_profile_name" {
  description = "The IAM instance profile name for the Grafana instance."
  type        = string
  
}

variable "prometheus_profile_name" {
  description = "The IAM instance profile name for the Prometheus instance."
  type        = string
  
}


