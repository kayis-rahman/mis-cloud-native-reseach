#!/usr/bin/env bash
set -euo pipefail
# Unified validation script for GCP deployment (Terraform + GKE + Helm)
# Usage:
#   scripts/validate_infra.sh [-n namespace] [-p project_id] [-r region] [-c cluster_name]
# Examples:
#   scripts/validate_infra.sh
#   scripts/validate_infra.sh -n default -p my-project -r us-central1 -c mis-cloud-native-gke

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT_DIR"

# Defaults
NAMESPACE="default"
PROJECT_ID=""
LOCATION=""
CLUSTER_NAME=""

# Parse args
while [[ $# -gt 0 ]]; do
  case "$1" in
    -n|--namespace) NAMESPACE="$2"; shift 2;;
    -p|--project) PROJECT_ID="$2"; shift 2;;
    -r|--region|--location) LOCATION="$2"; shift 2;;
    -c|--cluster) CLUSTER_NAME="$2"; shift 2;;
    -h|--help)
      echo "Usage: $0 [-n namespace] [-p project_id] [-r region] [-c cluster_name]"; exit 0;;
    *) echo "Unknown argument: $1"; exit 1;;
  esac
done

# Colors
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
pass() { echo -e "${GREEN}✔${NC} $1"; }
warn() { echo -e "${YELLOW}⚠${NC} $1"; }
fail() { echo -e "${RED}✘${NC} $1"; }
step() { echo -e "\n${YELLOW}==>${NC} $1"; }

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    fail "Missing required command: $1"; exit 1;
  fi
}

step "Checking required CLIs"
for c in gcloud terraform kubectl helm jq; do require_cmd "$c"; done
pass "All required CLIs are installed"

step "Checking gcloud auth and project"
if ! gcloud auth list --format=json | jq -e '.[0].account' >/dev/null 2>&1; then
  fail "No active gcloud account. Run: gcloud auth login"; exit 1
fi
if [[ -z "${PROJECT_ID}" ]]; then
  ACTIVE_PROJECT=$(gcloud config get-value project 2>/dev/null || true)
  PROJECT_ID="$ACTIVE_PROJECT"
fi
if [[ -z "$PROJECT_ID" ]]; then
  fail "GCP project not set. Set with: gcloud config set project <PROJECT_ID> or pass -p"; exit 1
fi
pass "Using project: $PROJECT_ID"

# Try to read terraform outputs if available
if [[ -d "terraform" ]]; then
  step "Reading Terraform outputs (if state present)"
  pushd terraform >/dev/null
  if terraform output -json >/dev/null 2>&1; then
    TF_CLUSTER=$(terraform output -raw cluster_name 2>/dev/null || true)
    TF_LOCATION=$(terraform output -raw cluster_location 2>/dev/null || true)
    TF_PROJECT=$(terraform output -raw project_id 2>/dev/null || true)
    [[ -z "$CLUSTER_NAME" && -n "$TF_CLUSTER" ]] && CLUSTER_NAME="$TF_CLUSTER"
    [[ -z "$LOCATION" && -n "$TF_LOCATION" ]] && LOCATION="$TF_LOCATION"
    [[ -z "$PROJECT_ID" && -n "$TF_PROJECT" ]] && PROJECT_ID="$TF_PROJECT"
    pass "Terraform outputs: cluster=$CLUSTER_NAME location=$LOCATION project=$PROJECT_ID"
  else
    warn "Terraform state not initialized or accessible. Skipping terraform output read."
  fi
  popd >/dev/null
fi

if [[ -z "$CLUSTER_NAME" ]]; then
  warn "Cluster name not found in terraform outputs. Defaulting to mis-cloud-native-gke"
  CLUSTER_NAME="mis-cloud-native-gke"
fi
if [[ -z "$LOCATION" ]]; then
  warn "Cluster location not found in terraform outputs. Defaulting to us-central1"
  LOCATION="us-central1"
fi

step "Verifying required APIs are enabled"
APIS=( container.googleapis.com compute.googleapis.com iam.googleapis.com sqladmin.googleapis.com artifactregistry.googleapis.com secretmanager.googleapis.com )
MISSING=()
for api in "${APIS[@]}"; do
  if ! gcloud services list --enabled --project "$PROJECT_ID" --filter="NAME:$api" --format="value(NAME)" | grep -q "$api"; then
    MISSING+=("$api")
  fi
done
if [[ ${#MISSING[@]} -gt 0 ]]; then
  warn "Missing APIs: ${MISSING[*]}"
  echo "Enable them with: gcloud services enable ${MISSING[*]} --project $PROJECT_ID"
else
  pass "All required APIs enabled"
fi

step "Fetching GKE credentials"
if gcloud container clusters get-credentials "$CLUSTER_NAME" --region "$LOCATION" --project "$PROJECT_ID" >/dev/null 2>&1; then
  pass "kubectl configured for cluster $CLUSTER_NAME in $LOCATION"
else
  fail "Failed to get GKE credentials. Verify cluster exists and your IAM permissions."; exit 1
fi

step "Kubernetes cluster reachability"
if kubectl cluster-info >/dev/null 2>&1; then pass "Cluster is reachable"; else fail "Cluster not reachable via kubectl"; exit 1; fi

step "Node and namespace checks"
kubectl get nodes -o wide || true
kubectl get ns "$NAMESPACE" >/dev/null 2>&1 && pass "Namespace $NAMESPACE exists" || warn "Namespace $NAMESPACE not found (Helm may create if configured)"

step "Helm check"
helm ls -n "$NAMESPACE" || true
if helm ls -n "$NAMESPACE" | grep -q "^mis\b"; then
  pass "Helm release 'mis' found in namespace $NAMESPACE"
else
  warn "Helm release 'mis' not found in $NAMESPACE. You may need to deploy: SERVICE=identity IMAGE=... scripts/deploy_service.sh"
fi

step "Workload health (Deployments/Pods/Services) in namespace $NAMESPACE"
kubectl get deploy -n "$NAMESPACE" || true
kubectl get pods -n "$NAMESPACE" -o wide || true
kubectl get svc -n "$NAMESPACE" || true

step "Ingress (if any)"
kubectl get ingress -n "$NAMESPACE" || true

step "Image pull secret (GHCR)"
if kubectl -n "$NAMESPACE" get secret ghcr-creds >/dev/null 2>&1; then
  pass "GHCR image pull secret 'ghcr-creds' exists in $NAMESPACE"
else
  warn "GHCR image pull secret 'ghcr-creds' not found. If using private GHCR images, run scripts/create_secrets.sh"
fi

step "Cloud SQL instance (if provisioned)"
if gcloud sql instances describe mis-cloud-native-pg --project "$PROJECT_ID" >/dev/null 2>&1; then
  pass "Cloud SQL instance mis-cloud-native-pg exists"
else
  warn "Cloud SQL instance mis-cloud-native-pg not found. If you changed project_name or disabled DB, this is expected."
fi

step "Readiness summary for known services"
for svc in cart identity order payment product api-gateway; do
  if kubectl get deploy -n "$NAMESPACE" 2>/dev/null | grep -q "mis-$svc"; then
    kubectl -n "$NAMESPACE" rollout status deploy/"mis-$svc" --timeout=20s || true
  fi
done

step "Tips"
echo "- To enable missing APIs: gcloud services enable ${MISSING[*]:-} --project $PROJECT_ID" || true
echo "- To deploy a service: SERVICE=identity IMAGE=ghcr.io/OWNER/identity:TAG scripts/deploy_service.sh"
echo "- To create GHCR pull secret: see scripts/create_secrets.sh"

echo
echo "Done"
pass "Validation completed. Review warnings above if present."