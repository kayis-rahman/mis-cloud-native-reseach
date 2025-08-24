# Create secrets for API Gateway
resource "google_secret_manager_secret" "api_gateway_security" {
  secret_id = "api-gateway-security"
  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "api_gateway_security" {
  secret = google_secret_manager_secret.api_gateway_security.id
  secret_data = jsonencode({
    apiKeys = "default-key-please-change"
  })
}

# Add the secrets to Kubernetes
resource "kubernetes_secret" "api_gateway_security" {
  metadata {
    name = "api-gateway-security"
    namespace = var.k8s_namespace
  }
  data = {
    apiKeys = jsondecode(google_secret_manager_secret_version.api_gateway_security.secret_data)["apiKeys"]
  }
  depends_on = [google_container_node_pool.primary]
}
