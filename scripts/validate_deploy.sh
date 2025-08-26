#!/usr/bin/env bash
set -euo pipefail
# Validate a deployment by checking rollout and basic endpoints (if port-forward is possible).
# Usage: SERVICE=identity scripts/validate_deploy.sh

SERVICE="${SERVICE:-identity}"
NAMESPACE="default"
RELEASE="mis"

kubectl -n "$NAMESPACE" rollout status deploy/${RELEASE}-${SERVICE} --timeout=30s || true
kubectl -n "$NAMESPACE" get deploy,po,svc

echo "[INFO] Attempting port-forward for basic health check (Ctrl+C to stop after output)"

# Detect target port similar to smoke_test_a_service.sh
TARGET_PORT=""
set +e
TARGET_PORT=$(kubectl -n "$NAMESPACE" get svc "${RELEASE}-${SERVICE}" -o jsonpath='{.spec.ports[?(@.name=="http")].targetPort}' 2>/dev/null)
if [[ -z "$TARGET_PORT" ]]; then
  TARGET_PORT=$(kubectl -n "$NAMESPACE" get deploy "${RELEASE}-${SERVICE}" -o jsonpath='{.spec.template.spec.containers[0].ports[0].containerPort}' 2>/dev/null)
fi
set -e
if [[ -z "$TARGET_PORT" ]]; then
  case "$SERVICE" in
    identity) TARGET_PORT=9000;;
    product) TARGET_PORT=9001;;
    cart) TARGET_PORT=9002;;
    order) TARGET_PORT=9003;;
    payment) TARGET_PORT=9004;;
    api-gateway) TARGET_PORT=8080;;
    *) TARGET_PORT=8080;;
  esac
  echo "[WARN] Could not auto-detect container port; falling back to default ${TARGET_PORT} for ${SERVICE}"
fi

set +e
kubectl -n "$NAMESPACE" port-forward deploy/${RELEASE}-${SERVICE} 9999:${TARGET_PORT} >/tmp/pf.log 2>&1 &
PF_PID=$!
sleep 3
curl -sS http://127.0.0.1:9999/actuator/health || true
kill $PF_PID >/dev/null 2>&1 || true
set -e

echo "[INFO] Validation attempt complete."