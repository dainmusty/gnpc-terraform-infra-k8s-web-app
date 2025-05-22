# Terraform essential commands and notes
terraform init

terraform plan

terraform apply --auto-approve

terraform destroy --auto-approve

terraform reconfigure

# Generate a terraform plan and apply targeting only specified infrastructure:
# terraform plan -target=aws_vpc.network -target=aws_efs_file_system.efs_setup

# terraform apply -target=aws_vpc.network -target=aws_efs_file_system.efs_setup


terraform/
├── modules/
│   ├── rds/
│   ├── ssm/
│   └── ...
├── envs/
│   ├── dev/
│   │   ├── main.tf
│   │   ├── data.tf      ← All data lookups (like SSM)
│   │   ├── variables.tf
│   │   └── outputs.tf


# Tflint
TFLint ruleset plugin for Terraform AWS Provider

This ruleset focus on possible errors and best practices about AWS resources. Many rules are enabled by default and warn against code that might fail when running terraform apply, or clearly unrecommened.

# Installation
You can install the plugin by adding a config to .tflint.hcl and running tflint --init:

# Installation
1. Run the command for your OS
Bash script (Linux):
curl -s https://raw.githubusercontent.com/terraform-linters/tflint/master/install_linux.sh | bash

Homebrew (macOS):
brew install tflint

Chocolatey (Windows):
choco install tflint

# Enable plugin
1. vi into a file and call it .tflint.hcl
2. paste the plugin details, save and quit
plugin "aws" {
    enabled = true
    version = "0.39.0"
    source  = "github.com/terraform-linters/tflint-ruleset-aws"
}
3. run tflint --init
It should return the output below
Installing "aws" plugin...
Installed "aws" (source: github.com/terraform-linters/tflint-ruleset-aws, version: 0.39.0) # the version will depend on the version you installed.


# iam principal variables
Value	Use Case
["ec2.amazonaws.com"]	Standard EKS worker nodes (EC2 instances)
["ssm.amazonaws.com"]	SSM-managed nodes or hybrid scenarios
["eks.amazonaws.com"]	Rare, for EKS service itself
["ec2.amazonaws.com", ...]	Multiple services (advanced use cases)


and the value for the permission boundary null means it is applied right?

GitHub Copilot
No, setting the permission boundary variable to null means no permission boundary will be applied to the IAM role.

How it works:

If you set permissions_boundary = null (or simply omit the argument), Terraform will not add a permissions boundary to the role.
If you set permissions_boundary = "arn:aws:iam::123456789012:policy/your-permission-boundary", then that boundary will be applied.
Summary:

null = No permission boundary is attached.
"arn:aws:iam::...:policy/..." = That permission boundary is attached.
If you want the permission boundary to be enforced, provide its ARN as the value. If you want no boundary, use null.


Now, the next error you're encountering:

vbnet
Copy
Edit
Error: failed to get shared config profile, default
means that Terraform is trying to use an AWS CLI profile named default, but it's either not configured or not available in the GitHub Actions runner environment.

🔍 Why This Happens
In your providers.tf, you likely have something like:

h
Copy
Edit
provider "aws" {
  profile = "default" # ⛔ This line causes the issue in CI
  region  = "us-east-1"
}
This profile = "default" assumes the presence of a shared AWS credentials profile named default in ~/.aws/credentials. That may work locally, but in GitHub Actions, AWS credentials are usually provided via environment variables like:

bash
Copy
Edit
AWS_ACCESS_KEY_ID
AWS_SECRET_ACCESS_KEY
✅ How to Fix It
✅ Option 1: Remove profile entirely (recommended for CI)
Update your providers.tf like this:

hcl
Copy
Edit
provider "aws" {
  region = "us-east-1"
}
When no profile is specified, the AWS provider will automatically use environment variables — which GitHub Actions sets from:

yaml
Copy
Edit
- name: Configure AWS Credentials
  uses: aws-actions/configure-aws-credentials@v4
  with:
    aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
    aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
    aws-region: us-east-1
🛠 Option 2: Pass a profile (not recommended in CI)
If you insist on using profile, you'd need to also configure that profile manually in GitHub Actions — but it's not the standard practice in CI/CD.