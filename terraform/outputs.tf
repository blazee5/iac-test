output "application_namespace" {
  value = kubernetes_namespace_v1.app.metadata[0].name
}

output "monitoring_namespace" {
  value = kubernetes_namespace_v1.monitoring.metadata[0].name
}

output "application_release" {
  value = helm_release.app.name
}

output "application_ingress_url" {
  value = var.app_ingress_enabled ? (var.app_ingress_host == "" ? "http://<server-ip>${var.app_ingress_path}" : "http://${var.app_ingress_host}${var.app_ingress_path}") : "application ingress disabled"
}

output "grafana_ingress_url" {
  value = var.grafana_ingress_enabled ? (var.grafana_ingress_host == "" ? "http://<server-ip>${var.grafana_ingress_path}" : "http://${var.grafana_ingress_host}${var.grafana_ingress_path}") : "grafana ingress disabled"
}
