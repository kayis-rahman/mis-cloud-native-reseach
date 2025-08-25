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
# GKE Cluster - POC Budget Optimized
############################
resource "google_container_cluster" "gke" {
  name                     = "${var.project_name}-gke"
  location                 = var.gcp_zone  # Use single zone instead of regional to save costs
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

  # Basic cluster autoscaling for POC
  cluster_autoscaling {
    enabled = true
    resource_limits {
      resource_type = "cpu"
      minimum       = 1    # Reduced from 4
      maximum       = 6    # Reduced from 20
    }
    resource_limits {
      resource_type = "memory"
      minimum       = 4    # Reduced from 16
      maximum       = 24   # Reduced from 80
    }
  }

  # Enable workload identity for better security
  workload_identity_config {
    workload_pool = "${var.gcp_project_id}.svc.id.goog"
  }

  # Enable network policy for security
  network_policy {
    enabled = true
  }

  addons_config {
    http_load_balancing {
      disabled = false
    }
    horizontal_pod_autoscaling {
      disabled = false
    }
    network_policy_config {
      disabled = false
    }
  }

  depends_on = [google_project_service.services]
}

# Single cost-optimized node pool for all workloads
resource "google_container_node_pool" "primary" {
  name       = "primary-pool"
  location   = var.gcp_zone  # Single zone for cost savings
  cluster    = google_container_cluster.gke.name

  # Conservative auto-scaling for budget
  autoscaling {
    min_node_count = 1    # Start with just 1 node
    max_node_count = 3    # Max 3 nodes for budget control
  }

  node_config {
    machine_type = "e2-standard-2"  # 2 vCPU, 8Gi memory
    disk_size_gb = 30              # Increased for better performance
    disk_type    = "pd-ssd"        # SSD for performance

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform",
    ]

    labels = {
      env        = var.environment
      node-type  = "performance-optimized"
      pool       = "primary-pool"
    }

    metadata = {
      disable-legacy-endpoints = "true"
    }

    # Enable workload identity
    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    taint {
      key    = "dedicated"
      value  = "poc"
      effect = "NO_SCHEDULE"
    }
  }

  # Upgrade settings for better reliability
  upgrade_settings {
    max_surge       = 1
    max_unavailable = 0
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  depends_on = [google_container_cluster.gke]
}
