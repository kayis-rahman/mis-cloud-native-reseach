#!/usr/bin/env bash
set -euo pipefail
# Bootstrap a GCS bucket for Terraform remote state and configure backend for main terraform.
# Usage:
#   TF_VAR_gcp_project_id=<project-id> [TF_VAR_bucket_location=US] [TF_VAR_bucket_name=...] ./scripts/bootstrap_state.sh
#
# This will:
# 1) Create a GCS bucket in terraform/bootstrap (local state)
# 2) Output its name and optionally create/update terraform/backend.tf from backend.tf.example
# 3) Re-initialize main terraform to use the GCS backend

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
BOOTSTRAP_DIR="$ROOT_DIR/terraform/bootstrap"
MAIN_TF_DIR="$ROOT_DIR/terraform"

: "${TF_VAR_gcp_project_id:?Set TF_VAR_gcp_project_id to your GCP Project ID}"

if [[ ! -d "$BOOTSTRAP_DIR" ]]; then
  echo "[ERR] Bootstrap directory not found: $BOOTSTRAP_DIR" >&2
  exit 1
fi

pushd "$BOOTSTRAP_DIR" >/dev/null
  echo "[INFO] Initializing bootstrap terraform"
  terraform init -input=false
  echo "[INFO] Applying bootstrap to create GCS bucket for remote state"
  terraform apply -auto-approve -input=false
  TF_STATE_BUCKET=$(terraform output -raw tf_state_bucket_name)
  echo "[OK] Created/ensured state bucket: $TF_STATE_BUCKET"
popd >/dev/null

# Create backend.tf from example if not present
if [[ ! -f "$MAIN_TF_DIR/backend.tf" ]]; then
  if [[ -f "$MAIN_TF_DIR/backend.tf.example" ]]; then
    echo "[INFO] Creating backend.tf from backend.tf.example"
    cp "$MAIN_TF_DIR/backend.tf.example" "$MAIN_TF_DIR/backend.tf"
  else
    echo "[ERR] backend.tf.example not found in $MAIN_TF_DIR; cannot proceed." >&2
    exit 1
  fi
fi

# Replace placeholder bucket name
if grep -q "REPLACE_WITH_TF_STATE_BUCKET_NAME" "$MAIN_TF_DIR/backend.tf"; then
  echo "[INFO] Setting bucket name in backend.tf"
  sed -i '' -e "s/REPLACE_WITH_TF_STATE_BUCKET_NAME/${TF_STATE_BUCKET}/g" "$MAIN_TF_DIR/backend.tf" 2>/dev/null || \
  sed -i -e "s/REPLACE_WITH_TF_STATE_BUCKET_NAME/${TF_STATE_BUCKET}/g" "$MAIN_TF_DIR/backend.tf"
else
  echo "[INFO] backend.tf already has a bucket configured; leaving as is"
fi

# Initialize main terraform with (possibly) migrating state
pushd "$MAIN_TF_DIR" >/dev/null
  echo "[INFO] Initializing main terraform (migrate state if needed)"
  terraform init -migrate-state -force-copy -input=false || terraform init -input=false
popd >/dev/null

echo "[DONE] Remote state configured. Future terraform runs will use bucket: $TF_STATE_BUCKET"