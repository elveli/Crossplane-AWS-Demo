output "cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = module.eks.cluster_endpoint
}

output "cluster_name" {
  description = "Kubernetes Cluster Name"
  value       = module.eks.cluster_name
}

output "crossplane_namespace" {
  description = "Namespace where Crossplane is installed"
  value       = helm_release.crossplane.namespace
}
