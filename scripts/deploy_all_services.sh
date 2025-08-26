#!/usr/bin/env bash
set -euo pipefail
# Deploy all services using the new image format.
# Usage: scripts/deploy_all_services.sh

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
CHART_PATH="$ROOT_DIR/helm/mis-cloud-native"
RELEASE="mis"
NAMESPACE="default"

# Use the new fixed image repository format
IMAGE_REPOSITORY="ghcr.io/kayis-rahman/mis-cloud-native-reseach"

VALUES=( )

#for svc in identity product cart order payment api-gateway; do
for svc in api-gateway; do
  VALUES+=( --set services.${svc}.enabled=true )
  img_var="IMG_$(printf "%s" "$svc" | tr '[:lower:]' '[:upper:]' | tr '-' '_')" # IMG_IDENTITY, IMG_API_GATEWAY etc
  if [[ -n "${!img_var:-}" ]]; then
    # Per-service explicit image override
    VALUES+=( --set-string services.${svc}.image=${!img_var} )
  else
    # Use the new image format: ghcr.io/kayis-rahman/mis-cloud-native-reseach/[service]:latest
    VALUES+=( --set-string services.${svc}.image=${IMAGE_REPOSITORY}/${svc}:latest )
  fi
done

helm upgrade --install "$RELEASE" "$CHART_PATH" --namespace "$NAMESPACE" "${VALUES[@]}"

echo "✅ All services deployed with new image format: ${IMAGE_REPOSITORY}/[service]:latest"

# Wait for deployments to be ready
echo "⏳ Waiting for deployments to be ready..."
for svc in identity product cart order payment api-gateway; do
  echo "  Checking $svc..."
  kubectl wait --for=condition=available --timeout=30s deployment/${RELEASE}-${svc} -n ${NAMESPACE} || echo "⚠️  $svc deployment not ready"
done

echo "🎉 Deployment complete!"
