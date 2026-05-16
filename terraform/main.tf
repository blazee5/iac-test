resource "kubernetes_namespace_v1" "app" {
  metadata {
    name = var.namespace
    labels = {
      "app.kubernetes.io/name"       = "sre-capstone"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }
}

resource "kubernetes_namespace_v1" "monitoring" {
  metadata {
    name = var.monitoring_namespace
    labels = {
      "app.kubernetes.io/name"       = "monitoring"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }
}

resource "helm_release" "monitoring" {
  name       = var.prometheus_release_name
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  version    = var.kube_prometheus_stack_chart_version
  namespace  = kubernetes_namespace_v1.monitoring.metadata[0].name

  atomic          = true
  cleanup_on_fail = true
  wait            = true
  timeout         = 600

  values = [
    yamlencode({
      grafana = {
        defaultDashboardsTimezone = "browser"
        sidecar = {
          dashboards = {
            enabled         = true
            label           = "grafana_dashboard"
            searchNamespace = "ALL"
          }
        }
      }
      prometheus = {
        prometheusSpec = {
          retention                               = var.prometheus_retention
          serviceMonitorSelectorNilUsesHelmValues = false
          ruleSelectorNilUsesHelmValues           = false
        }
      }
      alertmanager = {
        enabled = true
      }
    })
  ]

  set_sensitive {
    name  = "grafana.adminPassword"
    value = var.grafana_admin_password
  }
}

resource "helm_release" "app" {
  name      = "ecommerce-api"
  chart     = "${path.module}/../charts/ecommerce-api"
  namespace = kubernetes_namespace_v1.app.metadata[0].name

  atomic          = true
  cleanup_on_fail = true
  wait            = true
  timeout         = 300

  values = [
    yamlencode({
      replicaCount = var.app_replicas
      image = {
        repository = var.app_image_repository
        tag        = var.app_image_tag
      }
      resources = {
        requests = {
          cpu    = var.app_cpu_request
          memory = var.app_memory_request
        }
        limits = {
          cpu    = var.app_cpu_limit
          memory = var.app_memory_limit
        }
      }
      autoscaling = {
        enabled                           = true
        minReplicas                       = var.hpa_min_replicas
        maxReplicas                       = var.hpa_max_replicas
        targetCPUUtilizationPercentage    = var.hpa_cpu_average_utilization
        targetMemoryUtilizationPercentage = var.hpa_memory_average_utilization
      }
      monitoring = {
        enabled      = true
        releaseLabel = var.prometheus_release_name
      }
    })
  ]

  depends_on = [helm_release.monitoring]
}

