resource "helm_release" "kube_prometheus_stack" {
  name             = "kps"
  namespace        = "monitoring"
  create_namespace = true

  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  version    = "65.5.0"

  values = [yamlencode({
    grafana = {
      adminUser     = "admin"
      adminPassword = "admin"
      persistence = {
        enabled = false
      }
      ingress = {
        enabled          = true
        ingressClassName = "nginx"
        hosts            = ["grafana.127-0-0-1.nip.io"]
        path             = "/"
      }
      defaultDashboardsEnabled = true
    }

    prometheus = {
      prometheusSpec = {
        serviceMonitorSelectorNilUsesHelmValues = false
        podMonitorSelectorNilUsesHelmValues     = false
        ruleSelectorNilUsesHelmValues           = false
        probeSelectorNilUsesHelmValues          = false
        retention                               = "12h"
        resources = {
          requests = { cpu = "100m", memory = "256Mi" }
          limits   = { cpu = "500m", memory = "1Gi" }
        }
      }
      ingress = {
        enabled          = true
        ingressClassName = "nginx"
        hosts            = ["prometheus.127-0-0-1.nip.io"]
        paths            = ["/"]
      }
    }

    alertmanager = {
      alertmanagerSpec = {
        configSecret = "alertmanager-config"
        resources = {
          requests = { cpu = "20m", memory = "32Mi" }
          limits   = { cpu = "100m", memory = "128Mi" }
        }
        volumes = [{
          name = "resend-creds"
          secret = {
            secretName = "alertmanager-resend"
          }
        }]
        volumeMounts = [{
          name      = "resend-creds"
          mountPath = "/etc/resend"
          readOnly  = true
        }]
      }
      ingress = {
        enabled          = true
        ingressClassName = "nginx"
        hosts            = ["alertmanager.127-0-0-1.nip.io"]
        paths            = ["/"]
      }
    }

    prometheusOperator = {
      resources = {
        requests = { cpu = "50m", memory = "64Mi" }
        limits   = { cpu = "200m", memory = "256Mi" }
      }
    }
  })]

  wait    = true
  timeout = 600

  depends_on = [helm_release.ingress_nginx]
}
