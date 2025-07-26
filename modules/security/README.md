# Terraform essential commands and notes
terraform init

terraform plan

terraform apply --auto-approve

terraform destroy --auto-approve

terraform reconfigure

# Generate a terraform plan and apply targeting only specified infrastructure:
# terraform plan -target=aws_vpc.network -target=aws_efs_file_system.efs_setup

# terraform apply -target=aws_vpc.network -target=aws_efs_file_system.efs_setup


Explanation of Changes:
Fixed Invalid Policy ARN:

Updated the config-role policy ARN to arn:aws:iam::aws:policy/AWSConfigRole.
Added S3 Bucket Policy:

Added an aws_s3_bucket_policy resource to allow AWS Config to write to the S3 bucket.
Added Dependencies:

Ensured aws_config_configuration_recorder_status depends on aws_config_configuration_recorder.
Ensured aws_config_config_rule depends on aws_config_configuration_recorder_status.
Removed Invalid File Reference:

Removed invalid references to undeclared resources and files.


Yes, it is considered best practice to define security group rule details (such as ingress and egress rules) in the parent module and pass them as variables to the child module.

Why this is best practice:
Separation of concerns: The child module (security) only defines the structure and logic for creating security groups, not the specific rules.
Reusability: The same security group module can be reused in different environments (dev, staging, prod) or projects, each with different rules.
Flexibility: You can easily update rules for a specific environment without modifying the module code.
Clarity: The parent module provides a clear, at-a-glance view of all security rules applied in that environment.

This is the recommended pattern in Terraform for complex, reusable infrastructure.

Summary:
Keep the logic and structure in the child module, and the environment-specific details (like SG rules) in the parent. This is modular, maintainable, and scalable.