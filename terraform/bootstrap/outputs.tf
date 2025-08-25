output "tf_state_bucket_name" {
  description = "Name of the GCS bucket for Terraform state"
  value       = google_storage_bucket.terraform_state.name
}

output "tf_state_bucket_url" {
  description = "URL of the GCS bucket for Terraform state"
  value       = google_storage_bucket.terraform_state.url
}
