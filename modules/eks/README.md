# Terraform essential commands and notes
terraform init

terraform plan

terraform apply --auto-approve

terraform destroy --auto-approve

terraform reconfigure

#
terraform apply -target=aws_eks_cluster.eks_cluster


✅ Recommended Terraform Two-Step Plan (Best Practice)
Step 1: Apply EKS Cluster + OIDC + IAM

Create the EKS cluster.

Wait for the data "aws_eks_cluster" to fetch the OIDC issuer.

Create the IAM OIDC provider.

Create any IAM roles and policies needed by the node group and addons.

# run terraform apply -target=aws_eks_cluster.eks_cluster

Step 2: Apply Node Group + Addons

Create the managed node group.

Attach IAM roles with proper trust relationships.

Install addons (vpc-cni, coredns, kube-proxy, etc).
# run terraform apply


✅ Summary
What	Best Practice
Cluster + OIDC	Terraform apply (Step 1)
Nodegroup + Addons	Terraform apply (Step 2)
CI/CD Strategy	Split into two steps in pipeline
One-shot Deploy	Only possible via eksctl/CloudFormation

# Generate a terraform plan and apply targeting only specified infrastructure:
# terraform plan -target=aws_vpc.network -target=aws_efs_file_system.efs_setup

# terraform apply -target=aws_vpc.network -target=aws_efs_file_system.efs_setup

aws eks update-kubeconfig --region us-east-1 --name effulgencetech-dev



🔁 Option 1: Two-Phase Terraform Apply (Recommended for Simplicity)
Step 1 – Apply only the EKS cluster:

hcl
Copy
Edit
resource "aws_eks_cluster" "eks_cluster" {
  name     = var.cluster_name
  role_arn = var.eks_cluster_role_arn
  version  = "1.32"

  vpc_config {
    subnet_ids         = var.subnet_ids
    security_group_ids = [var.cluster_security_group_id]
  }

  depends_on = [var.cluster_AmazonEKSClusterPolicy]
}
Then apply:

bash
Copy
Edit
terraform apply -target=aws_eks_cluster.eks_cluster
Step 2 – Fetch OIDC URL and Add IAM Provider

After the EKS cluster is created, the OIDC URL becomes available. Then you can use:

hcl
Copy
Edit
data "aws_eks_cluster" "eks" {
  name = aws_eks_cluster.eks_cluster.name
}

resource "aws_iam_openid_connect_provider" "oidc" {
  url             = data.aws_eks_cluster.eks.identity[0].oidc[0].issuer
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["9e99a48a9960b14926bb7f3b02e22da0a4d34e0d"]
}
Then run:

bash
Copy
Edit
terraform apply
🧠 Option 2: External Data Source (Automated)
If you want a fully automated approach, you can use a null_resource or external data source to call an external script that fetches the thumbprint — but it’s more brittle and less readable. Here’s the idea in brief:

hcl
Copy
Edit
data "external" "oidc_thumbprint" {
  program = ["bash", "${path.module}/scripts/get_thumbprint.sh"]
}
But this is generally discouraged for maintainability. Stick with Option 1 unless you're automating across multiple accounts.

🧼 Recommendation Recap
✅ Use two-phase apply to first create the cluster, then create the OIDC provider and node groups.

✅ Use hardcoded thumbprint (9e99a48a9960b14926bb7f3b02e22da0a4d34e0d) only if you're using AWS's default Root CA (which EKS does).

🚫 Avoid trying to create aws_iam_openid_connect_provider before the cluster.

If you'd like, I can help refactor your Terraform into a clean two-phase structure and show you how to script both phases with minimal changes.






You said:
what is AWS Root CA?


ChatGPT said:
The AWS Root CA is a Certificate Authority (CA) that Amazon Web Services uses to secure communication between services — like when your EKS cluster uses OIDC (OpenID Connect) to communicate securely with IAM and other services.

🛡️ What is a Root CA?
A Root Certificate Authority is a trusted entity that issues digital certificates. These certificates are used to establish secure (TLS/SSL) connections. In AWS, the OIDC provider your EKS cluster uses must be trusted, so its certificate needs to be verified — this is where the Root CA’s thumbprint comes in.

📦 In the context of EKS + OIDC
When you enable OIDC on your EKS cluster:

The cluster uses a public OIDC issuer like:
https://oidc.eks.us-east-1.amazonaws.com/id/EXAMPLE

This URL is backed by an SSL certificate.

The Root CA for that certificate is Amazon Trust Services.

✅ Therefore, when creating an aws_iam_openid_connect_provider in Terraform, AWS wants to ensure the OIDC issuer is trusted by checking the SHA1 thumbprint of the Root CA.

✅ Common Thumbprint for AWS OIDC (Amazon Root CA 1)
Most EKS clusters use this one:

Copy
Edit
9e99a48a9960b14926bb7f3b02e22da0a4d34e0d













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




# Launch Template for EKS worker nodes if you are not using node groups
resource "aws_launch_template" "eks_worker" {
  name_prefix   = "${var.cluster_name}-worker-"
  image_id      = data.aws_ami.eks_worker.id
  instance_type = var.instance_type
  iam_instance_profile {
    name = var.worker_instance_profile_name
  }
  user_data = base64encode(templatefile("${path.module}/user_data.sh.tpl", {
    cluster_name = aws_eks_cluster.eks_cluster.name
    endpoint     = aws_eks_cluster.eks_cluster.endpoint
    ca_data      = aws_eks_cluster.eks_cluster.certificate_authority[0].data
    node_role    = var.eks_node_role_arn
  }))
  # ...add other settings as needed...
}

# Get latest EKS-optimized AMI
data "aws_ami" "eks_worker" {
  most_recent = true
  owners      = ["602401143452"] # Amazon EKS AMI account
  filter {
    name   = "name"
    values = ["amazon-eks-node-*"]
  }
  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

# Create 2 EC2 worker nodes
resource "aws_instance" "eks_worker" {
  count         = 2
  ami           = data.aws_ami.eks_worker.id
  instance_type = var.instance_type
  subnet_id     = element(var.subnet_ids, count.index)
  iam_instance_profile = var.worker_instance_profile_name
  user_data     = base64encode(templatefile("${path.module}/user_data.sh.tpl", {
    cluster_name = aws_eks_cluster.eks_cluster.name
    endpoint     = aws_eks_cluster.eks_cluster.endpoint
    ca_data      = aws_eks_cluster.eks_cluster.certificate_authority[0].data
    node_role    = var.eks_node_role_arn
  }))
  # ...add security groups, tags, etc. as needed...
}

# variables for node group
variable "cluster_name" {}
variable "eks_node_role_arn" {}
variable "eks_cluster_role_arn" {}
variable "cluster_AmazonEKSClusterPolicy" {}
variable "node_AmazonEKSWorkerNodePolicy" {}
variable "node_AmazonEKS_CNI_Policy" {}
variable "node_AmazonEC2ContainerRegistryReadOnly" {}
variable "node_group_name" {}
variable "instance_type" {}
variable "desired_nodes" {}
variable "min_nodes" {}
variable "max_nodes" {}
variable "subnet_ids" {
  type = list(string)
}


module "eks" {
  source         = "../../modules/eks"
  cluster_name   = "effulgencetech-dev"
  node_group_name = "dev-nodegroup"
  instance_type  = "t2.medium"   
  desired_nodes  = 2
  min_nodes      = 1
  max_nodes      = 3
  subnet_ids     = module.vpc.vpc_private_subnets
  eks_cluster_role_arn = module.iam.eks_cluster_role_arn
  eks_node_role_arn = module.iam.eks_node_role_arn
  cluster_AmazonEKSClusterPolicy = module.iam.cluster_AmazonEKSClusterPolicy
  node_AmazonEC2ContainerRegistryReadOnly = module.iam.node_AmazonEC2ContainerRegistryReadOnly
  node_AmazonEKS_CNI_Policy = module.iam.node_AmazonEKS_CNI_Policy
  node_AmazonEKSWorkerNodePolicy = module.iam.node_AmazonEKSWorkerNodePolicy

}


# final copy eks setup

can you give me the equivalent terraform code for the eksctl code below because the eksctl is able to create the cluster and the nodegroup successfully but the terraform code does not. see below the two codes

eksctl
eksctl create cluster --name effulgencetech-dev --region us-east-1 --nodegroup-name et-nodegroup --node-type t2.medium --nodes 2 --nodes-min 1 --nodes-max 3 --managed
2025-06-14 16:08:17 [ℹ]  eksctl version 0.207.0
2025-06-14 16:08:17 [ℹ]  using region us-east-1
2025-06-14 16:08:19 [ℹ]  setting availability zones to [us-east-1b us-east-1d]
2025-06-14 16:08:19 [ℹ]  subnets for us-east-1b - public:192.168.0.0/19 private:192.168.64.0/19
2025-06-14 16:08:19 [ℹ]  subnets for us-east-1d - public:192.168.32.0/19 private:192.168.96.0/19
2025-06-14 16:08:19 [ℹ]  nodegroup "et-nodegroup" will use "" [AmazonLinux2/1.32]
2025-06-14 16:08:19 [ℹ]  using Kubernetes version 1.32
2025-06-14 16:08:19 [ℹ]  creating EKS cluster "effulgencetech-dev" in "us-east-1" region with managed nodes
2025-06-14 16:08:19 [ℹ]  will create 2 separate CloudFormation stacks for cluster itself and the initial managed nodegroup
2025-06-14 16:08:19 [ℹ]  if you encounter any issues, check CloudFormation console or try 'eksctl utils describe-stacks --region=us-east-1 --cluster=effulgencetech-dev'
2025-06-14 16:08:19 [ℹ]  Kubernetes API endpoint access will use default of {publicAccess=true, privateAccess=false} for cluster "effulgencetech-dev" in "us-east-1"
2025-06-14 16:08:19 [ℹ]  CloudWatch logging will not be enabled for cluster "effulgencetech-dev" in "us-east-1"
2025-06-14 16:08:19 [ℹ]  you can enable it with 'eksctl utils update-cluster-logging --enable-types={SPECIFY-YOUR-LOG-TYPES-HERE (e.g. all)} --region=us-east-1 --cluster=effulgencetech-dev'
2025-06-14 16:08:19 [ℹ]  default addons kube-proxy, coredns, metrics-server, vpc-cni were not specified, will install them as EKS addons
2025-06-14 16:08:19 [ℹ]
2 sequential tasks: { create cluster control plane "effulgencetech-dev",
    2 sequential sub-tasks: {
        2 sequential sub-tasks: {
            1 task: { create addons },
            wait for control plane to become ready,
        },
        create managed nodegroup "et-nodegroup",
    }
}
2025-06-14 16:08:19 [ℹ]  building cluster stack "eksctl-effulgencetech-dev-cluster"
2025-06-14 16:08:21 [ℹ]  deploying stack "eksctl-effulgencetech-dev-cluster"
2025-06-14 16:08:51 [ℹ]  waiting for CloudFormation stack "eksctl-effulgencetech-dev-cluster"
2025-06-14 16:09:40 [ℹ]  waiting for CloudFormation stack "eksctl-effulgencetech-dev-cluster"
2025-06-14 16:10:42 [ℹ]  waiting for CloudFormation stack "eksctl-effulgencetech-dev-cluster"
2025-06-14 16:11:43 [ℹ]  waiting for CloudFormation stack "eksctl-effulgencetech-dev-cluster"
2025-06-14 16:12:49 [ℹ]  waiting for CloudFormation stack "eksctl-effulgencetech-dev-cluster"
2025-06-14 16:13:50 [ℹ]  waiting for CloudFormation stack "eksctl-effulgencetech-dev-cluster"
2025-06-14 16:14:52 [ℹ]  waiting for CloudFormation stack "eksctl-effulgencetech-dev-cluster"
2025-06-14 16:15:56 [ℹ]  waiting for CloudFormation stack "eksctl-effulgencetech-dev-cluster"
2025-06-14 16:16:58 [ℹ]  waiting for CloudFormation stack "eksctl-effulgencetech-dev-cluster"
2025-06-14 16:17:05 [ℹ]  creating addon: kube-proxy
2025-06-14 16:17:05 [ℹ]  successfully created addon: kube-proxy
2025-06-14 16:17:06 [ℹ]  creating addon: coredns
2025-06-14 16:17:07 [ℹ]  successfully created addon: coredns
2025-06-14 16:17:08 [ℹ]  creating addon: metrics-server
2025-06-14 16:17:08 [ℹ]  successfully created addon: metrics-server
2025-06-14 16:17:09 [!]  recommended policies were found for "vpc-cni" addon, but since OIDC is disabled on the cluster, eksctl cannot configure the requested permissions; the recommended way to provide IAM permissions for "vpc-cni" addon is via pod identity associations; after addon creation is completed, add all recommended policies to the config file, under addon.PodIdentityAssociations, and run eksctl update addon
2025-06-14 16:17:09 [ℹ]  creating addon: vpc-cni
2025-06-14 16:17:10 [ℹ]  successfully created addon: vpc-cni

terraform eks cluster code
resource "aws_eks_cluster" "eks_cluster" {
  name     = var.cluster_name
  role_arn = var.eks_cluster_role_arn

  vpc_config {
    subnet_ids         = var.subnet_ids
    security_group_ids = [var.cluster_security_group_id]
  }

  depends_on = [var.cluster_AmazonEKSClusterPolicy]
}



resource "aws_eks_node_group" "eks_node_group" {
  cluster_name    = aws_eks_cluster.eks_cluster.name
  node_group_name = "${var.env}-nodegroup"
  node_role_arn   = var.eks_node_role_arn
  subnet_ids      = var.subnet_ids

  scaling_config {
    desired_size = var.node_desired_size
    min_size     = var.node_min_size
    max_size     = var.node_max_size
  }

  instance_types = [var.instance_type]

  # Optionally, add labels, taints, or remote access config
  # remote_access {
  #   ec2_ssh_key = var.ssh_key_namelicy,
  # }

  depends_on = [
    aws_eks_cluster.eks_cluster,
    var.node_AmazonEC2ContainerRegistryReadOnly,
    var.node_AmazonEKS_CNI_Policy,
    var.node_AmazonEKSWorkerNodePolicy
  ]
} 


ChatGPT said:
Updated saved memory
Thanks for the detailed comparison. Your eksctl command creates a fully working cluster because it:

Automatically creates public/private subnets with proper tags.

Associates required IAM roles and policies correctly.

Automatically installs EKS addons like vpc-cni, kube-proxy, and coredns.

Ensures OIDC provider is configured for IAM roles (critical for vpc-cni to work properly).

Your Terraform setup is missing key features, especially the EKS addons, OIDC, and possibly subnet tagging. Below is a corrected and eksctl-equivalent Terraform version, including EKS cluster, node group, addons, and OIDC setup.

✅ Terraform Code (Equivalent to eksctl)
1. EKS Cluster
hcl
Copy
Edit
resource "aws_eks_cluster" "eks_cluster" {
  name     = var.cluster_name
  role_arn = var.eks_cluster_role_arn

  version = "1.32"

  vpc_config {
    subnet_ids         = var.subnet_ids
    security_group_ids = [var.cluster_security_group_id]
  }

  depends_on = [
    var.cluster_AmazonEKSClusterPolicy,
    aws_iam_openid_connect_provider.oidc
  ]
}
2. OIDC Provider
hcl
Copy
Edit
data "aws_eks_cluster" "eks" {
  name = aws_eks_cluster.eks_cluster.name
}

data "aws_eks_cluster_auth" "eks" {
  name = aws_eks_cluster.eks_cluster.name
}

resource "aws_iam_openid_connect_provider" "oidc" {
  url = data.aws_eks_cluster.eks.identity[0].oidc[0].issuer
  client_id_list = ["sts.amazonaws.com"]
  thumbprint_list = [var.thumbprint]
}
Replace var.thumbprint with the correct thumbprint of the OIDC provider.

3. Managed Node Group
hcl
Copy
Edit
resource "aws_eks_node_group" "eks_node_group" {
  cluster_name    = aws_eks_cluster.eks_cluster.name
  node_group_name = "${var.env}-nodegroup"
  node_role_arn   = var.eks_node_role_arn
  subnet_ids      = var.subnet_ids

  scaling_config {
    desired_size = 2
    min_size     = 1
    max_size     = 3
  }

  instance_types = [var.instance_type]

  depends_on = [
    aws_eks_cluster.eks_cluster,
    var.node_AmazonEC2ContainerRegistryReadOnly,
    var.node_AmazonEKS_CNI_Policy,
    var.node_AmazonEKSWorkerNodePolicy
  ]
}
4. EKS Addons (CoreDNS, kube-proxy, VPC CNI, metrics-server)
hcl
Copy
Edit
resource "aws_eks_addon" "vpc_cni" {
  cluster_name = aws_eks_cluster.eks_cluster.name
  addon_name   = "vpc-cni"
}

resource "aws_eks_addon" "kube_proxy" {
  cluster_name = aws_eks_cluster.eks_cluster.name
  addon_name   = "kube-proxy"
}

resource "aws_eks_addon" "coredns" {
  cluster_name = aws_eks_cluster.eks_cluster.name
  addon_name   = "coredns"
}

resource "aws_eks_addon" "metrics_server" {
  cluster_name = aws_eks_cluster.eks_cluster.name
  addon_name   = "metrics-server"
}
🛠 Subnet Tagging Required by EKS
You must tag your private subnets like this:

hcl
Copy
Edit
resource "aws_subnet" "private" {
  # ... your subnet config ...
  tags = {
    "Name" = "private-subnet"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb" = "1"
  }
}
Without these, EKS cannot schedule workloads or initialize CNI networking.

✅ Summary
Your Terraform code needs:

OIDC provider setup.

EKS Addons block to install vpc-cni, kube-proxy, coredns, etc.

Proper subnet tagging (kubernetes.io/cluster/CLUSTER_NAME = shared).

Ensure IAM policies and roles are associated correctly with the EKS node role.

Would you like a full Terraform module structure (including VPC, roles, subnets) to mirror eksctl entirely?




# cloudformation template for eks cluster
{
	"AWSTemplateFormatVersion": "2010-09-09",
	"Description": "EKS cluster (dedicated VPC: true, dedicated IAM: true) [created and managed by eksctl]",
	"Mappings": {
		"ServicePrincipalPartitionMap": {
			"aws": {
				"EC2": "ec2.amazonaws.com",
				"EKS": "eks.amazonaws.com",
				"EKSFargatePods": "eks-fargate-pods.amazonaws.com",
				"IRA": "rolesanywhere.amazonaws.com",
				"SSM": "ssm.amazonaws.com"
			},
			"aws-cn": {
				"EC2": "ec2.amazonaws.com.cn",
				"EKS": "eks.amazonaws.com",
				"EKSFargatePods": "eks-fargate-pods.amazonaws.com"
			},
			"aws-iso": {
				"EC2": "ec2.c2s.ic.gov",
				"EKS": "eks.amazonaws.com",
				"EKSFargatePods": "eks-fargate-pods.amazonaws.com"
			},
			"aws-iso-b": {
				"EC2": "ec2.sc2s.sgov.gov",
				"EKS": "eks.amazonaws.com",
				"EKSFargatePods": "eks-fargate-pods.amazonaws.com"
			},
			"aws-iso-e": {
				"EC2": "ec2.amazonaws.com",
				"EKS": "eks.amazonaws.com",
				"EKSFargatePods": "eks-fargate-pods.amazonaws.com"
			},
			"aws-iso-f": {
				"EC2": "ec2.amazonaws.com",
				"EKS": "eks.amazonaws.com",
				"EKSFargatePods": "eks-fargate-pods.amazonaws.com"
			},
			"aws-us-gov": {
				"EC2": "ec2.amazonaws.com",
				"EKS": "eks.amazonaws.com",
				"EKSFargatePods": "eks-fargate-pods.amazonaws.com",
				"IRA": "rolesanywhere.amazonaws.com",
				"SSM": "ssm.amazonaws.com"
			}
		}
	},
	"Resources": {
		"ClusterSharedNodeSecurityGroup": {
			"Type": "AWS::EC2::SecurityGroup",
			"Properties": {
				"GroupDescription": "Communication between all nodes in the cluster",
				"Tags": [
					{
						"Key": "Name",
						"Value": {
							"Fn::Sub": "${AWS::StackName}/ClusterSharedNodeSecurityGroup"
						}
					}
				],
				"VpcId": {
					"Ref": "VPC"
				}
			}
		},
		"ControlPlane": {
			"Type": "AWS::EKS::Cluster",
			"Properties": {
				"AccessConfig": {
					"AuthenticationMode": "API_AND_CONFIG_MAP",
					"BootstrapClusterCreatorAdminPermissions": true
				},
				"BootstrapSelfManagedAddons": false,
				"KubernetesNetworkConfig": {
					"IpFamily": "ipv4"
				},
				"Name": "effulgencetech-dev",
				"ResourcesVpcConfig": {
					"EndpointPrivateAccess": false,
					"EndpointPublicAccess": true,
					"SecurityGroupIds": [
						{
							"Ref": "ControlPlaneSecurityGroup"
						}
					],
					"SubnetIds": [
						{
							"Ref": "SubnetPublicUSEAST1A"
						},
						{
							"Ref": "SubnetPublicUSEAST1D"
						},
						{
							"Ref": "SubnetPrivateUSEAST1A"
						},
						{
							"Ref": "SubnetPrivateUSEAST1D"
						}
					]
				},
				"RoleArn": {
					"Fn::GetAtt": [
						"ServiceRole",
						"Arn"
					]
				},
				"Tags": [
					{
						"Key": "Name",
						"Value": {
							"Fn::Sub": "${AWS::StackName}/ControlPlane"
						}
					}
				],
				"Version": "1.32"
			}
		},
		"ControlPlaneSecurityGroup": {
			"Type": "AWS::EC2::SecurityGroup",
			"Properties": {
				"GroupDescription": "Communication between the control plane and worker nodegroups",
				"Tags": [
					{
						"Key": "Name",
						"Value": {
							"Fn::Sub": "${AWS::StackName}/ControlPlaneSecurityGroup"
						}
					}
				],
				"VpcId": {
					"Ref": "VPC"
				}
			}
		},
		"IngressDefaultClusterToNodeSG": {
			"Type": "AWS::EC2::SecurityGroupIngress",
			"Properties": {
				"Description": "Allow managed and unmanaged nodes to communicate with each other (all ports)",
				"FromPort": 0,
				"GroupId": {
					"Ref": "ClusterSharedNodeSecurityGroup"
				},
				"IpProtocol": "-1",
				"SourceSecurityGroupId": {
					"Fn::GetAtt": [
						"ControlPlane",
						"ClusterSecurityGroupId"
					]
				},
				"ToPort": 65535
			}
		},
		"IngressInterNodeGroupSG": {
			"Type": "AWS::EC2::SecurityGroupIngress",
			"Properties": {
				"Description": "Allow nodes to communicate with each other (all ports)",
				"FromPort": 0,
				"GroupId": {
					"Ref": "ClusterSharedNodeSecurityGroup"
				},
				"IpProtocol": "-1",
				"SourceSecurityGroupId": {
					"Ref": "ClusterSharedNodeSecurityGroup"
				},
				"ToPort": 65535
			}
		},
		"IngressNodeToDefaultClusterSG": {
			"Type": "AWS::EC2::SecurityGroupIngress",
			"Properties": {
				"Description": "Allow unmanaged nodes to communicate with control plane (all ports)",
				"FromPort": 0,
				"GroupId": {
					"Fn::GetAtt": [
						"ControlPlane",
						"ClusterSecurityGroupId"
					]
				},
				"IpProtocol": "-1",
				"SourceSecurityGroupId": {
					"Ref": "ClusterSharedNodeSecurityGroup"
				},
				"ToPort": 65535
			}
		},
		"InternetGateway": {
			"Type": "AWS::EC2::InternetGateway",
			"Properties": {
				"Tags": [
					{
						"Key": "Name",
						"Value": {
							"Fn::Sub": "${AWS::StackName}/InternetGateway"
						}
					}
				]
			}
		},
		"NATGateway": {
			"Type": "AWS::EC2::NatGateway",
			"Properties": {
				"AllocationId": {
					"Fn::GetAtt": [
						"NATIP",
						"AllocationId"
					]
				},
				"SubnetId": {
					"Ref": "SubnetPublicUSEAST1A"
				},
				"Tags": [
					{
						"Key": "Name",
						"Value": {
							"Fn::Sub": "${AWS::StackName}/NATGateway"
						}
					}
				]
			}
		},
		"NATIP": {
			"Type": "AWS::EC2::EIP",
			"Properties": {
				"Domain": "vpc",
				"Tags": [
					{
						"Key": "Name",
						"Value": {
							"Fn::Sub": "${AWS::StackName}/NATIP"
						}
					}
				]
			}
		},
		"NATPrivateSubnetRouteUSEAST1A": {
			"Type": "AWS::EC2::Route",
			"Properties": {
				"DestinationCidrBlock": "0.0.0.0/0",
				"NatGatewayId": {
					"Ref": "NATGateway"
				},
				"RouteTableId": {
					"Ref": "PrivateRouteTableUSEAST1A"
				}
			}
		},
		"NATPrivateSubnetRouteUSEAST1D": {
			"Type": "AWS::EC2::Route",
			"Properties": {
				"DestinationCidrBlock": "0.0.0.0/0",
				"NatGatewayId": {
					"Ref": "NATGateway"
				},
				"RouteTableId": {
					"Ref": "PrivateRouteTableUSEAST1D"
				}
			}
		},
		"PrivateRouteTableUSEAST1A": {
			"Type": "AWS::EC2::RouteTable",
			"Properties": {
				"Tags": [
					{
						"Key": "Name",
						"Value": {
							"Fn::Sub": "${AWS::StackName}/PrivateRouteTableUSEAST1A"
						}
					}
				],
				"VpcId": {
					"Ref": "VPC"
				}
			}
		},
		"PrivateRouteTableUSEAST1D": {
			"Type": "AWS::EC2::RouteTable",
			"Properties": {
				"Tags": [
					{
						"Key": "Name",
						"Value": {
							"Fn::Sub": "${AWS::StackName}/PrivateRouteTableUSEAST1D"
						}
					}
				],
				"VpcId": {
					"Ref": "VPC"
				}
			}
		},
		"PublicRouteTable": {
			"Type": "AWS::EC2::RouteTable",
			"Properties": {
				"Tags": [
					{
						"Key": "Name",
						"Value": {
							"Fn::Sub": "${AWS::StackName}/PublicRouteTable"
						}
					}
				],
				"VpcId": {
					"Ref": "VPC"
				}
			}
		},
		"PublicSubnetRoute": {
			"Type": "AWS::EC2::Route",
			"Properties": {
				"DestinationCidrBlock": "0.0.0.0/0",
				"GatewayId": {
					"Ref": "InternetGateway"
				},
				"RouteTableId": {
					"Ref": "PublicRouteTable"
				}
			},
			"DependsOn": [
				"VPCGatewayAttachment"
			]
		},
		"RouteTableAssociationPrivateUSEAST1A": {
			"Type": "AWS::EC2::SubnetRouteTableAssociation",
			"Properties": {
				"RouteTableId": {
					"Ref": "PrivateRouteTableUSEAST1A"
				},
				"SubnetId": {
					"Ref": "SubnetPrivateUSEAST1A"
				}
			}
		},
		"RouteTableAssociationPrivateUSEAST1D": {
			"Type": "AWS::EC2::SubnetRouteTableAssociation",
			"Properties": {
				"RouteTableId": {
					"Ref": "PrivateRouteTableUSEAST1D"
				},
				"SubnetId": {
					"Ref": "SubnetPrivateUSEAST1D"
				}
			}
		},
		"RouteTableAssociationPublicUSEAST1A": {
			"Type": "AWS::EC2::SubnetRouteTableAssociation",
			"Properties": {
				"RouteTableId": {
					"Ref": "PublicRouteTable"
				},
				"SubnetId": {
					"Ref": "SubnetPublicUSEAST1A"
				}
			}
		},
		"RouteTableAssociationPublicUSEAST1D": {
			"Type": "AWS::EC2::SubnetRouteTableAssociation",
			"Properties": {
				"RouteTableId": {
					"Ref": "PublicRouteTable"
				},
				"SubnetId": {
					"Ref": "SubnetPublicUSEAST1D"
				}
			}
		},
		"ServiceRole": {
			"Type": "AWS::IAM::Role",
			"Properties": {
				"AssumeRolePolicyDocument": {
					"Statement": [
						{
							"Action": [
								"sts:AssumeRole",
								"sts:TagSession"
							],
							"Effect": "Allow",
							"Principal": {
								"Service": [
									{
										"Fn::FindInMap": [
											"ServicePrincipalPartitionMap",
											{
												"Ref": "AWS::Partition"
											},
											"EKS"
										]
									}
								]
							}
						}
					],
					"Version": "2012-10-17"
				},
				"ManagedPolicyArns": [
					{
						"Fn::Sub": "arn:${AWS::Partition}:iam::aws:policy/AmazonEKSClusterPolicy"
					},
					{
						"Fn::Sub": "arn:${AWS::Partition}:iam::aws:policy/AmazonEKSVPCResourceController"
					}
				],
				"Tags": [
					{
						"Key": "Name",
						"Value": {
							"Fn::Sub": "${AWS::StackName}/ServiceRole"
						}
					}
				]
			}
		},
		"SubnetPrivateUSEAST1A": {
			"Type": "AWS::EC2::Subnet",
			"Properties": {
				"AvailabilityZone": "us-east-1a",
				"CidrBlock": "192.168.64.0/19",
				"Tags": [
					{
						"Key": "kubernetes.io/role/internal-elb",
						"Value": "1"
					},
					{
						"Key": "Name",
						"Value": {
							"Fn::Sub": "${AWS::StackName}/SubnetPrivateUSEAST1A"
						}
					}
				],
				"VpcId": {
					"Ref": "VPC"
				}
			}
		},
		"SubnetPrivateUSEAST1D": {
			"Type": "AWS::EC2::Subnet",
			"Properties": {
				"AvailabilityZone": "us-east-1d",
				"CidrBlock": "192.168.96.0/19",
				"Tags": [
					{
						"Key": "kubernetes.io/role/internal-elb",
						"Value": "1"
					},
					{
						"Key": "Name",
						"Value": {
							"Fn::Sub": "${AWS::StackName}/SubnetPrivateUSEAST1D"
						}
					}
				],
				"VpcId": {
					"Ref": "VPC"
				}
			}
		},
		"SubnetPublicUSEAST1A": {
			"Type": "AWS::EC2::Subnet",
			"Properties": {
				"AvailabilityZone": "us-east-1a",
				"CidrBlock": "192.168.0.0/19",
				"MapPublicIpOnLaunch": true,
				"Tags": [
					{
						"Key": "kubernetes.io/role/elb",
						"Value": "1"
					},
					{
						"Key": "Name",
						"Value": {
							"Fn::Sub": "${AWS::StackName}/SubnetPublicUSEAST1A"
						}
					}
				],
				"VpcId": {
					"Ref": "VPC"
				}
			}
		},
		"SubnetPublicUSEAST1D": {
			"Type": "AWS::EC2::Subnet",
			"Properties": {
				"AvailabilityZone": "us-east-1d",
				"CidrBlock": "192.168.32.0/19",
				"MapPublicIpOnLaunch": true,
				"Tags": [
					{
						"Key": "kubernetes.io/role/elb",
						"Value": "1"
					},
					{
						"Key": "Name",
						"Value": {
							"Fn::Sub": "${AWS::StackName}/SubnetPublicUSEAST1D"
						}
					}
				],
				"VpcId": {
					"Ref": "VPC"
				}
			}
		},
		"VPC": {
			"Type": "AWS::EC2::VPC",
			"Properties": {
				"CidrBlock": "192.168.0.0/16",
				"EnableDnsHostnames": true,
				"EnableDnsSupport": true,
				"Tags": [
					{
						"Key": "Name",
						"Value": {
							"Fn::Sub": "${AWS::StackName}/VPC"
						}
					}
				]
			}
		},
		"VPCGatewayAttachment": {
			"Type": "AWS::EC2::VPCGatewayAttachment",
			"Properties": {
				"InternetGatewayId": {
					"Ref": "InternetGateway"
				},
				"VpcId": {
					"Ref": "VPC"
				}
			}
		}
	},
	"Outputs": {
		"ARN": {
			"Value": {
				"Fn::GetAtt": [
					"ControlPlane",
					"Arn"
				]
			},
			"Export": {
				"Name": {
					"Fn::Sub": "${AWS::StackName}::ARN"
				}
			}
		},
		"CertificateAuthorityData": {
			"Value": {
				"Fn::GetAtt": [
					"ControlPlane",
					"CertificateAuthorityData"
				]
			}
		},
		"ClusterSecurityGroupId": {
			"Value": {
				"Fn::GetAtt": [
					"ControlPlane",
					"ClusterSecurityGroupId"
				]
			},
			"Export": {
				"Name": {
					"Fn::Sub": "${AWS::StackName}::ClusterSecurityGroupId"
				}
			}
		},
		"ClusterStackName": {
			"Value": {
				"Ref": "AWS::StackName"
			}
		},
		"Endpoint": {
			"Value": {
				"Fn::GetAtt": [
					"ControlPlane",
					"Endpoint"
				]
			},
			"Export": {
				"Name": {
					"Fn::Sub": "${AWS::StackName}::Endpoint"
				}
			}
		},
		"FeatureNATMode": {
			"Value": "Single"
		},
		"SecurityGroup": {
			"Value": {
				"Ref": "ControlPlaneSecurityGroup"
			},
			"Export": {
				"Name": {
					"Fn::Sub": "${AWS::StackName}::SecurityGroup"
				}
			}
		},
		"ServiceRoleARN": {
			"Value": {
				"Fn::GetAtt": [
					"ServiceRole",
					"Arn"
				]
			},
			"Export": {
				"Name": {
					"Fn::Sub": "${AWS::StackName}::ServiceRoleARN"
				}
			}
		},
		"SharedNodeSecurityGroup": {
			"Value": {
				"Ref": "ClusterSharedNodeSecurityGroup"
			},
			"Export": {
				"Name": {
					"Fn::Sub": "${AWS::StackName}::SharedNodeSecurityGroup"
				}
			}
		},
		"SubnetsPrivate": {
			"Value": {
				"Fn::Join": [
					",",
					[
						{
							"Ref": "SubnetPrivateUSEAST1A"
						},
						{
							"Ref": "SubnetPrivateUSEAST1D"
						}
					]
				]
			},
			"Export": {
				"Name": {
					"Fn::Sub": "${AWS::StackName}::SubnetsPrivate"
				}
			}
		},
		"SubnetsPublic": {
			"Value": {
				"Fn::Join": [
					",",
					[
						{
							"Ref": "SubnetPublicUSEAST1A"
						},
						{
							"Ref": "SubnetPublicUSEAST1D"
						}
					]
				]
			},
			"Export": {
				"Name": {
					"Fn::Sub": "${AWS::StackName}::SubnetsPublic"
				}
			}
		},
		"VPC": {
			"Value": {
				"Ref": "VPC"
			},
			"Export": {
				"Name": {
					"Fn::Sub": "${AWS::StackName}::VPC"
				}
			}
		}
	}
}

# cloudformation template for nodegroup creation
{
  "AWSTemplateFormatVersion": "2010-09-09",
  "Description": "EKS Managed Nodes (SSH access: false) [created by eksctl]",
  "Mappings": {
    "ServicePrincipalPartitionMap": {
      "aws": {
        "EC2": "ec2.amazonaws.com",
        "EKS": "eks.amazonaws.com",
        "EKSFargatePods": "eks-fargate-pods.amazonaws.com",
        "IRA": "rolesanywhere.amazonaws.com",
        "SSM": "ssm.amazonaws.com"
      },
      "aws-cn": {
        "EC2": "ec2.amazonaws.com.cn",
        "EKS": "eks.amazonaws.com",
        "EKSFargatePods": "eks-fargate-pods.amazonaws.com"
      },
      "aws-iso": {
        "EC2": "ec2.c2s.ic.gov",
        "EKS": "eks.amazonaws.com",
        "EKSFargatePods": "eks-fargate-pods.amazonaws.com"
      },
      "aws-iso-b": {
        "EC2": "ec2.sc2s.sgov.gov",
        "EKS": "eks.amazonaws.com",
        "EKSFargatePods": "eks-fargate-pods.amazonaws.com"
      },
      "aws-iso-e": {
        "EC2": "ec2.amazonaws.com",
        "EKS": "eks.amazonaws.com",
        "EKSFargatePods": "eks-fargate-pods.amazonaws.com"
      },
      "aws-iso-f": {
        "EC2": "ec2.amazonaws.com",
        "EKS": "eks.amazonaws.com",
        "EKSFargatePods": "eks-fargate-pods.amazonaws.com"
      },
      "aws-us-gov": {
        "EC2": "ec2.amazonaws.com",
        "EKS": "eks.amazonaws.com",
        "EKSFargatePods": "eks-fargate-pods.amazonaws.com",
        "IRA": "rolesanywhere.amazonaws.com",
        "SSM": "ssm.amazonaws.com"
      }
    }
  },
  "Resources": {
    "LaunchTemplate": {
      "Type": "AWS::EC2::LaunchTemplate",
      "Properties": {
        "LaunchTemplateData": {
          "BlockDeviceMappings": [
            {
              "DeviceName": "/dev/xvda",
              "Ebs": {
                "Iops": 3000,
                "Throughput": 125,
                "VolumeSize": 80,
                "VolumeType": "gp3"
              }
            }
          ],
          "MetadataOptions": {
            "HttpPutResponseHopLimit": 2,
            "HttpTokens": "required"
          },
          "SecurityGroupIds": [
            {
              "Fn::ImportValue": "eksctl-effulgencetech-dev-cluster::ClusterSecurityGroupId"
            }
          ],
          "TagSpecifications": [
            {
              "ResourceType": "instance",
              "Tags": [
                {
                  "Key": "Name",
                  "Value": "effulgencetech-dev-et-nodegroup-Node"
                },
                {
                  "Key": "alpha.eksctl.io/nodegroup-name",
                  "Value": "et-nodegroup"
                },
                {
                  "Key": "alpha.eksctl.io/nodegroup-type",
                  "Value": "managed"
                }
              ]
            },
            {
              "ResourceType": "volume",
              "Tags": [
                {
                  "Key": "Name",
                  "Value": "effulgencetech-dev-et-nodegroup-Node"
                },
                {
                  "Key": "alpha.eksctl.io/nodegroup-name",
                  "Value": "et-nodegroup"
                },
                {
                  "Key": "alpha.eksctl.io/nodegroup-type",
                  "Value": "managed"
                }
              ]
            },
            {
              "ResourceType": "network-interface",
              "Tags": [
                {
                  "Key": "Name",
                  "Value": "effulgencetech-dev-et-nodegroup-Node"
                },
                {
                  "Key": "alpha.eksctl.io/nodegroup-name",
                  "Value": "et-nodegroup"
                },
                {
                  "Key": "alpha.eksctl.io/nodegroup-type",
                  "Value": "managed"
                }
              ]
            }
          ]
        },
        "LaunchTemplateName": {
          "Fn::Sub": "${AWS::StackName}"
        }
      }
    },
    "ManagedNodeGroup": {
      "Type": "AWS::EKS::Nodegroup",
      "Properties": {
        "AmiType": "AL2_x86_64",
        "ClusterName": "effulgencetech-dev",
        "InstanceTypes": [
          "t2.medium"
        ],
        "Labels": {
          "alpha.eksctl.io/cluster-name": "effulgencetech-dev",
          "alpha.eksctl.io/nodegroup-name": "et-nodegroup"
        },
        "LaunchTemplate": {
          "Id": {
            "Ref": "LaunchTemplate"
          }
        },
        "NodeRole": {
          "Fn::GetAtt": [
            "NodeInstanceRole",
            "Arn"
          ]
        },
        "NodegroupName": "et-nodegroup",
        "ScalingConfig": {
          "DesiredSize": 2,
          "MaxSize": 3,
          "MinSize": 1
        },
        "Subnets": [
          "subnet-031313879e7b1038f",
          "subnet-0fe0364b288c2c996"
        ],
        "Tags": {
          "alpha.eksctl.io/nodegroup-name": "et-nodegroup",
          "alpha.eksctl.io/nodegroup-type": "managed"
        }
      }
    },
    "NodeInstanceRole": {
      "Type": "AWS::IAM::Role",
      "Properties": {
        "AssumeRolePolicyDocument": {
          "Statement": [
            {
              "Action": [
                "sts:AssumeRole"
              ],
              "Effect": "Allow",
              "Principal": {
                "Service": [
                  {
                    "Fn::FindInMap": [
                      "ServicePrincipalPartitionMap",
                      {
                        "Ref": "AWS::Partition"
                      },
                      "EC2"
                    ]
                  }
                ]
              }
            }
          ],
          "Version": "2012-10-17"
        },
        "ManagedPolicyArns": [
          {
            "Fn::Sub": "arn:${AWS::Partition}:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
          },
          {
            "Fn::Sub": "arn:${AWS::Partition}:iam::aws:policy/AmazonEKSWorkerNodePolicy"
          },
          {
            "Fn::Sub": "arn:${AWS::Partition}:iam::aws:policy/AmazonEKS_CNI_Policy"
          },
          {
            "Fn::Sub": "arn:${AWS::Partition}:iam::aws:policy/AmazonSSMManagedInstanceCore"
          }
        ],
        "Path": "/",
        "Tags": [
          {
            "Key": "Name",
            "Value": {
              "Fn::Sub": "${AWS::StackName}/NodeInstanceRole"
            }
          }
        ]
      }
    }
  }
}


# "Fn::Sub": "arn:${AWS::Partition}:iam::aws:policy/AmazonSSMManagedInstanceCore"

Key Points:
Create the EKS cluster first.

Wait for the cluster to be ready using a dummy null_resource.

Use data "aws_eks_cluster" to extract the OIDC URL after the cluster is created.

Feed this OIDC URL into the IAM module to create the IRSA role.

Pass the IRSA role ARN back into the EKS module to attach it to the vpc-cni addon.