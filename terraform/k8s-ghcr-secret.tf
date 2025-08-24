# Create a Kubernetes docker-registry secret for GHCR using a token stored in
# Google Secret Manager, and patch the default ServiceAccount to use it.

locals {
  # Enabled when we have an owner and either a direct token or a Secret Manager secret id
  ghcr_enabled = var.ghcr_owner != "" && (var.ghcr_token != "" || var.ghcr_token_secret_id != "")

  # Create a hash of the secret content to detect changes
  ghcr_content_hash = local.ghcr_enabled ? md5(local.ghcr_dockerconfigjson) : ""
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
    annotations = {
      "terraform.io/content-hash" = local.ghcr_content_hash
      "terraform.io/managed-by"   = "terraform"
    }
  }
  type = "kubernetes.io/dockerconfigjson"
  data = {
    ".dockerconfigjson" = local.ghcr_dockerconfigjson
  }

  lifecycle {
    # Only recreate if the content actually changes
    create_before_destroy = true
    replace_triggered_by = [
      local.ghcr_content_hash
    ]
    ignore_changes = [
      # Ignore metadata changes that don't affect functionality
      metadata[0].labels,
      metadata[0].resource_version,
      metadata[0].uid,
      metadata[0].generation
    ]
  }

  depends_on = [google_container_node_pool.primary]
}

# Patch default service account to include the imagePullSecret
resource "null_resource" "patch_default_sa" {
  count = local.ghcr_enabled ? 1 : 0

  triggers = {
    # Only re-run if the secret content changes or the secret is recreated
    secret_version = try(data.google_secret_manager_secret_version.ghcr_token[0].version, "latest")
    secret_hash    = local.ghcr_content_hash
    namespace      = var.k8s_namespace
    secret_name    = "ghcr-creds"
  }

  provisioner "local-exec" {
    command = <<-EOT
      # Check if service account already has the imagePullSecret
      if ! kubectl -n ${var.k8s_namespace} get serviceaccount default -o jsonpath='{.imagePullSecrets[*].name}' | grep -q "ghcr-creds"; then
        echo "Patching service account to add ghcr-creds imagePullSecret"
        kubectl -n ${var.k8s_namespace} patch serviceaccount default -p '{"imagePullSecrets": [{"name": "ghcr-creds"}]}'
      else
        echo "Service account already has ghcr-creds imagePullSecret"
      fi
    EOT
  }

  depends_on = [kubernetes_secret.ghcr_creds]
}