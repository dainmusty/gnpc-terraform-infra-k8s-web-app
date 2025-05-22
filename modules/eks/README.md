# Terraform essential commands and notes
terraform init

terraform plan

terraform apply --auto-approve

terraform destroy --auto-approve

terraform reconfigure

# Generate a terraform plan and apply targeting only specified infrastructure:
# terraform plan -target=aws_vpc.network -target=aws_efs_file_system.efs_setup

# terraform apply -target=aws_vpc.network -target=aws_efs_file_system.efs_setup


# 
variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes version to use for the cluster"
  type        = string
  default     = "1.29"
}

variable "vpc_id" {
  description = "VPC ID for the EKS cluster"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for EKS nodes"
  type        = list(string)
}

variable "node_group_config" {
  description = "Map of node group configurations"
  type = map(object({
    instance_types  = list(string)
    desired_size    = number
    min_size        = number
    max_size        = number
    capacity_type   = string # ON_DEMAND or SPOT
  }))
}

variable "eks_role_arn" {
  description = "IAM role ARN for the EKS control plane"
  type        = string
}

variable "node_role_arn" {
  description = "IAM role ARN for the EKS worker nodes"
  type        = string
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}


main.tf
resource "aws_eks_cluster" "this" {
  name     = var.cluster_name
  version  = var.kubernetes_version
  role_arn = var.eks_role_arn

  vpc_config {
    subnet_ids = var.subnet_ids
  }

  tags = merge(var.tags, {
    Name = var.cluster_name
  })
}

resource "aws_eks_node_group" "this" {
  for_each = var.node_group_config

  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "${var.cluster_name}-${each.key}"
  node_role_arn   = var.node_role_arn
  subnet_ids      = var.subnet_ids

  scaling_config {
    desired_size = each.value.desired_size
    min_size     = each.value.min_size
    max_size     = each.value.max_size
  }

  instance_types = each.value.instance_types
  capacity_type  = each.value.capacity_type

  depends_on = [aws_eks_cluster.this]

  tags = merge(var.tags, {
    Name = "${var.cluster_name}-${each.key}"
  })
}


outputs.tf
output "cluster_name" {
  value = aws_eks_cluster.this.name
}

output "cluster_endpoint" {
  value = aws_eks_cluster.this.endpoint
}

output "kubeconfig" {
  value = jsonencode({
    apiVersion = "v1"
    clusters = [{
      cluster = {
        server                   = aws_eks_cluster.this.endpoint
        "certificate-authority-data" = aws_eks_cluster.this.certificate_authority[0].data
      }
      name = aws_eks_cluster.this.name
    }]
    contexts = [{
      context = {
        cluster = aws_eks_cluster.this.name
        user    = "aws"
      }
      name = aws_eks_cluster.this.name
    }]
    current-context = aws_eks_cluster.this.name
    kind            = "Config"
    preferences     = {}
    users = [{
      name = "aws"
      user = {}
    }]
  })
}

output "node_group_names" {
  value = [for ng in aws_eks_node_group.this : ng.node_group_name]
}


root module call
module "eks" {
  source = "./modules/eks"

  cluster_name       = "myapp-eks"
  kubernetes_version = "1.29"
  vpc_id             = module.vpc.vpc_id
  subnet_ids         = module.vpc.private_subnets

  eks_role_arn       = module.iam.eks_cluster_role_arn
  node_role_arn      = module.iam.eks_node_role_arn

  node_group_config = {
    ng1 = {
      instance_types = ["t3.medium"]
      desired_size   = 2
      min_size       = 1
      max_size       = 3
      capacity_type  = "ON_DEMAND"
    }
  }

  tags = {
    Environment = "dev"
    Project     = "myapp"
  }
}


# configmap setup
resource "null_resource" "apply_aws_auth" {
  provisioner "local-exec" {
    command = <<EOF
      aws eks update-kubeconfig --region ${var.aws_region} --name ${aws_eks_cluster.this.name}
      kubectl apply -f ${path.module}/manifests/aws-auth.yaml
    EOF
  }

  depends_on = [aws_eks_node_group.this]
}


// Ensure the aws-auth ConfigMap is applied separately using kubectl or Terraform Kubernetes provider.
provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.cluster.token
}

data "aws_eks_cluster_auth" "cluster" {
  name = module.eks.cluster_name

}