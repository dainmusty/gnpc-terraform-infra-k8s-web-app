# Permission Boundary
resource "aws_iam_policy" "permission_boundary" {
  name        = "${var.company_name}-${var.env}-permission-boundary"
  description = "Permission boundary to restrict access to only required services"
  policy      = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid      = "AllowLimitedServices",
        Effect   = "Allow",
        Action   = [
          "s3:*",
          "eks:*",
          "ec2:*",
          "rds:*",
          "config:*"
        ],
        Resource = "*"
      }
    ]
  })
}



# --- Admin Role ---
data "aws_iam_policy_document" "admin_assume" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = var.admin_role_principals
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "admin_role" {
  name                 = "${var.company_name}-${var.env}-admin-role"
  assume_role_policy   = data.aws_iam_policy_document.admin_assume.json
  permissions_boundary = var.admin_permissions_boundary_arn
}

resource "aws_iam_policy" "admin_policy" {
  name        = "admin-full-access"
  description = "Full admin access for admin role"
  policy      = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = "*",
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "attach_admin_policy" {
  role       = aws_iam_role.admin_role.name
  policy_arn = aws_iam_policy.admin_policy.arn
}

resource "aws_iam_instance_profile" "admin_instance_profile" {
  name = "GNPC-dev-admin-instance-profile"
  role = aws_iam_role.admin_role.name
}


# --- Config Role ---
data "aws_iam_policy_document" "config_assume" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = var.config_role_principals
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "config_role" {
  name                 = "${var.company_name}-${var.env}-config-role"
  assume_role_policy   = data.aws_iam_policy_document.config_assume.json
  permissions_boundary = var.config_permissions_boundary_arn
}

resource "aws_iam_policy" "config_policy" {
  name        = "aws-config-policy"
  description = "Policy for AWS Config role"
  policy      = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = ["config:*", "s3:GetBucketAcl", "s3:PutObject"],
        Resource = [
          var.log_bucket_arn,
          "${var.log_bucket_arn}/*"
        ]
      }
    ]
  })
}

# --- S3 Full Access Role ---
data "aws_iam_policy_document" "s3_full_access_assume" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = var.s3_full_access_role_principals
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "s3_full_access_role" {
  name                 = "${var.company_name}-${var.env}-s3-full-access-role"
  assume_role_policy   = data.aws_iam_policy_document.s3_full_access_assume.json
  permissions_boundary = var.s3_full_access_permissions_boundary_arn
}

resource "aws_iam_policy" "s3_full_access_policy" {
  name        = "s3-full-access"
  description = "Policy for full read/write S3 access"
  policy      = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = ["s3:*"],
        Resource = [
          var.operations_bucket_arn,
          "${var.operations_bucket_arn}/*"
        ]
      }
    ]
  })
}
resource "aws_iam_role_policy_attachment" "attach_s3_full_access_policy" {
  role       = aws_iam_role.s3_full_access_role.name
  policy_arn = aws_iam_policy.s3_full_access_policy.arn
}


# --- S3 RW Access Role ---
data "aws_iam_policy_document" "s3_rw_assume" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = var.s3_rw_role_principals
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "s3_rw_role" {
  name                 = "${var.company_name}-${var.env}-s3-rw-role"
  assume_role_policy   = data.aws_iam_policy_document.s3_rw_assume.json
  permissions_boundary = var.s3_rw_permissions_boundary_arn
}

resource "aws_iam_policy" "s3_rw_access" {
  name        = "S3AccessToBucket"
  description = "Allow read/write access to the specified S3 bucket"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          var.log_bucket_arn,
          "${var.log_bucket_arn}/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "attach_s3_rw_policy" {
  role       = aws_iam_role.s3_rw_role.name
  policy_arn = aws_iam_policy.s3_rw_access.arn
}


# --- Grafana Role ---
data "aws_iam_policy_document" "grafana_assume" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = var.grafana_role_principals
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_policy" "grafana_policy" {
  name        = "${var.env}-grafana-policy"
  description = "Policy for Grafana role"
  policy      = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = [
          "cloudwatch:GetMetricData",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams",
          "logs:GetLogEvents"
        ]
        Resource = "*"
      },
      
      {
        Effect   = "Allow"
        Action   = [
          "ec2:DescribeInstances",
          "ec2:DescribeTags"
        ]
        Resource = "*"
      }
    ]
  })
}


resource "aws_iam_role" "grafana_role" {
  name                 = "${var.company_name}-${var.env}-grafana-role"
  assume_role_policy   = data.aws_iam_policy_document.grafana_assume.json
  permissions_boundary = var.grafana_permissions_boundary_arn
}

resource "aws_iam_policy" "cloudwatch_policy" {
  name        = "${var.env}-cloudwatch-policy"
  description = "Policy for CloudWatch role"
  policy      = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = [
          "cloudwatch:GetMetricData",
          "cloudwatch:GetMetricStatistics",
          "cloudwatch:ListMetrics",
          "logs:DescribeLogGroups",
          "logs:GetLogEvents",
          "logs:FilterLogEvents"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "grafana_policy_attachment" {
  role       = aws_iam_role.grafana_role.name
  policy_arn = aws_iam_policy.grafana_policy.arn
}

resource "aws_iam_role_policy_attachment" "cloudwatch_policy_attachment" {
  role       = aws_iam_role.grafana_role.name
  policy_arn = aws_iam_policy.cloudwatch_policy.arn
}



# --- Prometheus Role ---
data "aws_iam_policy_document" "prometheus_assume" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = var.prometheus_role_principals
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "prometheus_role" {
  name                 = "${var.company_name}-${var.env}-prometheus-role"
  assume_role_policy   = data.aws_iam_policy_document.prometheus_assume.json
  permissions_boundary = var.prometheus_permissions_boundary_arn
}

resource "aws_iam_policy" "prometheus_policy" {
  name        = "${var.env}-prometheus-policy"
  description = "Policy for Prometheus role"
  policy      = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = [
          "cloudwatch:PutMetricData",
          "cloudwatch:GetMetricData",
          "cloudwatch:GetMetricStatistics",
          "cloudwatch:ListMetrics",
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "ec2:DescribeInstances"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "prometheus_policy_attachment" {
  role       = aws_iam_role.prometheus_role.name
  policy_arn = aws_iam_policy.prometheus_policy.arn
}

# Instance profiles
resource "aws_iam_instance_profile" "grafana_instance_profile" {
  name = "GNPC-dev-grafana-instance-profile"
  role = aws_iam_role.grafana_role.name
}

resource "aws_iam_instance_profile" "prometheus_instance_profile" {
  name = "GNPC-dev-prometheus-instance-profile"
  role = aws_iam_role.prometheus_role.name
}



# Data Source of modules
data "aws_caller_identity" "current" {}

data "aws_eks_cluster" "eks" {
  name = var.cluster_name
}

data "aws_eks_cluster_auth" "eks" {
  name = var.cluster_name
}



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
  policy      = file("${path.module}/../../scripts/alb-policy.json")
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
        Federated = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${replace(data.aws_eks_cluster.eks.identity[0].oidc[0].issuer, "https://", "")}"
      },
      Action = "sts:AssumeRoleWithWebIdentity",
      Condition = {
        StringEquals = {
          "${replace(data.aws_eks_cluster.eks.identity[0].oidc[0].issuer, "https://", "")}:sub" = "system:serviceaccount:argocd:argocd-server"
        }
      }
    }]
  })
}


# find a way to attach multiple policies to the role in a much more cleaner way than the approach below. the current approach makes the code too long
resource "aws_iam_role_policy_attachment" "iam_full" {
  role       = aws_iam_role.argocd_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "vpc_full" {
  role       = aws_iam_role.argocd_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonVPCFullAccess"
}

resource "aws_iam_role_policy_attachment" "cf_full" {
  role       = aws_iam_role.argocd_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSComputePolicy"
}

resource "aws_iam_role_policy_attachment" "eks_full" {
  role       = aws_iam_role.argocd_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "alb_full" {
  role       = aws_iam_role.argocd_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSLoadBalancingPolicy"
}

resource "aws_iam_role_policy_attachment" "elb_full_access" {
  role       = aws_iam_role.argocd_role.name
  policy_arn = "arn:aws:iam::aws:policy/ElasticLoadBalancingFullAccess"
}

resource "aws_iam_role_policy_attachment" "admin_access" {        # Removed for security during production
  role       = aws_iam_role.argocd_role.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
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
        Federated = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${replace(data.aws_eks_cluster.eks.identity[0].oidc[0].issuer, "https://", "")}"
      },
      Action = "sts:AssumeRoleWithWebIdentity",
      Condition = {
        StringEquals = {
          "${replace(data.aws_eks_cluster.eks.identity[0].oidc[0].issuer, "https://", "")}:sub" = "system:serviceaccount:kube-system:ebs-csi-controller-sa"
        }
      }
    }]
  })
}


# Custom IAM Policy (if not using AWS managed one)
resource "aws_iam_policy" "ebs_csi_driver_policy" {
  name        = "AWSEBSCSIDriverIAMPolicy"
  description = "Policy for AWS EBS CSI Driver"
  policy = file("${path.module}/../../scripts/ebs-csi-policy.json")
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
        Federated = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${replace(data.aws_eks_cluster.eks.identity[0].oidc[0].issuer, "https://", "")}"
      },
      Action = "sts:AssumeRoleWithWebIdentity",
      Condition = {
        StringEquals = {
          "${replace(data.aws_eks_cluster.eks.identity[0].oidc[0].issuer, "https://", "")}:sub" = "system:serviceaccount:monitoring:grafana"
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
