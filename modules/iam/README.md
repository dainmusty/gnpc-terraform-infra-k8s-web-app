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