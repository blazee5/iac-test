locals {
  grafana_root_url = var.grafana_ingress_path == "/" ? "%(protocol)s://%(domain)s:%(http_port)s/" : "%(protocol)s://%(domain)s:%(http_port)s${trimsuffix(var.grafana_ingress_path, "/")}/"
}

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
        "grafana.ini" = {
          server = {
            root_url            = local.grafana_root_url
            serve_from_sub_path = var.grafana_ingress_path != "/"
          }
        }
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

resource "kubernetes_ingress_v1" "grafana" {
  count = var.grafana_ingress_enabled ? 1 : 0

  metadata {
    name      = "grafana"
    namespace = kubernetes_namespace_v1.monitoring.metadata[0].name
    labels = {
      "app.kubernetes.io/name"       = "grafana"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }

  spec {
    ingress_class_name = var.grafana_ingress_class_name == "" ? null : var.grafana_ingress_class_name

    rule {
      host = var.grafana_ingress_host == "" ? null : var.grafana_ingress_host

      http {
        path {
          path      = var.grafana_ingress_path
          path_type = "Prefix"

          backend {
            service {
              name = "${var.prometheus_release_name}-grafana"
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }

  depends_on = [helm_release.monitoring]
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
      ingress = {
        enabled   = var.app_ingress_enabled
        className = var.app_ingress_class_name
        hosts = [
          {
            host = var.app_ingress_host
            paths = [
              {
                path     = var.app_ingress_path
                pathType = "Prefix"
              }
            ]
          }
        ]
        tls = []
      }
    })
  ]

  depends_on = [helm_release.monitoring]
}
