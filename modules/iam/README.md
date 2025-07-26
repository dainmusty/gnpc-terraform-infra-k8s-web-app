# Terraform essential commands and notes
terraform init

terraform plan

terraform apply --auto-approve

terraform destroy --auto-approve

terraform reconfigure

# Generate a terraform plan and apply targeting only specified infrastructure:
# terraform plan -target=aws_vpc.network -target=aws_efs_file_system.efs_setup

# terraform apply -target=aws_vpc.network -target=aws_efs_file_system.efs_setup


#yet to use
#resource "aws_iam_policy" "grafana_cloudwatch_policy" {
  name        = "${var.ResourcePrefix}-grafana-cloudwatch-policy"
  description = "Policy for Grafana CloudWatch role"
  policy      = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

# policy_arn = "arn:aws:iam::aws:policy/CloudWatchReadOnlyAccess" # looks its hardcoding but will check if it can be in main.tf

Error: Unsupported attribute
│
│   on main.tf line 343, in module "monitoring":
│  343:   grafana_instance_profile    = module.iam.grafana_instance_profile
│     ├────────────────
│     │ module.iam is a object  #once you see a module is a object it means one of its dependencies is not being outputted 



# --- ECS Task Role ---
data "aws_iam_policy_document" "ecs_assume" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "ecs_task_role" {
  name                 = "ecs-task-role"
  assume_role_policy   = data.aws_iam_policy_document.ecs_assume.json
  permissions_boundary = aws_iam_policy.permission_boundary.arn
}

resource "aws_iam_policy" "ecs_task_policy" {
  name        = "ecs-task-limited"
  description = "Limited permissions for ECS task role"
  policy      = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = ["logs:CreateLogStream", "logs:PutLogEvents"],
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "attach_ecs_policy" {
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = aws_iam_policy.ecs_task_policy.arn
}


Here are some common options for the identifiers field (service principals) when creating an assume role policy for an admin IAM role:

Identifier	Use Case / Service
ec2.amazonaws.com	EC2 instances
ssm.amazonaws.com	AWS Systems Manager
lambda.amazonaws.com	AWS Lambda functions
ecs-tasks.amazonaws.com	ECS tasks
eks.amazonaws.com	EKS control plane
config.amazonaws.com	AWS Config
rds.amazonaws.com	RDS service
cloudwatch.amazonaws.com	CloudWatch service
apigateway.amazonaws.com	API Gateway
elasticbeanstalk.amazonaws.com	Elastic Beanstalk
Example:

Example:
identifiers = ["ec2.amazonaws.com", "lambda.amazonaws.com"]
You can specify one or more, depending on which AWS services you want to allow to assume the admin role.
Best practice: Only include the services that actually need to assume the role.







# Explains the repitition of the bucket arn
var.operations_bucket_arn,
          "${var.operations_bucket_arn}/*"
This selection is from a Terraform configuration and shows two values related to an S3 bucket ARN (Amazon Resource Name).

var.operations_bucket_arn refers to a Terraform variable that holds the ARN of an S3 bucket, likely used for operations or logging.
"${var.operations_bucket_arn}/*" uses Terraform's interpolation syntax to append /* to the bucket ARN. This pattern represents all objects within the bucket, not just the bucket itself.
Including both the bucket ARN and the bucket ARN with /* is common when defining AWS IAM policies. The first grants permissions on the bucket itself (such as listing the bucket), while the second grants permissions on all objects inside the bucket (such as reading or writing files). This distinction is important because AWS treats actions on the bucket and its contents separately.


# Naming and tagging resources to be done later
name       = "${var.env}-${var.db_subnet_group_name}"


# use when you are not using a vpc cni service account (irsa )
resource "aws_iam_role_policy_attachment" "AmazonEKS_CNI_Policy" {
  role       = aws_iam_role.eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}


condition = var.enable_oidc_and_nodegroup.
my editor is telling me that the condition above is not expected here
Unexpected attribute: An attribute named "condition" is not expected hereTerraform


ChatGPT said:
You're absolutely right — and your editor is correct.

❌ The issue:
This block:

hcl
Copy
Edit
output "oidc_provider_arn" {
  value     = aws_iam_openid_connect_provider.oidc[0].arn
  condition = var.enable_oidc_and_nodegroup  # ❌ INVALID
}
Terraform does not support a condition attribute in output blocks. This is not valid syntax.

✅ Correct way to write a conditional output in Terraform:
You must always return a value — so if you're conditionally creating something, use a ternary (? :) operator to avoid referencing a nonexistent resource:

hcl
Copy
Edit
output "oidc_provider_arn" {
  value = var.enable_oidc_and_nodegroup ? aws_iam_openid_connect_provider.oidc[0].arn : ""
}
This will:

return the OIDC provider ARN if enable_oidc_and_nodegroup is true, or

return an empty string "" if false (e.g. when the resource isn't created).

✅ Final Tip:
You can also use null instead of an empty string:

 
output "oidc_provider_arn" {
  value = var.enable_oidc_and_nodegroup ? aws_iam_openid_connect_provider.oidc[0].arn : null
}
This is useful when chaining outputs or using them in conditions downstream.

Let me know if you'd like me to verify your full IRSA setup with these changes in one view.

# To create IRSA for AlB controller dynamically without creating iam role and its policy attachment manually use;
# IAM Role for IRSA for the AWS Load Balancer Controller
module "eks_irsa_alb_controller" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "5.34.0" # Adjust version as needed
  role_name = "alb-controller-irsa"
  attach_load_balancer_controller_policy = false
  cluster_name = var.cluster_name
  oidc_providers = {
    main = {
      provider_arn = data.aws_eks_cluster.eks.identity[0].oidc.issuer
    }
  }
  policy_arn = aws_iam_policy.aws_load_balancer_controller.arn
  irsa_config = {
    namespace       = "kube-system"
    service_account = "aws-load-balancer-controller"
  }
}


# IAM Role for ALB Controller
resource "aws_iam_role" "alb_controller_irsa" {
  name               = "eks-alb-controller-irsa"
  assume_role_policy = data.aws_iam_policy_document.alb_controller_oidc_trust.json
}

# Attach AWS Managed IAM Policy to Role
resource "aws_iam_role_policy_attachment" "alb_controller" {
  role       = aws_iam_role.alb_controller_irsa.name
  policy_arn = "arn:aws:iam::aws:policy/AWSLoadBalancerControllerIAMPolicy"
}

# Custom IAM Policy (if not using AWS managed one)
# resource "aws_iam_policy" "aws_load_balancer_controller" {
#   name        = "AWSLoadBalancerControllerIAMPolicy"
#   description = "Policy for AWS ALB Controller"
#   policy = file("${path.module}//../../scripts/alb-policy.json")
# }


# Custom basded policy Attachment
resource "aws_iam_role_policy_attachment" "ebs_csi_driver" {
  role       = aws_iam_role.ebs_csi_driver_irsa.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}


# # AWS Managed IAM Policy (if you want to use an AWS managed policy 
# resource "aws_iam_role_policy_attachment" "alb_controller" {
#   role       = aws_iam_role.alb_controller_irsa.name
#   policy_arn = "arn:aws:iam::aws:policy/AWSLoadBalancerControllerIAMPolicy"
# }


# IAM Role for Grafana to access AWS Secrets Manager
# 1. IAM Policy to allow access to specific secret
# resource "aws_iam_policy" "grafana_secrets_access" {
#   name        = "grafana-secretsmanager-access"
#   description = "Allow read-only access to Grafana admin secret"

#   policy = jsonencode({
#     Version = "2012-10-17",
#     Statement = [
#       {
#         Effect = "Allow",
#         Action = [
#           "secretsmanager:GetSecretValue"
#         ],
#         Resource = var.grafana_admin_secret_arn
#       }
#     ]
#   })
# }


# final iam for alb
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
resource "aws_iam_role" "alb_controller_irsa" {
  name               = "eks-alb-controller-irsa"
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
  role       = aws_iam_role.alb_controller_irsa.name
}

# old setup for alb iam

# Define local variable to extract OIDC provider ID from ARN
locals {
  oidc_provider_id = replace(var.oidc_provider_arn, "https://", "")
}

# OIDC Trust Policy for ALB Controller
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
      values   = ["system:serviceaccount:kube-system:aws-load-balancer-controller"]
    }
  }
}

# IAM Role for ALB Controller
resource "aws_iam_role" "alb_controller_irsa" {
  name               = "eks-alb-controller-irsa"
  assume_role_policy = data.aws_iam_policy_document.alb_controller_oidc_trust.json
}

# Custom IAM Policy (if not using AWS managed one)
resource "aws_iam_policy" "alb_controller_policy" {
  name        = "AWSLoadBalancerControllerIAMPolicy"
  description = "Policy for AWS ALB Controller"
  policy = file("${path.module}//../../scripts/alb-policy.json")
}

resource "aws_iam_role_policy_attachment" "alb_controller_attach" {
  policy_arn = aws_iam_policy.alb_controller_policy.arn
  role       = aws_iam_role.alb_controller_irsa.name
}
