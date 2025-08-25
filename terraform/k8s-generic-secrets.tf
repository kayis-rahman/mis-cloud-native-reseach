# Sync generic secrets from GCP Secret Manager to Kubernetes as Opaque secrets.
# Input: var.k8s_generic_secrets is a map of k8s_secret_name -> secret_id

locals {
  generic_secret_map = var.k8s_generic_secrets
}

data "google_secret_manager_secret_version" "generic" {
  for_each = local.generic_secret_map
  secret   = each.value
  version  = "latest"
  depends_on = [google_container_node_pool.primary]
}

resource "kubernetes_secret" "generic" {
  for_each = local.generic_secret_map

  metadata {
    name      = each.key
    namespace = var.k8s_namespace
  }
  type = "Opaque"
  data = {
    value = base64encode(data.google_secret_manager_secret_version.generic[each.key].secret_data)
  }

  depends_on = [google_container_node_pool.primary]
}