# Optionally create the Secret Manager secret container for GHCR token
# (value/versions are managed manually by you or via CI).

# Data source to check if secret already exists - only when we actually need it
data "google_secret_manager_secret" "ghcr_pat_existing" {
  count     = 0  # Disable this data source since we're creating the secret ourselves
  secret_id = var.ghcr_token_secret_id

  # Handle case where secret doesn't exist yet
  depends_on = [google_project_service.services]
}

# Only create secret if it doesn't exist and we want to create it
resource "google_secret_manager_secret" "ghcr_pat" {
  # Create if we have a secret ID configured and want to create the secret
  count = var.ghcr_token_secret_id != "" && var.create_ghcr_secret ? 1 : 0

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

# Use the secret we created
locals {
  secret_id = length(google_secret_manager_secret.ghcr_pat) > 0 ? google_secret_manager_secret.ghcr_pat[0].id : ""
}

# If a token is provided, create a new secret version with its value
resource "google_secret_manager_secret_version" "ghcr_pat" {
  count       = (var.ghcr_token_secret_id != "" && var.ghcr_token != "" && var.create_ghcr_secret) ? 1 : 0
  secret      = google_secret_manager_secret.ghcr_pat[0].id
  secret_data = var.ghcr_token

  lifecycle {
    # Only recreate if the actual secret data changes
    create_before_destroy = true
  }

  depends_on = [google_secret_manager_secret.ghcr_pat]
}
