# Grafana Cloud credentials in Google Secret Manager and synced to Kubernetes

# Variables are defined in variables.tf (see grafana_* vars).

#############################################
# Google Secret Manager: Secrets & Versions #
#############################################

resource "google_secret_manager_secret" "grafana_cloud_stack_id" {
  secret_id  = var.grafana_cloud_stack_id_secret_id
  replication {
    automatic = true
  }
  labels = {
    managed_by = "terraform"
    purpose    = "grafana_cloud"
  }
  depends_on = [google_project_service.services]
}

resource "google_secret_manager_secret" "grafana_cloud_api_key" {
  secret_id  = var.grafana_cloud_api_key_secret_id
  replication {
    automatic = true
  }
  labels = {
    managed_by = "terraform"
    purpose    = "grafana_cloud"
  }
  depends_on = [google_project_service.services]
}

# Only create versions when values are provided via tfvars
resource "google_secret_manager_secret_version" "grafana_cloud_stack_id" {
  count       = var.grafana_cloud_stack_id != null && var.grafana_cloud_stack_id != "" ? 1 : 0
  secret      = google_secret_manager_secret.grafana_cloud_stack_id.id
  secret_data = var.grafana_cloud_stack_id
}

resource "google_secret_manager_secret_version" "grafana_cloud_api_key" {
  count       = var.grafana_cloud_api_key != null && var.grafana_cloud_api_key != "" ? 1 : 0
  secret      = google_secret_manager_secret.grafana_cloud_api_key.id
  secret_data = var.grafana_cloud_api_key
}

#############################################
# Read latest versions to sync into K8s     #
#############################################

data "google_secret_manager_secret_version" "grafana_cloud_stack_id_latest" {
  secret  = google_secret_manager_secret.grafana_cloud_stack_id.id
  version = "latest"
  depends_on = [
    google_secret_manager_secret.grafana_cloud_stack_id,
    google_secret_manager_secret_version.grafana_cloud_stack_id,
    google_container_node_pool.primary,
  ]
}

data "google_secret_manager_secret_version" "grafana_cloud_api_key_latest" {
  secret  = google_secret_manager_secret.grafana_cloud_api_key.id
  version = "latest"
  depends_on = [
    google_secret_manager_secret.grafana_cloud_api_key,
    google_secret_manager_secret_version.grafana_cloud_api_key,
    google_container_node_pool.primary,
  ]
}

#############################################
# Kubernetes Secret with both credentials   #
#############################################

# Optionally allow toggling creation
variable "create_k8s_grafana_cloud_secret" {
  description = "Whether to create grafana-cloud-credentials Kubernetes Secret from Secret Manager"
  type        = bool
  default     = true
}

# Create the Kubernetes secret when enabled
resource "kubernetes_secret" "grafana_cloud_credentials" {
  count = var.create_k8s_grafana_cloud_secret ? 1 : 0

  metadata {
    name      = "grafana-cloud-credentials"
    namespace = var.k8s_namespace
    labels = {
      managed_by = "terraform"
    }
  }

  data = {
    stack_id = data.google_secret_manager_secret_version.grafana_cloud_stack_id_latest.secret_data
    api_key  = data.google_secret_manager_secret_version.grafana_cloud_api_key_latest.secret_data
  }

  type = "Opaque"
}
