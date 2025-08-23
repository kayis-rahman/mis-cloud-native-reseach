# Optionally create the Secret Manager secret container for GHCR token
# (value/versions are managed manually by you or via CI).

resource "google_secret_manager_secret" "ghcr_pat" {
  # Create the secret container if requested OR if a token is provided
  count = (var.ghcr_token_secret_id != "" && (var.create_ghcr_secret || var.ghcr_token != "")) ? 1 : 0

  secret_id = var.ghcr_token_secret_id
  replication {
    auto {}
  }

  depends_on = [google_project_service.services]
}

# If a token is provided, create a new secret version with its value
resource "google_secret_manager_secret_version" "ghcr_pat" {
  count  = (var.ghcr_token_secret_id != "" && var.ghcr_token != "") ? 1 : 0
  secret = google_secret_manager_secret.ghcr_pat[0].id
  secret_data = var.ghcr_token
}
