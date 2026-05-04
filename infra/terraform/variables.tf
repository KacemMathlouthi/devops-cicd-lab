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
