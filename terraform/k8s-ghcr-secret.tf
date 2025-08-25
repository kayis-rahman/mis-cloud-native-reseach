# Create a Kubernetes docker-registry secret for GHCR using a token stored in
# Google Secret Manager, and patch the default ServiceAccount to use it.
#
# NOTE: GHCR credentials creation has been disabled - create manually instead

locals {
  # Enabled when we have an owner and either a direct token or a Secret Manager secret id
  ghcr_enabled = false  # Disabled - create GHCR credentials manually
}

# Only read from Secret Manager if no direct token provided and secret exists
data "google_secret_manager_secret_version" "ghcr_token" {
  count      = 0  # Disabled - GHCR credentials will be created manually
  secret     = var.ghcr_token_secret_id
  version    = "latest"
  depends_on = [
    google_container_node_pool.primary,
    google_secret_manager_secret.ghcr_pat,
    google_secret_manager_secret_version.ghcr_pat
  ]
}

# Build dockerconfigjson content (raw JSON string)
locals {
  # Disabled - GHCR credentials will be created manually
  ghcr_effective_token = ""
  ghcr_dockerconfigjson = null
}

# Removed - GHCR secret will be created manually
# resource "kubernetes_secret" "ghcr_creds" {
#   # This resource has been disabled - create GHCR credentials manually
# }

# Removed - Service account patching will be done manually
# resource "null_resource" "patch_default_sa" {
#   # This resource has been disabled - patch service account manually
# }
