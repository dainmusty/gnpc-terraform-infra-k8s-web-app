# Terraform essential commands and notes
terraform init

terraform plan

terraform apply --auto-approve

terraform destroy --auto-approve

terraform reconfigure

# Generate a terraform plan and apply targeting only specified infrastructure:
# terraform plan -target=aws_vpc.network -target=aws_efs_file_system.efs_setup

# terraform apply -target=aws_vpc.network -target=aws_efs_file_system.efs_setup


# README.md
```markdown
# S3 Bucket Module

This Terraform module creates an Amazon S3 bucket with optional versioning support.

## Inputs

| Name              | Description                          | Type          | Default  | Required |
|-------------------|--------------------------------------|---------------|----------|----------|
| bucket_name       | The name of the S3 bucket            | `string`      | n/a      | yes      |
| acl               | The canned ACL to apply              | `string`      | `private`| no       |
| versioning_enabled| Enable versioning on the bucket      | `bool`        | `false`  | no       |
| tags              | Tags to apply to the bucket          | `map(string)` | `{}`     | no       |

## Outputs

| Name         | Description                 |
|--------------|-----------------------------|
| bucket_arn   | The ARN of the bucket       |
| bucket_name  | The name of the bucket      |

## Usage

```hcl
module "s3" {
  source            = "./modules/s3"
  bucket_name       = "my-s3-bucket-name"
  acl               = "private"
  versioning_enabled = true
  tags = {
    Environment = "dev"
    Team        = "DevOps"
  }
}


module.s3.aws_s3_bucket.s3_bucket will be destroyed
  - resource "aws_s3_bucket" "s3_bucket" {
      - arn                         = "arn:aws:s3:::gnpc-dev-bucket" -> null
      - bucket                      = "gnpc-dev-bucket" -> null
      - bucket_domain_name          = "gnpc-dev-bucket.s3.amazonaws.com" -> null
      - bucket_regional_domain_name = "gnpc-dev-bucket.s3.us-east-1.amazonaws.com" -> null
      - force_destroy               = false -> null
      - hosted_zone_id              = "Z3AQBSTGFYJSTF" -> null
      - id                          = "gnpc-dev-bucket" -> null
      - object_lock_enabled         = false -> null
      - region                      = "us-east-1" -> null
      - request_payer               = "BucketOwner" -> null
      - tags                        = {
          - "Name" = "GNPC-Dev-gnpc-dev-bucket"
        } -> null
      - tags_all                    = {
          - "Name" = "GNPC-Dev-gnpc-dev-bucket"
        } -> null
        # (3 unchanged attributes hidden)

      - grant {
          - id          = "c55ad48d0b76c57ece4b7ab46630353c560493d3fd5802cc5d91aa2a2383cf59" -> null       
          - permissions = [
              - "FULL_CONTROL",
            ] -> null
          - type        = "CanonicalUser" -> null
            # (1 unchanged attribute hidden)
        }

      - server_side_encryption_configuration {
          - rule {
              - bucket_key_enabled = false -> null

              - apply_server_side_encryption_by_default {
                  - sse_algorithm     = "AES256" -> null
                    # (1 unchanged attribute hidden)
                }
            }
        }

      - versioning {
          - enabled    = false -> null
          - mfa_delete = false -> null
        }
    }


data "aws_ssm_parameter" "db_access_parameter_name" {
  name = var.db_access_parameter_name
}

data "aws_ssm_parameter" "db_secret_parameter_name" {
  name = var.db_secret_parameter_name
}

data "aws_ssm_parameter" "key_parameter_name" {
  name = var.key_parameter_name
}


data "aws_ssm_parameter" "key_name_parameter_name" {
  name = var.key_name_parameter_name
}




# modules/ssm/main.tf
resource "aws_ssm_parameter" "db_user" {
  name  = var.db_user_parameter_name
  type  = var.db_user_parameter_type
  value = var.db_user_parameter_value

}

resource "aws_ssm_parameter" "db_passwd" {
  name  = var.db_passwd_parameter_name
  type  = var.db_passwd_parameter_type
  value = var.db_passwd_parameter_value

}

resource "aws_ssm_parameter" "key_name" {
  name  = var.key_name_parameter_name
  type  = var.key_name_parameter_type
  value = var.key_name_parameter_value

}

resource "aws_ssm_parameter" "key_path" {
  name  = var.key_path_parameter_name
  type  = var.key_path_parameter_type
  value = var.key_path_parameter_value

}

module "ssm" {
  source         = "../../modules/ssm"
  db_user_parameter_name = "/db/access"
  db_user_parameter_type = "SecureString"
  db_user_parameter_value = "/db/access"

  db_passwd_parameter_name = "/db/secure/access"
  db_passwd_parameter_type = "SecureString"
  db_passwd_parameter_value = "/db/secure/access"

  key_name_parameter_name = "/kp/path"
  key_name_parameter_type = "SecureString"
  key_name_parameter_value = "/kp/path"

  
  key_path_parameter_name = "/kp/path"
  key_path_parameter_type = "SecureString"
  key_path_parameter_value = "/kp/path"

}

