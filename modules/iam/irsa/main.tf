# Data Source of modules
data "aws_caller_identity" "current" {}

# IAM Roles for IRSA (IAM Roles for Service Accounts)

########################################
# IAM Roles for VPC CNI Add-on
########################################
# Trust Policy (Assume role) for IRSA Role

data "aws_iam_policy_document" "vpc_cni_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    condition {
      test     = "StringEquals"
      variable = "${replace(var.oidc_issuer, "https://", "")}:sub"
      values   = ["system:serviceaccount:kube-system:aws-node"]
    }

    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }
  }
}

resource "aws_iam_role" "vpc_cni_irsa_role" {
  name               = "${var.cluster_name}-vpc-cni-irsa"
  assume_role_policy = data.aws_iam_policy_document.vpc_cni_assume_role_policy.json
  tags = {
    "Name" = "${var.cluster_name}-vpc-cni-irsa"
  }
}

resource "aws_iam_role_policy_attachment" "vpc_cni_policy_attach" {
  for_each = toset([
    
    "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",
    
  ])
  role       = aws_iam_role.vpc_cni_irsa_role.name
  policy_arn = each.value
}

########################################


# Alb Controller Setup
locals {
  # Extracts the OIDC provider ID from the full ARN (e.g. oidc.eks.us-east-1.amazonaws.com/id/EXAMPLED539D4633E53DE1B716D3041E)
  oidc_provider_id = replace(var.oidc_provider_arn, "https://", "")
}

# Trust Policy for ALB Controller IAM Role
data "aws_iam_policy_document" "alb_controller_oidc_trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_provider_id}:sub"
      values   = ["system:serviceaccount:kube-system:alb-controller"]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_provider_id}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

# IAM Role to be assumed by the ALB Controller via IRSA
resource "aws_iam_role" "alb_controller_role" {
  name               = "aws-load-balancer-controller"
  assume_role_policy = data.aws_iam_policy_document.alb_controller_oidc_trust.json
}

# IAM Policy for ALB Controller (can be AWS managed or custom file)
resource "aws_iam_policy" "alb_controller_policy" {
  name        = "AWSLoadBalancerControllerIAMPolicy"
  description = "Policy for AWS ALB Controller"
  policy      = file("${path.module}/../../../scripts/alb-policy.json")
}

# Attach IAM Policy to the Role
resource "aws_iam_role_policy_attachment" "alb_controller_attach" {
  policy_arn = aws_iam_policy.alb_controller_policy.arn
  role       = aws_iam_role.alb_controller_role.name
}

# ArgoCD Role for EKS Management
resource "aws_iam_role" "argocd_role" {
  name = "argocd-eks-management-role"

 assume_role_policy = jsonencode({
  Version = "2012-10-17",
  Statement = [{
    Effect = "Allow",
    Principal = {
      Federated = var.oidc_provider_arn
    },
    Action = "sts:AssumeRoleWithWebIdentity",
    Condition = {
      StringEquals = {
        "${var.oidc_issuer}:sub" = "system:serviceaccount:argocd:argocd-server"
      }
    }
  }]
})

}

# Attach multiple IAM policies to the ArgoCD role
resource "aws_iam_role_policy_attachment" "argocd_policies" {
  for_each = toset([
    "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "arn:aws:iam::aws:policy/AmazonVPCFullAccess",
    "arn:aws:iam::aws:policy/AmazonEKSComputePolicy",
    "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",
    "arn:aws:iam::aws:policy/AmazonEKSLoadBalancingPolicy",
    "arn:aws:iam::aws:policy/ElasticLoadBalancingFullAccess",
    "arn:aws:iam::aws:policy/AdministratorAccess" # ⚠️ Remove or restrict for production
  ])

  role       = aws_iam_role.argocd_role.name
  policy_arn = each.value
}



# EBS CSI Driver Setup
# OIDC Trust Policy for EBS CSI Driver
resource "aws_iam_role" "ebs_csi_driver_role" {
  name = "eks-ebs-csi-driver-irsa"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Federated = var.oidc_provider_arn
      },
      Action = "sts:AssumeRoleWithWebIdentity",
      Condition = {
        StringEquals = {
          "${var.oidc_issuer}:sub" = "system:serviceaccount:kube-system:ebs-csi-controller-sa"
        }
      }
    }]
  })
}


# Custom IAM Policy (if not using AWS managed one)
resource "aws_iam_policy" "ebs_csi_driver_policy" {
  name        = "AWSEBSCSIDriverIAMPolicy"
  description = "Policy for AWS EBS CSI Driver"
  policy = file("${path.module}/../../../scripts/ebs-csi-policy.json")
}

resource "aws_iam_role_policy_attachment" "ebs_csi_driver_attach" {
  policy_arn = aws_iam_policy.ebs_csi_driver_policy.arn
  role       = aws_iam_role.ebs_csi_driver_role.name
}


# -------------------------------------------------------
# IAM Role for Grafana IRSA
# -------------------------------------------------------
resource "aws_iam_role" "grafana_irsa" {
  name = "eks-grafana-irsa-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Federated = var.oidc_provider_arn
      },
      Action = "sts:AssumeRoleWithWebIdentity",
      Condition = {
        StringEquals = {
          "${var.oidc_issuer}:sub" = "system:serviceaccount:monitoring:grafana"
        }
      }
    }]
  })
}

data "aws_secretsmanager_secret" "grafana" {
  name = var.grafana_secret_name
}

# -------------------------------------------------------
# IAM Policy for Secrets Manager Access
# -------------------------------------------------------
resource "aws_iam_policy" "grafana_secrets_access" {
  name        = "grafana-secretsmanager-access"
  description = "Allow Grafana to access Secrets Manager for admin credentials"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "secretsmanager:GetSecretValue"
        ],
        Resource = data.aws_secretsmanager_secret.grafana.arn
  
      }
    ]
  })
}

# -------------------------------------------------------
# Attach Policy to Grafana Role
# -------------------------------------------------------
resource "aws_iam_role_policy_attachment" "grafana_secret_policy_attach" {
  role       = aws_iam_role.grafana_irsa.name
  policy_arn = aws_iam_policy.grafana_secrets_access.arn
}


