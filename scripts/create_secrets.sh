#!/usr/bin/env bash
set -euo pipefail
# Simple Terraform-only script to create/sync the GHCR imagePullSecret in Kubernetes.
# No backward compatibility paths.
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
# - Ensures the Secret Manager secret container exists and adds the provided token as a new version.
# - Runs Terraform (full apply) to create/update the docker-registry secret in Kubernetes and patch the default ServiceAccount.

: "${GHCR_OWNER:?Set GHCR_OWNER to your GitHub username/org}"
: "${GHCR_TOKEN:?Set GHCR_TOKEN to a GitHub PAT with read:packages}"
: "${GHCR_TOKEN_SECRET_ID:?Set GHCR_TOKEN_SECRET_ID to the Secret Manager secret id (e.g., ghcr-pat)}"

NAMESPACE=${NAMESPACE:-default}
TF_DIR=${TF_DIR:-terraform}

# Ensure namespace exists
kubectl get ns "$NAMESPACE" >/dev/null 2>&1 || kubectl create ns "$NAMESPACE"

# Ensure Secret Manager secret exists and add a new version with the token
echo "[INFO] Ensuring Secret Manager secret '${GHCR_TOKEN_SECRET_ID}' exists and adding version"
set +e
gcloud secrets describe "$GHCR_TOKEN_SECRET_ID" >/dev/null 2>&1
EXISTS=$?
set -e
if [[ $EXISTS -ne 0 ]]; then
  echo -n "$GHCR_TOKEN" | gcloud secrets create "$GHCR_TOKEN_SECRET_ID" --replication-policy="automatic" --data-file=-
else
  echo -n "$GHCR_TOKEN" | gcloud secrets versions add "$GHCR_TOKEN_SECRET_ID" --data-file=- >/dev/null
fi

# Run Terraform to sync k8s secret and patch ServiceAccount
export TF_VAR_ghcr_owner="$GHCR_OWNER"
export TF_VAR_ghcr_token_secret_id="$GHCR_TOKEN_SECRET_ID"
export TF_VAR_k8s_namespace="$NAMESPACE"
# Avoid Terraform attempting to create the GHCR secret container since we handled it above
export TF_VAR_create_ghcr_secret=false

pushd "$TF_DIR" >/dev/null
terraform init -input=false
terraform apply -auto-approve
popd >/dev/null

echo "[INFO] GHCR pull secret ensured via Terraform and namespace '${NAMESPACE}' patched for image pulls."