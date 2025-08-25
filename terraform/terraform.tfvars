# GCP Project Configuration
gcp_project_id = "mis-research-cloud-native"

# GHCR (GitHub Container Registry) Configuration
ghcr_owner = "kayisrahman"  # Replace with your actual GitHub username/org
ghcr_token_secret_id = "ghcr-pat"
create_ghcr_secret = true
ghcr_token = "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"

# Database Configuration
db_username = "misadmin"

# Environment Configuration
environment = "development"

# Network Configuration
gcp_region = "us-central1"
network_cidr = "10.0.0.0/16"

# Kubernetes Configuration
k8s_namespace = "default"
create_k8s_db_secrets = true
