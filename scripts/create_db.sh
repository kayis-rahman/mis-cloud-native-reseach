#!/usr/bin/env bash
set -euo pipefail
# Create Cloud SQL (instance, secret) and per-service databases.
# Usage: scripts/create_db.sh

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT_DIR/terraform"

: "${TF_VAR_gcp_project_id:?Set TF_VAR_gcp_project_id to your GCP Project ID}"

echo "[INFO] Initializing Terraform"
terraform init -input=false

echo "[INFO] Applying DB resources (Cloud SQL + databases + secret)"
terraform apply -auto-approve \
  -target=random_password.db \
  -target=google_secret_manager_secret.db_password \
  -target=google_secret_manager_secret_version.db_password \
  -target=google_sql_database_instance.postgres \
  -target=google_sql_database.db \
  -target=google_sql_database.db_identity \
  -target=google_sql_database.db_product \
  -target=google_sql_database.db_cart \
  -target=google_sql_database.db_order \
  -target=google_sql_database.db_payment \
  -target=google_sql_user.db

terraform output -raw db_public_ip || true

echo "[INFO] DB resources created."