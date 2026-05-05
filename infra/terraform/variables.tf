variable "cluster_name" {
  description = "Name of the kind cluster"
  type        = string
  default     = "devops-cicd-lab"
}

variable "namespace" {
  description = "Kubernetes namespace where the application is deployed"
  type        = string
  default     = "demo"
}

variable "k8s_endpoint_override" {
  description = "Override for the Kubernetes API endpoint URL. Set this when terraform runs from a network where the kind-generated 127.0.0.1:<random-port> URL is not reachable (e.g. from inside the Jenkins container on the kind docker network)."
  type        = string
  default     = null
}
