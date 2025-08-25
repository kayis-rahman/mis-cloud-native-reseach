############################
# Cloud SQL Database Infrastructure
############################

# Generate random password for database
resource "random_password" "db" {
  length  = 16
  special = true
}

# Consolidate the DB password to a single local and store in Secret Manager
locals {
  db_password_effective = coalesce(var.db_password, random_password.db.result)
}

# Create Secret Manager secret for database password
resource "google_secret_manager_secret" "db_password" {
  secret_id = var.db_secret_id
  replication {
    auto {}
  }
  depends_on = [google_project_service.services]
}

resource "google_secret_manager_secret_version" "db_password" {
  secret      = google_secret_manager_secret.db_password.id
  secret_data = local.db_password_effective
}

# Cloud SQL PostgreSQL Instance
resource "google_sql_database_instance" "postgres" {
  name                 = "${var.project_name}-pg"
  region               = var.gcp_region
  database_version     = var.db_version
  deletion_protection  = var.enable_deletion_protection

  settings {
    tier = var.db_tier
    ip_configuration {
      ipv4_enabled = true
      authorized_networks {
        name  = "public"
        value = "0.0.0.0/0"
      }
    }
  }

  depends_on = [google_project_service.services]
}

# Individual databases per service for clearer separation
resource "google_sql_database" "db_identity" {
  name     = "identitydb"
  instance = google_sql_database_instance.postgres.name
}

resource "google_sql_database" "db_product" {
  name     = "productdb"
  instance = google_sql_database_instance.postgres.name
}

resource "google_sql_database" "db_cart" {
  name     = "cartdb"
  instance = google_sql_database_instance.postgres.name
}

resource "google_sql_database" "db_order" {
  name     = "orderdb"
  instance = google_sql_database_instance.postgres.name
}

resource "google_sql_database" "db_payment" {
  name     = "paymentdb"
  instance = google_sql_database_instance.postgres.name
}

# Database user
resource "google_sql_user" "db" {
  name     = var.db_username
  instance = google_sql_database_instance.postgres.name
  password = local.db_password_effective
}
