# Create Kubernetes Secrets per service with DB connection settings, so Helm doesn't need manual --set env.
# Secret names: db-identity, db-product, db-cart, db-order, db-payment

locals {
  db_service_names = [
    "identity",
    "product",
    "cart",
    "order",
    "payment",
  ]

  db_names_by_service = {
    identity = "identitydb"
    product  = "productdb"
    cart     = "cartdb"
    order    = "orderdb"
    payment  = "paymentdb"
  }
}

resource "kubernetes_secret" "db_service" {
  # If ESO is enabled, skip managing the identity DB secret here to avoid conflicts with ExternalSecret target
  for_each = var.create_k8s_db_secrets ? (
    var.enable_eso ? toset([for n in local.db_service_names : n if n != "identity"]) : toset(local.db_service_names)
  ) : toset([])

  metadata {
    name      = "db-${each.key}"
    namespace = var.k8s_namespace
  }
  type = "Opaque"

  data = {
    # Spring looks for these env vars by default if set
    SPRING_DATASOURCE_URL      = "jdbc:postgresql://${google_sql_database_instance.postgres.public_ip_address}:5432/${lookup(local.db_names_by_service, each.key)}"
    SPRING_DATASOURCE_USERNAME = var.db_username
    SPRING_DATASOURCE_PASSWORD = local.db_password_effective
  }

  depends_on = [
    google_container_node_pool.primary,
    google_sql_database_instance.postgres,
  ]
}
