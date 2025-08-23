variable "project_name" {
  description = "Base name for resources"
  type        = string
  default     = "mis-cloud-native"
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "eks_version" {
  description = "Kubernetes version for EKS"
  type        = string
  default     = "1.29"
}

variable "db_name" {
  description = "Database name"
  type        = string
  default     = "misdb"
}

variable "db_username" {
  description = "Database master username"
  type        = string
  default     = "misadmin"
}

variable "db_password" {
  description = "Database master password"
  type        = string
  sensitive   = true
}

variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "db_engine_version" {
  description = "PostgreSQL engine version"
  type        = string
  default     = "16.3"
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
