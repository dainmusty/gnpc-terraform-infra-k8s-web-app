# Variables for the security group module
variable "ResourcePrefix" {
  description = "Prefix for naming resources."
  type        = string
}

variable "vpc_id" {
  description = "The ID of the VPC where the security groups will be created."
  type        = string
}

variable "public_sg_ingress_rules" {
  description = "List of ingress rules for the public security group."
  type = list(object({
    from_port   = number
    to_port     = number
    protocol    = string
    cidr_blocks = optional(list(string), [])
    sg_ids      = optional(list(string), [])
    description = optional(string, null)
  }))
}

variable "public_sg_egress_rules" {
  description = "List of egress rules for the public security group."
  type = list(object({
    from_port   = number
    to_port     = number
    protocol    = string
    cidr_blocks = optional(list(string), [])
    sg_ids      = optional(list(string), [])
    description = optional(string, null)
  }))
}

variable "private_sg_ingress_rules" {
  description = "List of ingress rules for the private security group."
  type = list(object({
    from_port   = number
    to_port     = number
    protocol    = string
    cidr_blocks = optional(list(string), [])
    sg_ids      = optional(list(string), [])
    description = optional(string, null)
  }))
}

variable "private_sg_egress_rules" {
  description = "List of egress rules for the private security group."
  type = list(object({
    from_port   = number
    to_port     = number
    protocol    = string
    cidr_blocks = optional(list(string), [])
    sg_ids      = optional(list(string), [])
    description = optional(string, null)
  }))
}

variable "public_sg_description" {
  description = "Description for the public security group."
  type        = string
}
variable "private_sg_description" {
  description = "Description for the private security group."
  type        = string
}

variable "monitoring_sg_ingress_rules" {
  description = "List of ingress rules for the monitoring security group."
  type = list(object({
    description = optional(string)
    from_port   = number
    to_port     = number
    protocol    = string
    cidr_blocks = optional(list(string), [])
  }))
}

variable "monitoring_sg_egress_rules" {
  description = "List of egress rules for the monitoring security group."
  type = list(object({
    description = optional(string)
    from_port   = number
    to_port     = number
    protocol    = string
    cidr_blocks = optional(list(string), [])
  }))
}



