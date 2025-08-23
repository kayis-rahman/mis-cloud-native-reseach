#!/usr/bin/env bash
set -euo pipefail
# Validate a deployment by checking rollout and basic endpoints (if port-forward is possible).
# Usage: SERVICE=identity scripts/validate_deploy.sh

SERVICE="${SERVICE:-identity}"
NAMESPACE="default"
RELEASE="mis"

kubectl -n "$NAMESPACE" rollout status deploy/${RELEASE}-${SERVICE} --timeout=180s || true
kubectl -n "$NAMESPACE" get deploy,po,svc

echo "[INFO] Attempting port-forward for basic health check (Ctrl+C to stop after output)"
set +e
kubectl -n "$NAMESPACE" port-forward deploy/${RELEASE}-${SERVICE} 9999:9000 >/tmp/pf.log 2>&1 &
PF_PID=$!
sleep 3
curl -sS http://127.0.0.1:9999/actuator/health || true
kill $PF_PID >/dev/null 2>&1 || true
set -e

echo "[INFO] Validation attempt complete."