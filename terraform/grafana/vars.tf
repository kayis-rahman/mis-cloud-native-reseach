
variable "namespace" {
  type    = string
  default = "grafana"
}

variable "cluster_name" {
  type    = string
  default = "grafana-cluster"
}

variable "destinations_prometheus_url" {
  type    = string
  default = "https://prometheus-prod-39-prod-eu-north-0.grafana.net./api/prom/push"
}

variable "destinations_prometheus_username" {
  type    = string
  default = "2639785"
}

variable "destinations_prometheus_password" {
  type    = string
  default = "glc_eyJvIjoiMTUxODE1OCIsIm4iOiJzdGFjay0xMzU3Nzc1LWludGVncmF0aW9uLWdyYWZhbmEtYXBpLWdyYWZhbmEtYXBpIiwiayI6IkUzOXFqcTg1YTJiRzRpMXg3RUR6dDQ2bSIsIm0iOnsiciI6InByb2QtZXUtbm9ydGgtMCJ9fQ=="
}

variable "destinations_loki_url" {
  type    = string
  default = "https://logs-prod-025.grafana.net./loki/api/v1/push"
}

variable "destinations_loki_username" {
  type    = string
  default = "1315569"
}

variable "destinations_loki_password" {
  type    = string
  default = "glc_eyJvIjoiMTUxODE1OCIsIm4iOiJzdGFjay0xMzU3Nzc1LWludGVncmF0aW9uLWdyYWZhbmEtYXBpLWdyYWZhbmEtYXBpIiwiayI6IkUzOXFqcTg1YTJiRzRpMXg3RUR6dDQ2bSIsIm0iOnsiciI6InByb2QtZXUtbm9ydGgtMCJ9fQ=="
}

variable "destinations_otlp_url" {
  type    = string
  default = "https://otlp-gateway-prod-eu-north-0.grafana.net./otlp"
}

variable "destinations_otlp_username" {
  type    = string
  default = "1357775"
}

variable "destinations_otlp_password" {
  type    = string
  default = "glc_eyJvIjoiMTUxODE1OCIsIm4iOiJzdGFjay0xMzU3Nzc1LWludGVncmF0aW9uLWdyYWZhbmEtYXBpLWdyYWZhbmEtYXBpIiwiayI6IkUzOXFqcTg1YTJiRzRpMXg3RUR6dDQ2bSIsIm0iOnsiciI6InByb2QtZXUtbm9ydGgtMCJ9fQ=="
}

variable "fleetmanagement_url" {
  type    = string
  default = "https://fleet-management-prod-016.grafana.net"
}

variable "fleetmanagement_username" {
  type    = string
  default = "1357775"
}

variable "fleetmanagement_password" {
  type    = string
  default = "glc_eyJvIjoiMTUxODE1OCIsIm4iOiJzdGFjay0xMzU3Nzc1LWludGVncmF0aW9uLWdyYWZhbmEtYXBpLWdyYWZhbmEtYXBpIiwiayI6IkUzOXFqcTg1YTJiRzRpMXg3RUR6dDQ2bSIsIm0iOnsiciI6InByb2QtZXUtbm9ydGgtMCJ9fQ=="
}

# Toggle to enable/disable deploying Grafana k8s monitoring Helm chart
variable "enable_grafana_k8s_monitoring" {
  description = "Whether to deploy the Grafana k8s monitoring Helm chart"
  type        = bool
  default     = false
}

# Kubernetes kubeconfig settings for Helm provider (legacy; not used when connecting via gcloud)
variable "kubeconfig_path" {
  description = "Path to kubeconfig file used by Helm provider (legacy fallback)"
  type        = string
  default     = "~/.kube/config"
}

variable "kubeconfig_context" {
  description = "Kubeconfig context to use (legacy fallback). Leave empty to use current context"
  type        = string
  default     = ""
}

# GCP/GKE parameters for connecting Helm via gcloud/Google provider
variable "gcp_project_id" {
  description = "GCP Project ID for the target GKE cluster"
  type        = string
  default     = "mis-research-cloud-native"
}

variable "gcp_region" {
  description = "Region or location of the GKE cluster (use region for regional clusters or zone for zonal)."
  type        = string
  default     = "us-central1"
}

variable "gke_cluster_name" {
  description = "Name of the target GKE cluster to connect Helm to"
  type        = string
  default     = "mis-cloud-native-gke"
}
