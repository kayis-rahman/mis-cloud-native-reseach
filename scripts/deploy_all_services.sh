#!/usr/bin/env bash
set -euo pipefail
# Deploy all services using images provided via env or defaults.
# Usage: scripts/deploy_all_services.sh

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
CHART_PATH="$ROOT_DIR/helm/mis-cloud-native"
RELEASE="mis"
NAMESPACE="default"

# Optional registry inputs:
# - GLOBAL_REGISTRY can be a full registry prefix like ghcr.io/OWNER
# - GHCR_OWNER sets registry to ghcr.io/${GHCR_OWNER}
GLOBAL_REGISTRY="${GLOBAL_REGISTRY:-}"
GHCR_OWNER="${GHCR_OWNER:-}"
if [[ -z "$GLOBAL_REGISTRY" && -n "$GHCR_OWNER" ]]; then
  GLOBAL_REGISTRY="ghcr.io/${GHCR_OWNER}"
fi

VALUES=( )
for svc in identity product cart order payment api-gateway; do
  VALUES+=( --set services.${svc}.enabled=true )
  img_var="IMG_$(printf "%s" "$svc" | tr '[:lower:]' '[:upper:]' | tr '-' '_')" # IMG_IDENTITY, IMG_API_GATEWAY etc
  if [[ -n "${!img_var:-}" ]]; then
    # Per-service explicit image override
    VALUES+=( --set-string services.${svc}.image=${!img_var} )
  elif [[ -n "$GLOBAL_REGISTRY" ]]; then
    # Compose full image path from registry and service name
    VALUES+=( --set-string services.${svc}.image=${GLOBAL_REGISTRY}/${svc}:latest )
  else
    # No override: keep chart default image (may be Docker Hub sparkage/*)
    :
  fi
done

helm upgrade --install "$RELEASE" "$CHART_PATH" --namespace "$NAMESPACE" "${VALUES[@]}"

# Best-effort status summary
kubectl -n "$NAMESPACE" get deploy,po,svc || true