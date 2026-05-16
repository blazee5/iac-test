variable "kubeconfig_path" {
  description = "Path to kubeconfig used by Terraform and Helm."
  type        = string
  default     = "~/.kube/config"
}

variable "kube_context" {
  description = "Optional kubeconfig context."
  type        = string
  default     = ""
}

variable "namespace" {
  description = "Kubernetes namespace for the application."
  type        = string
  default     = "sre-capstone"
}

variable "monitoring_namespace" {
  description = "Kubernetes namespace for Prometheus, Grafana, and Alertmanager."
  type        = string
  default     = "monitoring"
}

variable "prometheus_release_name" {
  description = "Helm release name for kube-prometheus-stack."
  type        = string
  default     = "kube-prometheus-stack"
}

variable "kube_prometheus_stack_chart_version" {
  description = "Pinned kube-prometheus-stack chart version."
  type        = string
  default     = "75.15.1"
}

variable "grafana_admin_password" {
  description = "Initial Grafana admin password."
  type        = string
  sensitive   = true
  default     = "change-me-sre-capstone"
}

variable "prometheus_retention" {
  description = "Prometheus metric retention."
  type        = string
  default     = "7d"
}

variable "grafana_ingress_enabled" {
  description = "Expose Grafana through Kubernetes Ingress."
  type        = bool
  default     = true
}

variable "grafana_ingress_class_name" {
  description = "IngressClass used for Grafana. k3s uses traefik by default."
  type        = string
  default     = "traefik"
}

variable "grafana_ingress_host" {
  description = "Optional Grafana hostname. Empty value creates a hostless rule."
  type        = string
  default     = ""
}

variable "grafana_ingress_path" {
  description = "HTTP path for Grafana ingress."
  type        = string
  default     = "/grafana"
}

variable "app_image_repository" {
  description = "Application image repository."
  type        = string
  default     = "ghcr.io/blazee5/iac-test"
}

variable "app_image_tag" {
  description = "Application image tag."
  type        = string
  default     = "latest"
}

variable "app_replicas" {
  description = "Initial replica count when autoscaling is disabled."
  type        = number
  default     = 2
}

variable "app_cpu_request" {
  description = "Application CPU request."
  type        = string
  default     = "100m"
}

variable "app_memory_request" {
  description = "Application memory request."
  type        = string
  default     = "128Mi"
}

variable "app_cpu_limit" {
  description = "Application CPU limit."
  type        = string
  default     = "500m"
}

variable "app_memory_limit" {
  description = "Application memory limit."
  type        = string
  default     = "256Mi"
}

variable "app_ingress_enabled" {
  description = "Expose the application through Kubernetes Ingress."
  type        = bool
  default     = true
}

variable "app_ingress_class_name" {
  description = "IngressClass used for the application. k3s uses traefik by default."
  type        = string
  default     = "traefik"
}

variable "app_ingress_host" {
  description = "Optional application hostname. Empty value creates a hostless rule."
  type        = string
  default     = ""
}

variable "app_ingress_path" {
  description = "HTTP path for the application ingress."
  type        = string
  default     = "/"
}

variable "hpa_min_replicas" {
  description = "Minimum HPA replica count."
  type        = number
  default     = 2
}

variable "hpa_max_replicas" {
  description = "Maximum HPA replica count."
  type        = number
  default     = 8
}

variable "hpa_cpu_average_utilization" {
  description = "Target average CPU utilization percentage for HPA."
  type        = number
  default     = 70
}

variable "hpa_memory_average_utilization" {
  description = "Target average memory utilization percentage for HPA."
  type        = number
  default     = 80
}
