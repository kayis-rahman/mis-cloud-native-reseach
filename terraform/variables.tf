variable "project_name" {
  description = "Base name for resources"
  type        = string
  default     = "mis-cloud-native"
}

variable "gcp_project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "gcp_region" {
  description = "GCP region"
  type        = string
  default     = "us-central1"
}

variable "gcp_zone" {
  description = "GCP zone (for default node pool)"
  type        = string
  default     = "us-central1-a"
}

variable "network_cidr" {
  description = "CIDR block for VPC network"
  type        = string
  default     = "10.0.0.0/16"
}

variable "gke_version" {
  description = "Kubernetes version for GKE (minor version, e.g., 1.29)"
  type        = string
  default     = "1.29"
}

variable "db_name" {
  description = "Database name"
  type        = string
  default     = "misdb"
}

variable "db_username" {
  description = "Database user"
  type        = string
  default     = "misadmin"
}

variable "db_password" {
  description = "Database user password (optional). If not set, a random password will be generated and stored in Secret Manager."
  type        = string
  sensitive   = true
  default     = null
}

variable "db_tier" {
  description = "Cloud SQL machine tier (db-f1-micro, db-g1-small, db-custom-1-3840, etc.)"
  type        = string
  default     = "db-f1-micro"
}

variable "db_version" {
  description = "PostgreSQL version"
  type        = string
  default     = "POSTGRES_16"
}

variable "create_initial_helm" {
  description = "Whether to create initial Helm release for services"
  type        = bool
  default     = true
}

variable "global_image_registry" {
  description = "Optional image registry to prepend to service images (e.g., ghcr.io/OWNER)"
  type        = string
  default     = ""
}

variable "service_images" {
  description = "Map of service -> image reference (repository:tag or repository@sha)"
  type        = map(string)
  default = {
    cart     = "ghcr.io/OWNER/cart:latest"
    identity = "ghcr.io/OWNER/identity:latest"
    order    = "ghcr.io/OWNER/order:latest"
    payment  = "ghcr.io/OWNER/payment:latest"
    product  = "ghcr.io/OWNER/product:latest"
  }
}

variable "db_secret_id" {
  description = "Secret Manager secret ID to store the DB password"
  type        = string
  default     = "mis-cloud-native-db-password"
}

variable "enable_deletion_protection" {
  description = "Enable deletion protection for critical resources (GKE cluster and Cloud SQL). Set to false before terraform destroy."
  type        = bool
  default     = true
}
