#!/usr/bin/env bash
set -euo pipefail
# Sync identity DB config from Google Secret Manager into Kubernetes secret db-identity (namespace default by default).
# This is a helper for debugging or one-off syncs. ESO-based sync is preferred and automated in Terraform.
# Usage: [NAMESPACE=default] [SECRET_ID=identity-db-config] scripts/sync_db_secret_from_gsm.sh

NAMESPACE=${NAMESPACE:-default}
SECRET_ID=${SECRET_ID:-identity-db-config}

command -v gcloud >/dev/null || { echo "[ERR] gcloud is required"; exit 1; }
command -v kubectl >/dev/null || { echo "[ERR] kubectl is required"; exit 1; }
command -v jq >/dev/null || { echo "[ERR] jq is required"; exit 1; }

JSON=$(gcloud secrets versions access latest --secret="${SECRET_ID}")
URL=$(echo "$JSON" | jq -r '.SPRING_DATASOURCE_URL')
USER=$(echo "$JSON" | jq -r '.SPRING_DATASOURCE_USERNAME')
PASS=$(echo "$JSON" | jq -r '.SPRING_DATASOURCE_PASSWORD')

kubectl get ns "$NAMESPACE" >/dev/null 2>&1 || kubectl create ns "$NAMESPACE"

kubectl -n "$NAMESPACE" apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: db-identity
  namespace: ${NAMESPACE}
type: Opaque
stringData:
  SPRING_DATASOURCE_URL: "${URL}"
  SPRING_DATASOURCE_USERNAME: "${USER}"
  SPRING_DATASOURCE_PASSWORD: "${PASS}"
EOF

echo "[OK] Synced db-identity secret in namespace ${NAMESPACE} from GSM secret ${SECRET_ID}."
