# External Secrets Operator (ESO) installation and GSM integration

variable "enable_eso" {
  description = "Install External Secrets Operator and configure GSM sync for selected services"
  type        = bool
  default     = false
}

variable "eso_namespace" {
  description = "Namespace where ESO is installed"
  type        = string
  default     = "external-secrets"
}

variable "eso_gsm_key_json" {
  description = "Optional: JSON key for a GCP service account with Secret Manager access. If provided, Terraform will create the kubernetes secret 'gsm-eso-key' in k8s_namespace."
  type        = string
  sensitive   = true
  default     = ""
}

# Install ESO via Helm
resource "helm_release" "external_secrets" {
  count      = var.enable_eso ? 1 : 0
  name       = "external-secrets"
  repository = "https://charts.external-secrets.io"
  chart      = "external-secrets"
  namespace  = var.eso_namespace
  create_namespace = true

  set {
    name  = "installCRDs"
    value = "true"
  }

  depends_on = [
    google_container_node_pool.poc_pool,
  ]
}

# Create the key secret in the application namespace if json provided
resource "kubernetes_secret" "gsm_eso_key" {
  count = var.enable_eso && var.eso_gsm_key_json != "" ? 1 : 0

  metadata {
    name      = "gsm-eso-key"
    namespace = var.k8s_namespace
  }
  type = "Opaque"
  data = {
    "credentials.json" = base64encode(var.eso_gsm_key_json)
  }

  depends_on = [helm_release.external_secrets]
}

# Apply SecretStore manifest (gcpsm provider with SA key) using local-exec after ESO is up
resource "null_resource" "eso_secretstore" {
  count = var.enable_eso ? 1 : 0

  provisioner "local-exec" {
    command = <<EOT
kubectl apply -f - <<EOF
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: gcpsm-store
  namespace: ${var.k8s_namespace}
spec:
  provider:
    gcpsm:
      projectID: ${var.gcp_project_id}
      auth:
        secretRef:
          secretAccessKeySecretRef:
            name: gsm-eso-key
            key: credentials.json
EOF
EOT
  }

  depends_on = [
    helm_release.external_secrets,
    kubernetes_secret.gsm_eso_key,
  ]
}

# Create ExternalSecret for identity-db-config -> db-identity
resource "null_resource" "eso_externalsecret_identity" {
  count = var.enable_eso ? 1 : 0

  provisioner "local-exec" {
    command = <<EOT
kubectl apply -f - <<EOF
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: db-identity
  namespace: ${var.k8s_namespace}
spec:
  refreshInterval: 1m
  secretStoreRef:
    name: gcpsm-store
    kind: SecretStore
  target:
    name: db-identity
    creationPolicy: Owner
  data:
    - secretKey: SPRING_DATASOURCE_URL
      remoteRef:
        key: identity-db-config
        property: SPRING_DATASOURCE_URL
    - secretKey: SPRING_DATASOURCE_USERNAME
      remoteRef:
        key: identity-db-config
        property: SPRING_DATASOURCE_USERNAME
    - secretKey: SPRING_DATASOURCE_PASSWORD
      remoteRef:
        key: identity-db-config
        property: SPRING_DATASOURCE_PASSWORD
EOF
EOT
  }

  depends_on = [
    null_resource.eso_secretstore,
  ]
}

# ExternalSecret for product-db-config -> db-product
resource "null_resource" "eso_externalsecret_product" {
  count = var.enable_eso ? 1 : 0
  provisioner "local-exec" {
    command = <<EOT
kubectl apply -f - <<EOF
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: db-product
  namespace: ${var.k8s_namespace}
spec:
  refreshInterval: 1m
  secretStoreRef:
    name: gcpsm-store
    kind: SecretStore
  target:
    name: db-product
    creationPolicy: Owner
  data:
    - secretKey: SPRING_DATASOURCE_URL
      remoteRef:
        key: product-db-config
        property: SPRING_DATASOURCE_URL
    - secretKey: SPRING_DATASOURCE_USERNAME
      remoteRef:
        key: product-db-config
        property: SPRING_DATASOURCE_USERNAME
    - secretKey: SPRING_DATASOURCE_PASSWORD
      remoteRef:
        key: product-db-config
        property: SPRING_DATASOURCE_PASSWORD
EOF
EOT
  }
  depends_on = [null_resource.eso_secretstore]
}

# ExternalSecret for cart-db-config -> db-cart
resource "null_resource" "eso_externalsecret_cart" {
  count = var.enable_eso ? 1 : 0
  provisioner "local-exec" {
    command = <<EOT
kubectl apply -f - <<EOF
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: db-cart
  namespace: ${var.k8s_namespace}
spec:
  refreshInterval: 1m
  secretStoreRef:
    name: gcpsm-store
    kind: SecretStore
  target:
    name: db-cart
    creationPolicy: Owner
  data:
    - secretKey: SPRING_DATASOURCE_URL
      remoteRef:
        key: cart-db-config
        property: SPRING_DATASOURCE_URL
    - secretKey: SPRING_DATASOURCE_USERNAME
      remoteRef:
        key: cart-db-config
        property: SPRING_DATASOURCE_USERNAME
    - secretKey: SPRING_DATASOURCE_PASSWORD
      remoteRef:
        key: cart-db-config
        property: SPRING_DATASOURCE_PASSWORD
EOF
EOT
  }
  depends_on = [null_resource.eso_secretstore]
}

# ExternalSecret for order-db-config -> db-order
resource "null_resource" "eso_externalsecret_order" {
  count = var.enable_eso ? 1 : 0
  provisioner "local-exec" {
    command = <<EOT
kubectl apply -f - <<EOF
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: db-order
  namespace: ${var.k8s_namespace}
spec:
  refreshInterval: 1m
  secretStoreRef:
    name: gcpsm-store
    kind: SecretStore
  target:
    name: db-order
    creationPolicy: Owner
  data:
    - secretKey: SPRING_DATASOURCE_URL
      remoteRef:
        key: order-db-config
        property: SPRING_DATASOURCE_URL
    - secretKey: SPRING_DATASOURCE_USERNAME
      remoteRef:
        key: order-db-config
        property: SPRING_DATASOURCE_USERNAME
    - secretKey: SPRING_DATASOURCE_PASSWORD
      remoteRef:
        key: order-db-config
        property: SPRING_DATASOURCE_PASSWORD
EOF
EOT
  }
  depends_on = [null_resource.eso_secretstore]
}

# ExternalSecret for payment-db-config -> db-payment
resource "null_resource" "eso_externalsecret_payment" {
  count = var.enable_eso ? 1 : 0
  provisioner "local-exec" {
    command = <<EOT
kubectl apply -f - <<EOF
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: db-payment
  namespace: ${var.k8s_namespace}
spec:
  refreshInterval: 1m
  secretStoreRef:
    name: gcpsm-store
    kind: SecretStore
  target:
    name: db-payment
    creationPolicy: Owner
  data:
    - secretKey: SPRING_DATASOURCE_URL
      remoteRef:
        key: payment-db-config
        property: SPRING_DATASOURCE_URL
    - secretKey: SPRING_DATASOURCE_USERNAME
      remoteRef:
        key: payment-db-config
        property: SPRING_DATASOURCE_USERNAME
    - secretKey: SPRING_DATASOURCE_PASSWORD
      remoteRef:
        key: payment-db-config
        property: SPRING_DATASOURCE_PASSWORD
EOF
EOT
  }
  depends_on = [null_resource.eso_secretstore]
}
