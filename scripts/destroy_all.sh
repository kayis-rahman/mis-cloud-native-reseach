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

# First, disable deletion protection safely
echo "[INFO] Disabling deletion protection..."
TF_VAR_enable_deletion_protection=false terraform apply -auto-approve -input=false

# Now, destroy everything
echo "[INFO] Destroying all resources..."
terraform destroy -auto-approve -input=false

popd >/dev/null

echo "[OK] Destroy completed."
