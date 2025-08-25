#!/usr/bin/env bash
set -euo pipefail
# Create base infra (APIs, network, GKE) — excludes Cloud SQL DBs by using Terraform targets.
# Usage: scripts/create_infra.sh

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

echo "[INFO] Applying base infra (APIs, network, GKE). This may take several minutes..."
terraform apply -auto-approve \
  -target=google_project_service.services \
  -target=google_service_account.gke_node_service_account \
  -target=google_project_iam_member.gke_node_service_account_roles \
  -target=google_compute_network.vpc \
  -target=google_compute_subnetwork.subnet \
  -target=google_compute_firewall.allow_internal \
  -target=google_compute_firewall.allow_ssh \
  -target=google_compute_firewall.allow_http_https \
  -target=google_container_cluster.gke \
  -target=google_container_node_pool.primary

# Export kubeconfig
echo "[INFO] Fetching GKE credentials"
# Try to read terraform outputs, but fall back to env vars/defaults if missing
set +e
CLUSTER_NAME=$(terraform output -raw cluster_name 2>/dev/null)
CLUSTER_LOC=$(terraform output -raw cluster_location 2>/dev/null)
PROJECT_OUT=$(terraform output -raw project_id 2>/dev/null)
set -e

# Fallbacks
CLUSTER_NAME=${CLUSTER_NAME:-mis-cloud-native-gke}
CLUSTER_LOC=${CLUSTER_LOC:-${TF_VAR_gcp_region:-us-central1}}
PROJECT_OUT=${PROJECT_OUT:-${TF_VAR_gcp_project_id}}

if [[ -z "$PROJECT_OUT" ]]; then
  echo "[ERROR] Project id not found in outputs and TF_VAR_gcp_project_id not set" >&2
  exit 1
fi

gcloud container clusters get-credentials "$CLUSTER_NAME" \
  --region "$CLUSTER_LOC" \
  --project "$PROJECT_OUT"

kubectl get nodes -o wide || true

echo "[INFO] Base infra created."