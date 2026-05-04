output "cluster_name" {
  description = "Name of the kind cluster (kubectl context will be 'kind-<cluster_name>')"
  value       = kind_cluster.this.name
}

output "namespace" {
  description = "Namespace where the application will be deployed"
  value       = kubernetes_namespace.demo.metadata[0].name
}
