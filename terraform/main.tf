############################
# Project services (APIs)
############################
resource "google_project_service" "services" {
  for_each = toset([
    "container.googleapis.com",
    "compute.googleapis.com",
    "iam.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "sqladmin.googleapis.com",
    "artifactregistry.googleapis.com",
    "secretmanager.googleapis.com",
  ])
  project              = var.gcp_project_id
  service              = each.key
  disable_on_destroy   = false
}

############################
# Networking
############################
resource "google_compute_network" "vpc" {
  name                    = "${var.project_name}-vpc"
  auto_create_subnetworks = false

  depends_on = [
    google_project_service.services,
  ]
}

resource "google_compute_subnetwork" "subnet" {
  name          = "${var.project_name}-subnet"
  ip_cidr_range = var.network_cidr
  region        = var.gcp_region
  network       = google_compute_network.vpc.id

  secondary_ip_range {
    range_name    = "pods"
    ip_cidr_range = "10.4.0.0/14"
  }
  secondary_ip_range {
    range_name    = "services"
    ip_cidr_range = "10.8.0.0/20"
  }

  depends_on = [
    google_project_service.services,
  ]
}

############################
# GKE Cluster
############################
resource "google_container_cluster" "gke" {
  name                     = "${var.project_name}-gke"
  location                 = var.gcp_region
  network                  = google_compute_network.vpc.self_link
  subnetwork               = google_compute_subnetwork.subnet.self_link
  remove_default_node_pool = true
  initial_node_count       = 1
  deletion_protection      = var.enable_deletion_protection

  release_channel {
    channel = "REGULAR"
  }

  ip_allocation_policy {
    cluster_secondary_range_name  = "pods"
    services_secondary_range_name = "services"
  }

  master_auth {
    client_certificate_config {
      issue_client_certificate = false
    }
  }

  depends_on = [google_project_service.services]
}

resource "google_container_node_pool" "primary" {
  name       = "primary-pool"
  location   = var.gcp_region
  cluster    = google_container_cluster.gke.name
  node_count = 1

  node_config {
    machine_type = "e2-medium"
    disk_size_gb = 30
    disk_type    = "pd-standard"
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform",
    ]
    labels = {
      env = "prod"
    }
    metadata = {
      disable-legacy-endpoints = "true"
    }
  }
}

############################
# Cloud SQL (PostgreSQL) example dependency
############################
resource "random_password" "db" {
  length  = 16
  special = true
}

# Consolidate the DB password to a single local and store in Secret Manager
locals {
  db_password_effective = coalesce(var.db_password, random_password.db.result)
}

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

# Instance
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

# Database and user
resource "google_sql_database" "db" {
  name     = var.db_name
  instance = google_sql_database_instance.postgres.name
}

# Additional databases per service for clearer separation
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

resource "google_sql_user" "db" {
  name     = var.db_username
  instance = google_sql_database_instance.postgres.name
  password = local.db_password_effective
}

############################
# Helm bootstrapping (optional)
############################
locals {
  services = [
    "cart",
    "identity",
    "order",
    "payment",
    "product",
  ]
}

# Single release per service using the shared chart; enable only the service being deployed.
resource "helm_release" "service" {
  for_each = var.create_initial_helm ? toset(local.services) : toset([])

  name       = each.key
  repository = null
  chart      = "../helm/mis-cloud-native"
  namespace  = "default"
  create_namespace = false

  # Only enable this service in the values map
  set {
    name  = "services.${each.key}.enabled"
    value = "true"
  }

  # Set image to either global registry + service-image or provided full ref
  dynamic "set" {
    for_each = var.global_image_registry != "" ? [1] : []
    content {
      name  = "global.imageRegistry"
      value = var.global_image_registry
    }
  }

  set {
    name  = "services.${each.key}.image"
    value = lookup(var.service_images, each.key, "")
  }

  depends_on = [
    google_container_node_pool.primary,
  ]
}
