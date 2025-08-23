output "cluster_name" {
  description = "GKE cluster name"
  value       = google_container_cluster.gke.name
}

output "cluster_endpoint" {
  description = "GKE control plane endpoint"
  value       = google_container_cluster.gke.endpoint
}

output "db_connection_name" {
  description = "Cloud SQL connection name"
  value       = google_sql_database_instance.postgres.connection_name
}

output "db_public_ip" {
  description = "Cloud SQL public IP"
  value       = google_sql_database_instance.postgres.public_ip_address
}

output "db_credentials" {
  description = "Database username and password"
  value = {
    username = google_sql_user.db.name
    password = google_sql_user.db.password
  }
  sensitive = true
}

output "db_password_secret_id" {
  description = "Secret Manager secret resource for DB password"
  value       = google_secret_manager_secret.db_password.id
}

output "cluster_location" {
  description = "Location (region/zone) of the GKE cluster"
  value       = var.gcp_region
}

output "project_id" {
  description = "GCP Project ID used by this deployment"
  value       = var.gcp_project_id
}
