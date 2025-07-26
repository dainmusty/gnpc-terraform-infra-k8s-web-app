# -------------------------------
# EKS Cluster Stack (CloudFormation)
# -------------------------------
resource "aws_cloudformation_stack" "eks_cluster_stack" {
  name          = "eks-cluster-stack"
  template_body = file("${path.module}/../../scripts/eks-cluster-cft.yaml")

  parameters = {
    ClusterName = var.cluster_name
    KubernetesVersion = var.kube_version
    VpcCidr = var.vpc_cidr
    AvailabilityZone1 = var.availability_zone_1
    AvailabilityZone2 = var.availability_zone_2
    AvailabilityZone3 = var.availability_zone_3
    AvailabilityZone4 = var.availability_zone_4
    PublicSubnet1Cidr = var.public_subnet_1_cidr
    PublicSubnet2Cidr = var.public_subnet_2_cidr
    PrivateSubnet1Cidr = var.private_subnet_1_cidr
    PrivateSubnet2Cidr = var.private_subnet_2_cidr
  }


  capabilities  = ["CAPABILITY_IAM", "CAPABILITY_NAMED_IAM"]
}

# -------------------------------
# Fetch EKS Cluster Metadata
# -------------------------------
data "aws_eks_cluster" "eks" {
  name = "effulgencetech-dev"
  depends_on = [aws_cloudformation_stack.eks_cluster_stack]
}

data "aws_eks_cluster_auth" "eks" {
  name = data.aws_eks_cluster.eks.name
}

# -------------------------------
# OIDC Provider for IRSA
# -------------------------------
data "tls_certificate" "oidc_thumbprint" {
  url = data.aws_eks_cluster.eks.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks" {
  url             = data.aws_eks_cluster.eks.identity[0].oidc[0].issuer
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.oidc_thumbprint.certificates[0].sha1_fingerprint]
}

locals {
  oidc_provider_id = replace(data.aws_eks_cluster.eks.identity[0].oidc[0].issuer, "https://", "")
}

data "aws_iam_policy_document" "oidc_trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.eks.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_provider_id}:sub"
      values   = ["system:serviceaccount:kube-system:aws-node"]
    }
  }
}

# -------------------------------
# IAM Role for VPC CNI (IRSA)
# -------------------------------
resource "aws_iam_role" "vpc_cni_irsa" {
  name               = "eks-vpc-cni-irsa"
  assume_role_policy = data.aws_iam_policy_document.oidc_trust.json
}

resource "aws_iam_role_policy_attachment" "vpc_cni" {
  role       = aws_iam_role.vpc_cni_irsa.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

# -------------------------------
# EKS Add-ons
# -------------------------------
resource "aws_eks_addon" "vpc_cni" {
  cluster_name             = data.aws_eks_cluster.eks.name
  addon_name               = "vpc-cni"
 
  service_account_role_arn = aws_iam_role.vpc_cni_irsa.arn
  depends_on               = [aws_iam_role_policy_attachment.vpc_cni]
}

resource "aws_eks_addon" "kube_proxy" {
  cluster_name   = data.aws_eks_cluster.eks.name
  addon_name     = "kube-proxy"
  
  depends_on     = [aws_cloudformation_stack.eks_cluster_stack]
}

resource "aws_eks_addon" "coredns" {
  cluster_name   = data.aws_eks_cluster.eks.name
  addon_name     = "coredns"
  
  depends_on     = [aws_cloudformation_stack.eks_cluster_stack]
}

# resource "aws_eks_addon" "metrics_server" {
#   cluster_name   = data.aws_eks_cluster.eks.name
#   addon_name     = "metrics-server"
  
#   depends_on     = [aws_cloudformation_stack.eks_cluster_stack]
# }

# -------------------------------
# Node Group Stack (CloudFormation)
# -------------------------------
resource "aws_cloudformation_stack" "eks_node_group_stack" {
  name          = "eks-nodegroup-stack"
  template_body = file("${path.module}/../../scripts/eks-nodegp-cft.yaml")

  parameters = {
    ClusterName       = var.cluster_name
    NodeGroupName     = var.node_group_name
    InstanceType      = var.instance_type
    AmiType           = var.ami_type
    DesiredCapacity   = var.desired_capacity
    MinSize           = var.min_size
    MaxSize           = var.max_size
    VolumeSize        = var.volume_size
    VolumeIOPS        = var.volume_iops
    VolumeThroughput  = var.volume_throughput
  }

  capabilities  = ["CAPABILITY_IAM", "CAPABILITY_NAMED_IAM"]
  depends_on    = [aws_eks_addon.vpc_cni]
}

# -------------------------------
# Output: Kubeconfig Command (Optional)
# -------------------------------
output "kubeconfig_command" {
  value = "aws eks update-kubeconfig --region ${var.region} --name ${data.aws_eks_cluster.eks.name}"
  description = "Run this to configure your local kubeconfig"
}
