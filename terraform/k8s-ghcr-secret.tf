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
    annotations = {
      "terraform.io/managed-by" = "terraform"
      # Add the secret version as annotation to track changes
      "terraform.io/secret-version" = try(data.google_secret_manager_secret_version.ghcr_token[0].version, "latest")
    }
  }
  type = "kubernetes.io/dockerconfigjson"
  data = {
    ".dockerconfigjson" = local.ghcr_dockerconfigjson
  }

  lifecycle {
    # Only recreate if the content actually changes
    create_before_destroy = true
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
    # Re-run when the secret content changes or the secret is recreated
    secret_version = try(data.google_secret_manager_secret_version.ghcr_token[0].version, "latest")
    secret_id      = try(kubernetes_secret.ghcr_creds[0].metadata[0].uid, "")
    namespace      = var.k8s_namespace
    secret_name    = "ghcr-creds"
    ghcr_owner     = var.ghcr_owner
    # Force re-patch when secret data changes
    secret_data_hash = md5(local.ghcr_dockerconfigjson)
  }

  provisioner "local-exec" {
    command = <<-EOT
      echo "Ensuring service account has ghcr-creds imagePullSecret..."

      # Get current imagePullSecrets
      CURRENT_SECRETS=$(kubectl -n ${var.k8s_namespace} get serviceaccount default -o jsonpath='{.imagePullSecrets[*].name}' 2>/dev/null || echo "")

      if echo "$CURRENT_SECRETS" | grep -q "ghcr-creds"; then
        echo "Service account already has ghcr-creds imagePullSecret"
        echo "Forcing re-patch to ensure it uses the latest secret version..."
        # Remove the imagePullSecret and re-add it to ensure it's using the latest version
        kubectl -n ${var.k8s_namespace} patch serviceaccount default --type='json' \
          -p='[{"op": "remove", "path": "/imagePullSecrets"}]' || true
      fi

      echo "Adding ghcr-creds imagePullSecret to service account"
      kubectl -n ${var.k8s_namespace} patch serviceaccount default -p '{"imagePullSecrets": [{"name": "ghcr-creds"}]}'

      echo "✅ Service account patched successfully"

      # Verify the patch
      echo "Current imagePullSecrets:"
      kubectl -n ${var.k8s_namespace} get serviceaccount default -o jsonpath='{.imagePullSecrets}' || echo "None"
    EOT
  }

  depends_on = [kubernetes_secret.ghcr_creds]
}