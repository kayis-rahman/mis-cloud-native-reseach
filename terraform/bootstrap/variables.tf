variable "gcp_project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "gcp_region" {
  description = "Default region (not critical for bucket)"
  type        = string
  default     = "us-central1"
}

variable "bucket_location" {
  description = "GCS bucket location/region (e.g., US, EU, us-central1)"
  type        = string
  default     = "US"
}

variable "bucket_name" {
  description = "Optional explicit bucket name (must be globally unique). If not set, a name will be generated."
  type        = string
  default     = null
}

variable "force_destroy" {
  description = "Allow destroy to delete non-empty bucket"
  type        = bool
  default     = false
}
