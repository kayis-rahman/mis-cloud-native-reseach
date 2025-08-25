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

echo "[INFO] Checking for existing conflicting firewall rules..."
# Clean up any existing firewall rules that might conflict with our Terraform-managed ones
EXISTING_RULES=$(gcloud compute firewall-rules list \
  --filter="network:${TF_VAR_gcp_project_id}/global/networks/mis-cloud-native-vpc" \
  --format="value(name)" 2>/dev/null || echo "")

if [[ -n "$EXISTING_RULES" ]]; then
  echo "[INFO] Found existing firewall rules that need to be removed:"
  echo "$EXISTING_RULES"

  for rule in $EXISTING_RULES; do
    echo "[INFO] Removing conflicting firewall rule: $rule"
    gcloud compute firewall-rules delete "$rule" --quiet || echo "[WARN] Failed to delete $rule or it doesn't exist"
  done
else
  echo "[INFO] No conflicting firewall rules found"
fi

echo "[INFO] Applying base infra (APIs, network, GKE). This may take several minutes..."
terraform apply -auto-approve \
  -target=google_project_service.services \
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