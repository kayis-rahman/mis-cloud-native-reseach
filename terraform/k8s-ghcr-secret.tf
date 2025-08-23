# Create a Kubernetes docker-registry secret for GHCR using a token stored in
# Google Secret Manager, and patch the default ServiceAccount to use it.

locals {
  # Enabled when we have an owner and either a direct token or a Secret Manager secret id
  ghcr_enabled = var.ghcr_owner != "" && (var.ghcr_token != "" || var.ghcr_token_secret_id != "")
}

# Only read from Secret Manager if no direct token provided
data "google_secret_manager_secret_version" "ghcr_token" {
  count      = (var.ghcr_token == "" && var.ghcr_token_secret_id != "" && local.ghcr_enabled) ? 1 : 0
  secret     = var.ghcr_token_secret_id
  version    = "latest"
  depends_on = [google_container_node_pool.primary]
}

# Build dockerconfigjson content (raw JSON string)
locals {
  ghcr_effective_token = var.ghcr_token != "" ? var.ghcr_token : try(data.google_secret_manager_secret_version.ghcr_token[0].secret_data, "")
  ghcr_dockerconfigjson = local.ghcr_enabled ? jsonencode({
    auths = {
      "ghcr.io" = {
        username = var.ghcr_owner
        password = local.ghcr_effective_token
        auth     = base64encode("${var.ghcr_owner}:${local.ghcr_effective_token}")
      }
    }
  }) : null
}

resource "kubernetes_secret" "ghcr_creds" {
  count = local.ghcr_enabled ? 1 : 0

  metadata {
    name      = "ghcr-creds"
    namespace = var.k8s_namespace
  }
  type = "kubernetes.io/dockerconfigjson"
  data = {
    ".dockerconfigjson" = local.ghcr_dockerconfigjson
  }

  depends_on = [google_container_node_pool.primary]
}

# Patch default service account to include the imagePullSecret
resource "null_resource" "patch_default_sa" {
  count = local.ghcr_enabled ? 1 : 0

  triggers = {
    secret_version = try(data.google_secret_manager_secret_version.ghcr_token[0].version, "latest")
  }

  provisioner "local-exec" {
    command = "kubectl -n ${var.k8s_namespace} patch serviceaccount default -p '{\"imagePullSecrets\": [{\"name\": \"ghcr-creds\"}]}'"
  }

  depends_on = [kubernetes_secret.ghcr_creds]
}