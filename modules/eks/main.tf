resource "aws_eks_cluster" "eks_cluster" {
  name     = var.cluster_name
  role_arn = var.eks_cluster_role_arn

  vpc_config {
    subnet_ids = var.subnet_ids
  }

  depends_on = [var.cluster_AmazonEKSClusterPolicy]
}

# resource "aws_eks_node_group" "eks_node" {
#   cluster_name    = aws_eks_cluster.eks_cluster.name
#   node_group_name = var.node_group_name
#   node_role_arn   = var.eks_node_role_arn
#   subnet_ids      = var.subnet_ids

#   scaling_config {
#     desired_size = var.desired_nodes
#     max_size     = var.max_nodes
#     min_size     = var.min_nodes
#   }

#   instance_types = [var.instance_type]

#   depends_on = [
#     aws_eks_cluster.eks_cluster,
#     var.node_AmazonEKSWorkerNodePolicy,
#     var.node_AmazonEKS_CNI_Policy,
#     var.node_AmazonEC2ContainerRegistryReadOnly,
#   ]
# }
