terraform-infra/
├── environments/
│   ├── dev/
│   │   ├── backend.tf
│   │   ├── main.tf
│   │   ├── outputs.tf
│   │   ├── providers.tf
│   │   └── terraform.tfvars
│   ├── staging/
│   └── prod/
│
├── modules/
│   ├── vpc/
│   │   ├── main.tf
│   │   ├── outputs.tf
│   │   ├── variables.tf
│   │   └── README.md
│   ├── eks/
│   │   ├── main.tf
│   │   ├── outputs.tf
│   │   ├── variables.tf
│   │   └── README.md
│   ├── ec2/
│   ├── rds/
│   ├── s3/
│   ├── iam/
│   ├── kms/
│   ├── monitoring/
│   │   ├── prometheus.tf
│   │   ├── grafana.tf
│   └── security/
│       ├── aws_config.tf
│       ├── security_group.tf
│       └── config_rules.tf
│
├── shared/
│   └── providers.tf
│
├── scripts/
│   ├── bootstrap.sh
│   ├── deploy.sh
│   └── destroy.sh
│
├── .gitignore
├── README.md
└── terragrunt.hcl (optional) 
# Question: with the structure above, would you advice i keep all bash scripts in the scripts directory? and what is best practice? 

Best Practice: Yes, keep all bash scripts under a central scripts/ directory
This is recommended for the following reasons:

💡 Why it's a good idea:

Reason	Explanation
Organization	Keeps .tf modules clean and focused on infra logic only. Bash scripts belong elsewhere.
Reusability	You might reuse grafana_userdata.sh in different environments or modules. Keeping it in scripts/ avoids duplication.
Version control clarity	Easy to see and update your automation logic (like bootstrap scripts, userdata, custom provisioning).
Security/Scan separation	You can lint, scan, or sign the script folder separately.
CI/CD friendly	Centralizing helps your pipelines (GitHub Actions, GitLab CI, etc.) pick them up easily.


# Bonus: Automate Grafana Alerts for Dashboards
Each panel can have an alert section added. Here's a JSON example to add to your dashboard definitions:

 