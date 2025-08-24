# Google Secret Manager entries that hold per-service DB config used by ESO

variable "enable_gsm_db_config" {
  description = "Create per-service DB config secrets in Google Secret Manager (used by ESO)"
  type        = bool
  default     = true
}

# Identity DB config secret (JSON with keys matching Spring env names)
resource "google_secret_manager_secret" "identity_db_config" {
  count     = var.enable_gsm_db_config ? 1 : 0
  secret_id = "identity-db-config"
  replication {
    auto {}
  }
  depends_on = [google_project_service.services]
}

resource "google_secret_manager_secret_version" "identity_db_config" {
  count      = var.enable_gsm_db_config ? 1 : 0
  secret     = google_secret_manager_secret.identity_db_config[0].id
  secret_data = jsonencode({
    SPRING_DATASOURCE_URL      = "jdbc:postgresql://${google_sql_database_instance.postgres.public_ip_address}:5432/identitydb",
    SPRING_DATASOURCE_USERNAME = var.db_username,
    SPRING_DATASOURCE_PASSWORD = local.db_password_effective,
  })
  depends_on = [google_sql_database_instance.postgres]
}

# Product DB config
resource "google_secret_manager_secret" "product_db_config" {
  count     = var.enable_gsm_db_config ? 1 : 0
  secret_id = "product-db-config"
  replication {
    auto {}
  }
  depends_on = [google_project_service.services]
}
resource "google_secret_manager_secret_version" "product_db_config" {
  count       = var.enable_gsm_db_config ? 1 : 0
  secret      = google_secret_manager_secret.product_db_config[0].id
  secret_data = jsonencode({
    SPRING_DATASOURCE_URL      = "jdbc:postgresql://${google_sql_database_instance.postgres.public_ip_address}:5432/productdb",
    SPRING_DATASOURCE_USERNAME = var.db_username,
    SPRING_DATASOURCE_PASSWORD = local.db_password_effective,
  })
  depends_on = [google_sql_database_instance.postgres]
}

# Cart DB config
resource "google_secret_manager_secret" "cart_db_config" {
  count     = var.enable_gsm_db_config ? 1 : 0
  secret_id = "cart-db-config"
  replication {
    auto {}
  }
  depends_on = [google_project_service.services]
}
resource "google_secret_manager_secret_version" "cart_db_config" {
  count       = var.enable_gsm_db_config ? 1 : 0
  secret      = google_secret_manager_secret.cart_db_config[0].id
  secret_data = jsonencode({
    SPRING_DATASOURCE_URL      = "jdbc:postgresql://${google_sql_database_instance.postgres.public_ip_address}:5432/cartdb",
    SPRING_DATASOURCE_USERNAME = var.db_username,
    SPRING_DATASOURCE_PASSWORD = local.db_password_effective,
  })
  depends_on = [google_sql_database_instance.postgres]
}

# Order DB config
resource "google_secret_manager_secret" "order_db_config" {
  count     = var.enable_gsm_db_config ? 1 : 0
  secret_id = "order-db-config"
  replication {
    auto {}
  }
  depends_on = [google_project_service.services]
}
resource "google_secret_manager_secret_version" "order_db_config" {
  count       = var.enable_gsm_db_config ? 1 : 0
  secret      = google_secret_manager_secret.order_db_config[0].id
  secret_data = jsonencode({
    SPRING_DATASOURCE_URL      = "jdbc:postgresql://${google_sql_database_instance.postgres.public_ip_address}:5432/orderdb",
    SPRING_DATASOURCE_USERNAME = var.db_username,
    SPRING_DATASOURCE_PASSWORD = local.db_password_effective,
  })
  depends_on = [google_sql_database_instance.postgres]
}

# Payment DB config
resource "google_secret_manager_secret" "payment_db_config" {
  count     = var.enable_gsm_db_config ? 1 : 0
  secret_id = "payment-db-config"
  replication {
    auto {}
  }
  depends_on = [google_project_service.services]
}
resource "google_secret_manager_secret_version" "payment_db_config" {
  count       = var.enable_gsm_db_config ? 1 : 0
  secret      = google_secret_manager_secret.payment_db_config[0].id
  secret_data = jsonencode({
    SPRING_DATASOURCE_URL      = "jdbc:postgresql://${google_sql_database_instance.postgres.public_ip_address}:5432/paymentdb",
    SPRING_DATASOURCE_USERNAME = var.db_username,
    SPRING_DATASOURCE_PASSWORD = local.db_password_effective,
  })
  depends_on = [google_sql_database_instance.postgres]
}
