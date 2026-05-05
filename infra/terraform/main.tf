resource "kind_cluster" "this" {
  name           = var.cluster_name
  wait_for_ready = true

  kind_config {
    kind        = "Cluster"
    api_version = "kind.x-k8s.io/v1alpha4"

    node {
      role = "control-plane"

      kubeadm_config_patches = [
        "kind: InitConfiguration\nnodeRegistration:\n  kubeletExtraArgs:\n    node-labels: \"ingress-ready=true\"\n"
      ]

      extra_port_mappings {
        container_port = 80
        host_port      = 80
        protocol       = "TCP"
      }

      extra_port_mappings {
        container_port = 443
        host_port      = 443
        protocol       = "TCP"
      }
    }
  }
}

locals {
  k8s_host = coalesce(var.k8s_endpoint_override, kind_cluster.this.endpoint)
}

provider "kubernetes" {
  host                   = local.k8s_host
  cluster_ca_certificate = kind_cluster.this.cluster_ca_certificate
  client_certificate     = kind_cluster.this.client_certificate
  client_key             = kind_cluster.this.client_key
}

provider "helm" {
  kubernetes {
    host                   = local.k8s_host
    cluster_ca_certificate = kind_cluster.this.cluster_ca_certificate
    client_certificate     = kind_cluster.this.client_certificate
    client_key             = kind_cluster.this.client_key
  }
}

resource "kubernetes_namespace" "demo" {
  metadata {
    name = var.namespace
  }
}

resource "helm_release" "ingress_nginx" {
  name             = "ingress-nginx"
  namespace        = "ingress-nginx"
  create_namespace = true

  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  version    = "4.11.3"

  values = [yamlencode({
    controller = {
      nodeSelector = {
        "ingress-ready" = "true"
      }
      tolerations = [{
        key      = "node-role.kubernetes.io/control-plane"
        operator = "Equal"
        effect   = "NoSchedule"
      }]
      service = {
        type = "NodePort"
      }
      hostPort = {
        enabled = true
      }
      publishService = {
        enabled = false
      }
      extraArgs = {
        publish-status-address = "localhost"
      }
    }
  })]

  wait    = true
  timeout = 300
}
