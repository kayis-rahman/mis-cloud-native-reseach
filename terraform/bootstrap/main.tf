# Generate a random suffix for the bucket name to ensure uniqueness
resource "random_id" "bucket_suffix" {
  byte_length = 4
}

# Create the GCS bucket for Terraform state
resource "google_storage_bucket" "terraform_state" {
  name     = var.bucket_name != "" ? var.bucket_name : "tfstate-mis-research-cloud-native-${random_id.bucket_suffix.hex}"
  location = var.bucket_location
  project  = var.gcp_project_id

  # Enable versioning for state file history
  versioning {
    enabled = true
  }

  # Temporarily remove prevent_destroy to allow recreation
  # lifecycle {
  #   prevent_destroy = true
  # }

  # Enable uniform bucket-level access
  uniform_bucket_level_access = true

  # Security settings
  public_access_prevention = "enforced"
}
