#!/usr/bin/env bash
set -euo pipefail

# Destroy all Terraform-managed infrastructure safely.
# This script will:
#  1) Disable deletion protection on protected resources (GKE, Cloud SQL) via terraform apply
#  2) Run terraform destroy to remove all resources
#
# Requirements:
#  - Terraform >= 1.5
#  - Google Cloud auth configured (gcloud auth application-default login, or env vars in CI)
#  - Environment variables set for Terraform variables, at minimum:
#      TF_VAR_gcp_project_id
#      (optional) TF_VAR_gcp_region, TF_VAR_gcp_zone
#
# Usage:
#   scripts/destroy_all.sh
#
# Notes:
#  - This only destroys resources managed by Terraform state under ./terraform.
#  - It does not delete any remote state bucket if you use one.

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TF_DIR="${ROOT_DIR}/terraform"

command -v terraform >/dev/null 2>&1 || { echo "[ERR] Terraform is required in PATH"; exit 1; }

PROJECT_ID=${TF_VAR_gcp_project_id:-}
REGION=${TF_VAR_gcp_region:-us-central1}
ZONE=${TF_VAR_gcp_zone:-us-central1-a}

if [[ -z "${PROJECT_ID}" ]]; then
  echo "[ERR] Environment variable TF_VAR_gcp_project_id is required."
  echo "      Example: export TF_VAR_gcp_project_id=your-gcp-project"
  exit 1
fi

cat <<CONFIRM
You are about to DESTROY all Terraform-managed resources for:
  - Project: ${PROJECT_ID}
  - Region:  ${REGION}
  - Zone:    ${ZONE}

This will remove:
  - VPC and Subnet
  - GKE cluster and node pool
  - Cloud SQL instance, database, user
  - Any Helm releases created by Terraform

Type the project id (${PROJECT_ID}) to confirm:
CONFIRM

read -r INPUT
if [[ "${INPUT}" != "${PROJECT_ID}" ]]; then
  echo "[INFO] Aborted."
  exit 0
fi

pushd "${TF_DIR}" >/dev/null

# Ensure init
terraform init -input=false

# Try to fetch GKE credentials so the kubernetes provider can reach the cluster during refresh/destroy
if command -v gcloud >/dev/null 2>&1; then
  echo "[INFO] Fetching GKE credentials (best effort)"
  set +e
  CLUSTER_NAME=$(terraform output -raw cluster_name 2>/dev/null)
  CLUSTER_LOC=$(terraform output -raw cluster_location 2>/dev/null)
  PROJECT_OUT=$(terraform output -raw project_id 2>/dev/null)
  if [[ -n "$CLUSTER_NAME" && -n "$CLUSTER_LOC" ]]; then
    gcloud container clusters get-credentials "$CLUSTER_NAME" --region "$CLUSTER_LOC" --project "${PROJECT_OUT:-$PROJECT_ID}" >/dev/null 2>&1
  fi
  set -e
fi

# First, disable deletion protection safely
echo "[INFO] Disabling deletion protection..."
TF_VAR_enable_deletion_protection=false terraform apply -auto-approve -input=false -target=google_container_cluster.gke -target=google_sql_database_instance.postgres

# Proactively remove Kubernetes resources from Terraform state to avoid needing live cluster creds during destroy
set +e
K8S_RES=$(terraform state list 2>/dev/null | grep '^kubernetes_' )
set -e
if [[ -n "$K8S_RES" ]]; then
  echo "[INFO] Removing Kubernetes resources from Terraform state (they will not be deleted from the cluster explicitly):"
  echo "$K8S_RES" | while read -r addr; do
    echo "  - terraform state rm $addr"
    terraform state rm "$addr" >/dev/null 2>&1 || true
  done
fi

# Now, destroy everything
echo "[INFO] Destroying all resources..."
terraform destroy -auto-approve -input=false

popd >/dev/null

echo "[OK] Destroy completed."
