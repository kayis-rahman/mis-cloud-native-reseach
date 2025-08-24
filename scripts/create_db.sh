#!/usr/bin/env bash
set -euo pipefail
# Create Cloud SQL (instance, secret) and per-service databases.
# Usage: scripts/create_db.sh

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT_DIR/terraform"

: "${TF_VAR_gcp_project_id:?Set TF_VAR_gcp_project_id to your GCP Project ID}"

# Hint if backend not configured
if [[ ! -f "backend.tf" ]]; then
  echo "[WARN] Terraform backend (backend.tf) not found. State will be local unless you configure GCS backend."
  echo "       To create a remote state bucket and configure backend, run: scripts/bootstrap_state.sh"
fi

echo "[INFO] Initializing Terraform"
terraform init -input=false

# Fetch kube credentials (best effort) so kubernetes provider can create secrets
if command -v gcloud >/dev/null 2>&1; then
  echo "[INFO] Fetching GKE credentials (best effort)"
  set +e
  CLUSTER_NAME=$(terraform output -raw cluster_name 2>/dev/null)
  CLUSTER_LOC=$(terraform output -raw cluster_location 2>/dev/null)
  PROJECT_OUT=$(terraform output -raw project_id 2>/dev/null)
  if [[ -n "$CLUSTER_NAME" && -n "$CLUSTER_LOC" ]]; then
    gcloud container clusters get-credentials "$CLUSTER_NAME" --region "$CLUSTER_LOC" --project "${PROJECT_OUT:-$TF_VAR_gcp_project_id}" >/dev/null 2>&1
  fi
  set -e
fi

echo "[INFO] Applying DB resources (Cloud SQL + databases + secret)"
terraform apply -auto-approve \
  -target=random_password.db \
  -target=google_secret_manager_secret.db_password \
  -target=google_secret_manager_secret_version.db_password \
  -target=google_sql_database_instance.postgres \
  -target=google_sql_database.db_identity \
  -target=google_sql_database.db_product \
  -target=google_sql_database.db_cart \
  -target=google_sql_database.db_order \
  -target=google_sql_database.db_payment \
  -target=google_sql_user.db \
  -target=google_secret_manager_secret.identity_db_config \
  -target=google_secret_manager_secret_version.identity_db_config \
  -target=google_secret_manager_secret.product_db_config \
  -target=google_secret_manager_secret_version.product_db_config \
  -target=google_secret_manager_secret.cart_db_config \
  -target=google_secret_manager_secret_version.cart_db_config \
  -target=google_secret_manager_secret.order_db_config \
  -target=google_secret_manager_secret_version.order_db_config \
  -target=google_secret_manager_secret.payment_db_config \
  -target=google_secret_manager_secret_version.payment_db_config \
  -target=kubernetes_secret.db_service

terraform output -raw db_public_ip || true

echo "[INFO] DB resources created."