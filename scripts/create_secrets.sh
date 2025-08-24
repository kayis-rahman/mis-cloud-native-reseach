#!/usr/bin/env bash
set -euo pipefail
# Simple Terraform-only script to create/sync the GHCR imagePullSecret in Kubernetes.
# Enhanced with intelligent secret management to avoid unnecessary recreations.
#
# Usage:
#   GHCR_OWNER=<github_user_or_org> \
#   GHCR_TOKEN=<pat_with_read_packages> \
#   GHCR_TOKEN_SECRET_ID=ghcr-pat \
#   [NAMESPACE=default] [TF_DIR=terraform] \
#   scripts/create_secrets.sh
#
# Behavior:
# - Ensures the Kubernetes namespace exists.
# - Conditionally manages Secret Manager secret based on whether token is provided.
# - Runs Terraform to create/update the docker-registry secret in Kubernetes and patch the default ServiceAccount.
# - Only recreates secrets when content actually changes.

: "${GHCR_OWNER:?Set GHCR_OWNER to your GitHub username/org}"
: "${GHCR_TOKEN_SECRET_ID:?Set GHCR_TOKEN_SECRET_ID to the Secret Manager secret id (e.g., ghcr-pat)}"

NAMESPACE=${NAMESPACE:-default}
TF_DIR=${TF_DIR:-terraform}
GHCR_TOKEN=${GHCR_TOKEN:-""}

# Check if we have a token to manage
MANAGE_SECRET_VERSION=false
if [[ -n "$GHCR_TOKEN" ]]; then
  MANAGE_SECRET_VERSION=true
  echo "[INFO] GHCR token provided - will manage Secret Manager secret version"
else
  echo "[INFO] No GHCR token provided - will only read existing secret from Secret Manager"
fi

# Ensure namespace exists
kubectl get ns "$NAMESPACE" >/dev/null 2>&1 || kubectl create ns "$NAMESPACE"

# Only manage Secret Manager secret if we have a token
if [[ "$MANAGE_SECRET_VERSION" == "true" ]]; then
  echo "[INFO] Ensuring Secret Manager secret '${GHCR_TOKEN_SECRET_ID}' exists and adding version"

  # Check if secret exists
  set +e
  gcloud secrets describe "$GHCR_TOKEN_SECRET_ID" >/dev/null 2>&1
  EXISTS=$?
  set -e

  if [[ $EXISTS -ne 0 ]]; then
    echo "[INFO] Creating new Secret Manager secret: ${GHCR_TOKEN_SECRET_ID}"
    echo -n "$GHCR_TOKEN" | gcloud secrets create "$GHCR_TOKEN_SECRET_ID" --replication-policy="automatic" --data-file=-
  else
    # Check if the current secret value is different
    CURRENT_SECRET=$(gcloud secrets versions access latest --secret="$GHCR_TOKEN_SECRET_ID" 2>/dev/null || echo "")
    if [[ "$CURRENT_SECRET" != "$GHCR_TOKEN" ]]; then
      echo "[INFO] Secret value changed - adding new version to ${GHCR_TOKEN_SECRET_ID}"
      echo -n "$GHCR_TOKEN" | gcloud secrets versions add "$GHCR_TOKEN_SECRET_ID" --data-file=- >/dev/null
    else
      echo "[INFO] Secret value unchanged - skipping Secret Manager update"
    fi
  fi
else
  echo "[INFO] Skipping Secret Manager secret management (no token provided)"
fi

# Set Terraform variables
export TF_VAR_ghcr_owner="$GHCR_OWNER"
export TF_VAR_ghcr_token_secret_id="$GHCR_TOKEN_SECRET_ID"
export TF_VAR_k8s_namespace="$NAMESPACE"

# Set token variable and secret creation flag based on whether we're managing the secret
if [[ "$MANAGE_SECRET_VERSION" == "true" ]]; then
  export TF_VAR_ghcr_token="$GHCR_TOKEN"
  export TF_VAR_create_ghcr_secret=true
else
  export TF_VAR_ghcr_token=""
  export TF_VAR_create_ghcr_secret=false
fi

echo "[INFO] Running Terraform to sync Kubernetes secrets and patch ServiceAccount"
pushd "$TF_DIR" >/dev/null
terraform init -input=false
terraform apply -auto-approve
popd >/dev/null

echo "[INFO] GHCR pull secret management completed successfully"
echo "  - Namespace: ${NAMESPACE}"
echo "  - Secret ID: ${GHCR_TOKEN_SECRET_ID}"
echo "  - GHCR Owner: ${GHCR_OWNER}"
echo "  - Secret Management: $([ "$MANAGE_SECRET_VERSION" == "true" ] && echo "Active" || echo "Read-only")"
