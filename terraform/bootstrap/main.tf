terraform {
  required_version = ">= 1.5.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.43"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

provider "google" {
  project = var.gcp_project_id
  region  = var.gcp_region
}

# Provide a short random suffix if a bucket name is not explicitly provided
resource "random_id" "suffix" {
  byte_length = 2
}

locals {
  resolved_bucket_name = coalesce(
    var.bucket_name,
    "tfstate-${var.gcp_project_id}-${random_id.suffix.hex}"
  )
}

# GCS bucket for Terraform state
resource "google_storage_bucket" "tfstate" {
  name     = local.resolved_bucket_name
  location = var.bucket_location

  uniform_bucket_level_access = true

  versioning {
    enabled = true
  }

  lifecycle_rule {
    action {
      type = "Delete"
    }
    condition {
      age = 365
    }
  }

  # Optional: prevent accidental deletion of objects; comment out to allow force destroy
  force_destroy = var.force_destroy

  labels = {
    managed-by = "terraform"
    purpose    = "tfstate"
    project    = var.gcp_project_id
  }
}

output "tf_state_bucket_name" {
  description = "Name of the created GCS bucket for Terraform remote state"
  value       = google_storage_bucket.tfstate.name
}
