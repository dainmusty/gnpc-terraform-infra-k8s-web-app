variable "cluster_name" {}
variable "eks_node_role_arn" {}
variable "eks_cluster_role_arn" {}
variable "cluster_AmazonEKSClusterPolicy" {}
variable "node_AmazonEKSWorkerNodePolicy" {}
variable "node_AmazonEKS_CNI_Policy" {}
variable "node_AmazonEC2ContainerRegistryReadOnly" {}
variable "node_group_name" {}
variable "instance_type" {}
variable "desired_nodes" {}
variable "min_nodes" {}
variable "max_nodes" {}
variable "subnet_ids" {
  type = list(string)
}
