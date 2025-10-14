variable "vpc_id" {
  type        = string
  description = "VPC ID"
}

variable "env" {
  type        = string
  description = "Prefix for environment"
}


variable "description" {
  type        = string
  default     = "web security group"
}

variable "bastion_ingress_rules" {
  type = list(object({
    from_port                = number
    to_port                  = number
    protocol                 = string
    description              = string
    cidr_blocks              = optional(list(string))
    source_security_group_ids = optional(list(string))
  }))
  default = []
}

variable "bastion_egress_rules" {
  type = list(object({
    from_port   = number
    to_port     = number
    protocol    = string
    description = string
    cidr_blocks = list(string)
  }))
  default = []
}

variable "bastion_sg_tags" {
  description = "Additional tags for the bastion security group"
  type        = map(string)
  default     = {}
  
}

