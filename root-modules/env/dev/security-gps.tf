# Bastion SG
module "bastion_sg" {
  source          = "../../../modules/security/bastion"
  vpc_id          = module.vpc.vpc_id
  env = "Dev-GNPC"

  bastion_ingress_rules = [
    {
      description              = "Allow traffic from the internet"
      from_port                = 22
      to_port                  = 22
      protocol                 = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  ]

  bastion_egress_rules = [
    {
      description = "Allow all egress"
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = ["0.0.0.0/0"]
    }
  ]

  bastion_sg_tags = {
    Name        = "bastion-sg"
    Environment = "Dev"
  }

}


# Bastion SG
module "private_sg" {
  source          = "../../../modules/security/private-sg"
  vpc_id          = module.vpc.vpc_id
  env = "Dev-GNPC"

  private_ingress_rules = [
    {
      description              = "Allow traffic from bastion"
      from_port                = 22
      to_port                  = 22
      protocol                 = "tcp"
      source_security_group_ids = [module.bastion_sg.bastion_sg_id]
    },
    {
      description              = "Allow traffic from bastion"
      from_port                = 443
      to_port                  = 443
      protocol                 = "tcp"
      source_security_group_ids = [module.bastion_sg.bastion_sg_id]
    }
  ]

  private_egress_rules = [
    {
      description = "Allow all egress"
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = ["0.0.0.0/0"]
    }
  ]

  private_sg_tags = {
    Name        = "private-sg"
    Environment = "Dev"
  }

}