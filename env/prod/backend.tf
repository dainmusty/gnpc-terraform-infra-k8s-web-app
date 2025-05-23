# terraform {
#   backend "s3" {
#     bucket         = "my-tf-state-bucket"
#     key            = "prod/terraform.tfstate"
#     region         = "us-east-1"
#     encrypt        = true
#     use_lockfile = true
#     # Native s3 locking!
#   }
# }
