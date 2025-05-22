output "admin_role_arn" {
  description = "ARN of the admin role"
  value       = aws_iam_role.admin_role.arn
}

output "config_role_arn" {
  description = "ARN of the config role"
  value       = aws_iam_role.config_role.arn
}

output "permission_boundary_arn" {
  description = "ARN of the permission boundary policy"
  value       = aws_iam_policy.permission_boundary.arn
}

output "policy_attachment_status" {
  value = true
}

output "grafana_role_arn" {
  description = "ARN of the Grafana role"
  value       = aws_iam_role.grafana_role.arn
  
}

output "prometheus_role_arn" {
  description = "ARN of the Prometheus role"
  value       = aws_iam_role.prometheus_role.arn
}

output "eks_cluster_role_arn" {
  value = aws_iam_role.eks_cluster_role.arn
}

output "eks_node_role_arn" {
  value = aws_iam_role.eks_node_role.arn
}

output "cluster_AmazonEKSClusterPolicy" {
  value = aws_iam_role_policy_attachment.cluster_AmazonEKSClusterPolicy
}

output "node_AmazonEKSWorkerNodePolicy" {
  value = aws_iam_role_policy_attachment.node_AmazonEKSWorkerNodePolicy
}

output "node_AmazonEKS_CNI_Policy" {
  value = aws_iam_role_policy_attachment.node_AmazonEKS_CNI_Policy
}

output "node_AmazonEC2ContainerRegistryReadOnly" {
  value = aws_iam_role_policy_attachment.node_AmazonEC2ContainerRegistryReadOnly
}

output "prometheus_role_name" {
  description = "Name of the Prometheus iam role"
  value       = aws_iam_role.prometheus_role.name
}

output "grafana_role_name" {
  description = "Name of the Grafana iam role"
  value       = aws_iam_role.grafana_role.name
}

output "grafana_instance_profile_name" {
  description = "Name of the Grafana instance profile"
  value       = aws_iam_instance_profile.grafana_instance_profile.name
}

output "prometheus_instance_profile_name" {
  description = "Name of the Prometheus instance profile"
  value       = aws_iam_instance_profile.prometheus_instance_profile.name
}

output "admin_instance_profile_name" {
  description = "Name of the admin instance profile"
  value       = aws_iam_instance_profile.admin_instance_profile.name
}

