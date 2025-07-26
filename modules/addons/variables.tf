# Variables for EKS Addons Module
variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  
}

variable "region" {
  description = "AWS region"
  type        = string
  
}

# Alb Controller variables
variable "alb_controller_role" {
  description = "ARN of the ALB controller role"
  type        = string
}


# ArgoCD variables
variable "argocd_role_arn" {
  description = "ARN of the ArgoCD role"
  type        = string
  
}

variable "argocd_hostname" {
  description = "Hostname for ArgoCD"
  type        = string
  
}

# Grafana variables
variable "grafana_secret_name" {
  description = "Name of the Grafana secret"
  type        = string
}

variable "grafana_irsa_arn" {
  description = "ARN of the IAM role for Grafana IRSA"
  type        = string
  
}

# Slack Webhook for Alertmanager variable
variable "slack_webhook_secret_name" {
  description = "Name of the Slack Webhook secret"
  type        = string
  default     = "slack-webhook-alertmanager"
}

# Ebs variables
variable "ebs_csi_role_arn" {
  description = "ARN of the EBS CSI driver IAM role"
  type        = string
  
}
