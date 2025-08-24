#!/usr/bin/env bash
set -euo pipefail
# Deploy one service using the shared chart with new image format.
# Usage: SERVICE=identity scripts/deploy_service.sh
# Or with custom image: SERVICE=identity IMAGE=custom-image:tag scripts/deploy_service.sh

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
CHART_PATH="$ROOT_DIR/helm/mis-cloud-native"
RELEASE="mis"
NAMESPACE="default"

SERVICE="${SERVICE:-identity}"
IMAGE_REPOSITORY="ghcr.io/kayis-rahman/mis-cloud-native-reseach"

# Use custom image if provided, otherwise use new format
IMAGE="${IMAGE:-${IMAGE_REPOSITORY}/${SERVICE}:latest}"

echo "[INFO] Deploying service: $SERVICE"
echo "[INFO] Using image: $IMAGE"

# Disable all services, enable only the target one
VALUES=(
  --set services.identity.enabled=false
  --set services.product.enabled=false
  --set services.cart.enabled=false
  --set services.order.enabled=false
  --set services.payment.enabled=false
  --set services.api-gateway.enabled=false
)

case "$SERVICE" in
  identity|product|cart|order|payment|api-gateway) ;;
  *) echo "[ERROR] Unknown SERVICE: $SERVICE" >&2; exit 1;;
esac

VALUES+=( --set services.${SERVICE}.enabled=true )
VALUES+=( --set-string services.${SERVICE}.image=${IMAGE} )

helm upgrade --install "$RELEASE" "$CHART_PATH" --namespace "$NAMESPACE" "${VALUES[@]}"

# Wait for deployment to be ready
echo "⏳ Waiting for deployment ${RELEASE}-${SERVICE} to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/${RELEASE}-${SERVICE} -n ${NAMESPACE} || echo "⚠️  Deployment not ready within timeout"

echo "✅ Service $SERVICE deployed successfully with image: $IMAGE"
