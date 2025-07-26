output "cluster_name" {
  description = "EKS cluster name"
  value       = data.aws_eks_cluster.eks.name
}

output "cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = data.aws_eks_cluster.eks.endpoint
}

output "cluster_ca_certificate" {
  description = "Base64-encoded certificate authority data"
  value       = data.aws_eks_cluster.eks.certificate_authority[0].data
}

output "oidc_provider_arn" {
  value = aws_iam_openid_connect_provider.eks.arn
}
