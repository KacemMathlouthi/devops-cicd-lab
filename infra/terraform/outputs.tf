output "cluster_name" {
  description = "Name of the kind cluster (kubectl context will be 'kind-<cluster_name>')"
  value       = kind_cluster.this.name
}

output "namespace" {
  description = "Namespace where the application will be deployed"
  value       = kubernetes_namespace.demo.metadata[0].name
}

output "grafana_url" {
  description = "URL to reach Grafana from the host (login: admin / admin)"
  value       = "http://grafana.127-0-0-1.nip.io"
}

output "prometheus_url" {
  description = "URL to reach Prometheus from the host"
  value       = "http://prometheus.127-0-0-1.nip.io"
}

output "alertmanager_url" {
  description = "URL to reach AlertManager from the host"
  value       = "http://alertmanager.127-0-0-1.nip.io"
}
