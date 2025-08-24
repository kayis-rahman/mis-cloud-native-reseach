# Optionally create the Secret Manager secret container for GHCR token
# (value/versions are managed manually by you or via CI).

# Data source to check if secret already exists
data "google_secret_manager_secret" "ghcr_pat_existing" {
  count     = var.ghcr_token_secret_id != "" ? 1 : 0
  secret_id = var.ghcr_token_secret_id
}

# Only create secret if it doesn't exist
resource "google_secret_manager_secret" "ghcr_pat" {
  # Create only if secret doesn't exist and we want to create it
  count = (var.ghcr_token_secret_id != "" &&
           var.create_ghcr_secret &&
           length(data.google_secret_manager_secret.ghcr_pat_existing) == 0) ? 1 : 0

  secret_id = var.ghcr_token_secret_id
  replication {
    auto {}
  }

  lifecycle {
    # Prevent recreation unless the secret_id changes
    create_before_destroy = true
    ignore_changes = [
      # Ignore changes to labels and annotations that might be set externally
      labels,
      annotations
    ]
  }

  depends_on = [google_project_service.services]
}

# Use existing secret if available, otherwise use the one we created
locals {
  secret_id = length(data.google_secret_manager_secret.ghcr_pat_existing) > 0 ? data.google_secret_manager_secret.ghcr_pat_existing[0].id : (length(google_secret_manager_secret.ghcr_pat) > 0 ? google_secret_manager_secret.ghcr_pat[0].id : "")
}

# If a token is provided, create a new secret version with its value
resource "google_secret_manager_secret_version" "ghcr_pat" {
  count       = (var.ghcr_token_secret_id != "" && var.ghcr_token != "" && local.secret_id != "") ? 1 : 0
  secret      = local.secret_id
  secret_data = var.ghcr_token

  lifecycle {
    # Only recreate if the actual secret data changes
    create_before_destroy = true
  }
}
