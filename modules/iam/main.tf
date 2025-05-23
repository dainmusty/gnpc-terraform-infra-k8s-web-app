# Permission Boundary
resource "aws_iam_policy" "permission_boundary" {
  name                 = "${var.company_name}-${var.env}-permission-boundary"
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
          "logs:PutLogEvents"
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


# --- EKS Cluster Role ---
data "aws_iam_policy_document" "eks_cluster_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = var.eks_cluster_role_principals
    }
  }
}

resource "aws_iam_role" "eks_cluster_role" {
  name                 = "${var.company_name}-${var.env}-eks-cluster-role"
  assume_role_policy   = data.aws_iam_policy_document.eks_cluster_assume.json
  permissions_boundary = var.eks_cluster_permissions_boundary_arn
}

resource "aws_iam_role_policy_attachment" "cluster_AmazonEKSClusterPolicy" {
  role       = aws_iam_role.eks_cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

# --- EKS Node Role ---
data "aws_iam_policy_document" "eks_node_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = var.eks_node_role_principals # default: ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "eks_node_role" {
  name                 = "${var.company_name}-${var.env}-${var.cluster_name}-node-role"
  assume_role_policy   = data.aws_iam_policy_document.eks_node_assume.json
  permissions_boundary = var.eks_node_permissions_boundary_arn # optional
}

resource "aws_iam_role_policy_attachment" "node_AmazonEKSWorkerNodePolicy" {
  role       = aws_iam_role.eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "node_AmazonEKS_CNI_Policy" {
  role       = aws_iam_role.eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "node_AmazonEC2ContainerRegistryReadOnly" {
  role       = aws_iam_role.eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_instance_profile" "grafana_instance_profile" {
  name = "GNPC-dev-grafana-instance-profile"
  role = aws_iam_role.grafana_role.name
}

resource "aws_iam_instance_profile" "prometheus_instance_profile" {
  name = "GNPC-dev-prometheus-instance-profile"
  role = aws_iam_role.prometheus_role.name
}

