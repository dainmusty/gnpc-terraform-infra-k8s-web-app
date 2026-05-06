module "eks" {
  source                  = "../../../modules/eks"

  # Required cluster variables
  subnet_ids = module.vpc.private_subnets
  vpc_id     = module.vpc.vpc_id 
  private_sg_id = [module.private_sg.private_sg_id]
  
  # EKS Cluster variables
  cluster_name                   = "dev-gnpc-eks-cluster"
  cluster_role = module.iam_core.eks_cluster_role_arn
  cluster_endpoint_public_access = true
  cluster_version                = "1.34"
  eks_cluster_tags              = {
    Environment = "Dev-GNPC"
    Project     = "Startup"
  }
  eks_cluster_policies = module.iam_core.eks_cluster_policy_attachments
  
  
  # EKS Managed Node Groups variables
  node_group_role_arn = module.iam_core.node_group_role_arn
  eks_node_policies     = module.iam_core.eks_node_policy_attachments
  eks_node_groups_configuration = {
    dev-wg = {
      desired_size  = 1
      max_size      = 2
      min_size      = 1
      instance_types = ["t3.medium"]
      capacity_type  = "SPOT"   # This has to do with EC2 instance purchasing options, either ON_DEMAND or SPOT.
      tags = {
        Environment = "Dev-GNPC"
        Project     = "Startup"
        Name        = "dev-wg"
      }
    }
  }

  eks_managed_node_group_defaults = {
    instance_types = ["t2.micro"]
    ami_type       = "AL2023_x86_64_STANDARD"
  }
}
