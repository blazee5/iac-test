output "application_namespace" {
  value = kubernetes_namespace_v1.app.metadata[0].name
}

output "monitoring_namespace" {
  value = kubernetes_namespace_v1.monitoring.metadata[0].name
}

output "application_release" {
  value = helm_release.app.name
}

output "grafana_port_forward_command" {
  value = "kubectl -n ${var.monitoring_namespace} port-forward svc/${var.prometheus_release_name}-grafana 3000:80"
}

output "prometheus_port_forward_command" {
  value = "kubectl -n ${var.monitoring_namespace} port-forward svc/${var.prometheus_release_name}-prometheus 9090:9090"
}

