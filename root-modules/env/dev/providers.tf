provider "aws" {
  region  = "us-east-1"

 }

# Needed for ACM certs with CloudFront 
provider "aws" {
  alias  = "useast1"
  region = "us-east-1"
}
