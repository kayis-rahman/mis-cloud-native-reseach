variable "gcp_project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "bucket_location" {
  description = "Location for the Terraform state bucket"
  type        = string
  default     = "us-central1"  # Single region instead of multi-region
}

variable "bucket_name" {
  description = "Name for the Terraform state bucket (optional - will be auto-generated if not provided)"
  type        = string
  default     = ""
}
