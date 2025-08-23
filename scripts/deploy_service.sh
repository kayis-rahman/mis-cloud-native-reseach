#!/usr/bin/env bash
set -euo pipefail
# Deploy one service using the shared chart.
# Usage: SERVICE=identity IMAGE=ghcr.io/OWNER/identity:TAG scripts/deploy_service.sh

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
CHART_PATH="$ROOT_DIR/helm/mis-cloud-native"
RELEASE="mis"
NAMESPACE="default"

SERVICE="${SERVICE:-identity}"
IMAGE="${IMAGE:-}"
if [[ -z "$IMAGE" ]]; then
  echo "[ERROR] Set IMAGE to container image (e.g., ghcr.io/OWNER/identity:latest)" >&2
  exit 1
fi

# Disable all services, enable only the target one
VALUES=(
  --set services.identity.enabled=false
  --set services.product.enabled=false
  --set services.cart.enabled=false
  --set services.order.enabled=false
  --set services.payment.enabled=false
)
case "$SERVICE" in
  identity|product|cart|order|payment) ;;
  *) echo "[ERROR] Unknown SERVICE: $SERVICE" >&2; exit 1;;
esac

VALUES+=( --set services.${SERVICE}.enabled=true )
VALUES+=( --set-string services.${SERVICE}.image=${IMAGE} )

helm upgrade --install "$RELEASE" "$CHART_PATH" --namespace "$NAMESPACE" "${VALUES[@]}"

# Inject environment variables from db-<service> secret using valueFrom (secretKeyRef)
if kubectl -n "$NAMESPACE" get secret "db-${SERVICE}" >/dev/null 2>&1; then
  echo "[INFO] Patching deployment ${RELEASE}-${SERVICE} to reference secret db-${SERVICE} via valueFrom"
  PATCH='{
    "spec": {
      "template": {
        "spec": {
          "containers": [
            {
              "name": "'"${SERVICE}"'",
              "env": [
                {
                  "name": "SPRING_DATASOURCE_URL",
                  "valueFrom": {"secretKeyRef": {"name": "db-'"${SERVICE}"'", "key": "SPRING_DATASOURCE_URL"}}
                },
                {
                  "name": "SPRING_DATASOURCE_USERNAME",
                  "valueFrom": {"secretKeyRef": {"name": "db-'"${SERVICE}"'", "key": "SPRING_DATASOURCE_USERNAME"}}
                },
                {
                  "name": "SPRING_DATASOURCE_PASSWORD",
                  "valueFrom": {"secretKeyRef": {"name": "db-'"${SERVICE}"'", "key": "SPRING_DATASOURCE_PASSWORD"}}
                }
              ]
            }
          ]
        }
      }
    }
  }'
  kubectl -n "$NAMESPACE" patch deploy/${RELEASE}-${SERVICE} --type=merge -p "$PATCH" || true
  # Restart to pick up env changes
  kubectl -n "$NAMESPACE" rollout restart deploy/${RELEASE}-${SERVICE} || true
fi

kubectl -n "$NAMESPACE" rollout status deploy/${RELEASE}-${SERVICE} --timeout=180s || true
kubectl -n "$NAMESPACE" get deploy,po,svc