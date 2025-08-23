#!/usr/bin/env bash
set -euo pipefail
# Create base infra (APIs, network, GKE) — excludes Cloud SQL DBs by using Terraform targets.
# Usage: scripts/create_infra.sh

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT_DIR/terraform"

: "${TF_VAR_gcp_project_id:?Set TF_VAR_gcp_project_id to your GCP Project ID}"

echo "[INFO] Initializing Terraform"
terraform init -input=false

echo "[INFO] Applying base infra (APIs, network, GKE). This may take several minutes..."
terraform apply -auto-approve \
  -target=google_project_service.services \
  -target=google_compute_network.vpc \
  -target=google_compute_subnetwork.subnet \
  -target=google_container_cluster.gke \
  -target=google_container_node_pool.primary

# Export kubeconfig
echo "[INFO] Fetching GKE credentials"
gcloud container clusters get-credentials $(terraform output -raw cluster_name) \
  --region $(terraform output -raw cluster_location) \
  --project $(terraform output -raw project_id)

kubectl get nodes -o wide || true

echo "[INFO] Base infra created."