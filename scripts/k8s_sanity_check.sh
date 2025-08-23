#!/usr/bin/env bash
set -euo pipefail

# Simple GKE sanity script
# Usage:
#   1) Ensure you have gcloud and kubectl installed and authenticated.
#   2) Get credentials (example):
#        gcloud container clusters get-credentials mis-cloud-native-gke \
#          --region us-central1 --project YOUR_PROJECT_ID
#   3) Run this script from the repo root:
#        scripts/k8s_sanity_check.sh

# Colors
GREEN="\033[0;32m"
RED="\033[0;31m"
YELLOW="\033[1;33m"
NC="\033[0m"

ok() { echo -e "${GREEN}[OK]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
err() { echo -e "${RED}[ERR]${NC} $*"; }

command -v kubectl >/dev/null 2>&1 || { err "kubectl is required"; exit 1; }

# Context
CTX=$(kubectl config current-context 2>/dev/null || true)
if [[ -z "${CTX}" ]]; then
  err "No current kubectl context. Run gcloud get-credentials first."
  exit 1
fi
ok "kubectl context: ${CTX}"

echo
warn "Cluster info"
kubectl cluster-info || true

echo
warn "Nodes"
kubectl get nodes -o wide || true

echo
warn "Namespaces"
kubectl get ns || true

echo
warn "System pods"
kubectl get pods -A --field-selector status.phase!=Succeeded || true

echo
warn "Default namespace services"
kubectl get svc -n default || true

echo
warn "Ingresses (all namespaces)"
kubectl get ingress -A || true

echo
ok "Sanity checks completed. Review any [WARN]/[ERR] lines above."