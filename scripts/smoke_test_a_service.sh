#!/usr/bin/env bash
set -euo pipefail
# Generic smoke test for a service via port-forward
# Usage:
#   scripts/smoke_test_a_service.sh [service]
#   SERVICE=order scripts/smoke_test_a_service.sh
#   SERVICE=cart NAMESPACE=default RELEASE=mis scripts/smoke_test_a_service.sh
#
# Behavior:
# - Detects the service's container port from the Kubernetes Service (http port) or Deployment.
# - Port-forwards deploy/<RELEASE>-<SERVICE> to local 9999 and curls /actuator/health and /actuator/info.
# - Uses jq if available to pretty-print JSON.

SERVICE="${SERVICE:-${1:-identity}}"
NAMESPACE="${NAMESPACE:-default}"
RELEASE="${RELEASE:-mis}"
LOCAL_PORT="${LOCAL_PORT:-9999}"
CURL_TIMEOUT="${CURL_TIMEOUT:-10}"

if ! command -v kubectl >/dev/null 2>&1; then
  echo "[ERR] kubectl is required in PATH" >&2
  exit 1
fi

# Attempt to detect target port from Service (prefer named http port), then Deployment containerPort
TARGET_PORT=""
set +e
TARGET_PORT=$(kubectl -n "$NAMESPACE" get svc "${RELEASE}-${SERVICE}" -o jsonpath='{.spec.ports[?(@.name=="http")].targetPort}' 2>/dev/null)
if [[ -z "$TARGET_PORT" ]]; then
  TARGET_PORT=$(kubectl -n "$NAMESPACE" get deploy "${RELEASE}-${SERVICE}" -o jsonpath='{.spec.template.spec.containers[0].ports[0].containerPort}' 2>/dev/null)
fi
set -e

# Fallback default ports per known service
if [[ -z "$TARGET_PORT" ]]; then
  case "$SERVICE" in
    identity) TARGET_PORT=9000;;
    product)  TARGET_PORT=9001;;
    cart)     TARGET_PORT=9002;;
    order)    TARGET_PORT=9003;;
    payment)  TARGET_PORT=9004;;
    api-gateway) TARGET_PORT=8080;;
    *) TARGET_PORT=8080;;
  esac
  echo "[WARN] Could not auto-detect container port; falling back to default ${TARGET_PORT} for ${SERVICE}"
fi

# Ensure deployment exists
if ! kubectl -n "$NAMESPACE" get deploy "${RELEASE}-${SERVICE}" >/dev/null 2>&1; then
  echo "[ERR] Deployment '${RELEASE}-${SERVICE}' not found in namespace '${NAMESPACE}'." >&2
  kubectl -n "$NAMESPACE" get deploy || true
  exit 1
fi

# Port-forward in background
echo "[INFO] Port-forwarding deploy/${RELEASE}-${SERVICE} ${LOCAL_PORT}:${TARGET_PORT}"
kubectl -n "$NAMESPACE" port-forward "deploy/${RELEASE}-${SERVICE}" "${LOCAL_PORT}:${TARGET_PORT}" >/tmp/pf-${SERVICE}.log 2>&1 &
PF_PID=$!
cleanup() {
  kill "$PF_PID" >/dev/null 2>&1 || true
}
trap cleanup EXIT

# Give it a moment to establish
sleep 3

# Health endpoint
echo "[INFO] Health:"
if command -v jq >/dev/null 2>&1; then
  curl --max-time "$CURL_TIMEOUT" -fsS "http://127.0.0.1:${LOCAL_PORT}/actuator/health" | jq . || true
else
  curl --max-time "$CURL_TIMEOUT" -fsS "http://127.0.0.1:${LOCAL_PORT}/actuator/health" || true
fi

# Info endpoint
echo "[INFO] Info:"
if command -v jq >/dev/null 2>&1; then
  curl --max-time "$CURL_TIMEOUT" -fsS "http://127.0.0.1:${LOCAL_PORT}/actuator/info" | jq . || true
else
  curl --max-time "$CURL_TIMEOUT" -fsS "http://127.0.0.1:${LOCAL_PORT}/actuator/info" || true
fi
