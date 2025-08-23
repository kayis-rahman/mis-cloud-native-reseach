output "cluster_name" {
  value       = module.eks.cluster_name
  description = "EKS cluster name"
}

output "cluster_endpoint" {
  value       = data.aws_eks_cluster.this.endpoint
  description = "EKS cluster API endpoint"
}

output "db_address" {
  value       = module.db.db_instance_address
  description = "RDS endpoint address"
}

output "db_name" {
  value       = var.db_name
  description = "Database name"
}
