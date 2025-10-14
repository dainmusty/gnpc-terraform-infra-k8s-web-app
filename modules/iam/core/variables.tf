# Variables for IAM Principals
# -----------------------
variable "prometheus_role_principals" {
  description = "List of service principals for Prometheus role"
  type        = list(string)
  default     = ["ec2.amazonaws.com"]
}

variable "grafana_role_principals" {
  description = "List of service principals for Grafana role"
  type        = list(string)
  default     = ["ec2.amazonaws.com"]
}

variable "s3_rw_role_principals" {
  description = "List of service principals for S3 RW role"
  type        = list(string)
  default     = ["ec2.amazonaws.com"]
}

variable "config_role_principals" {
  description = "List of service principals for AWS Config role"
  type        = list(string)
  default     = ["config.amazonaws.com"]
}

variable "admin_role_principals" {
  description = "List of service principals for admin role"
  type        = list(string)
  default     = ["ec2.amazonaws.com"]
}

variable "s3_full_access_role_principals" {
  description = "List of service principals for S3 Full Access role"
  type        = list(string)
  default     = ["ec2.amazonaws.com"]
}


# General Variables
# -----------------
variable "env" {
  description = "Environment"
  type = string
}

variable "company_name" {
  description = "Company that owns the Infrastructure"
  type = string
}

variable "operations_bucket_arn" {
  description = "ARN of Operations Bucket"
  type = string
}

variable "log_bucket_arn" {
  description = "ARN of the S3 bucket for S3 RW access"
  type        = string
}

variable "log_bucket_name" {
  description = "Name of the S3 bucket for VPC Flow Logs"
  type        = string
}


# Variables for EKS and Node Roles tags.
variable "node_group_role_tags" {
  description = "Tags to apply to the Node Group Role"
  type        = map(string)
  default     = {
    Environment = "Dev"
    Project     = "Startup"
  }
  
}

variable "eks_cluster_role_tags" {
  description = "Tags to apply to the EKS Cluster Role"
  type        = map(string)
  default     = {
    Environment = "Dev"
    Project     = "Startup"
  }
  
}






