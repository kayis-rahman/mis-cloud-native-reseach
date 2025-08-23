#!/usr/bin/env bash
set -euo pipefail
# Simple smoke test for identity service via port-forward
# Usage: scripts/smoke_test_identity.sh

NAMESPACE="default"
RELEASE="mis"

kubectl -n "$NAMESPACE" port-forward deploy/${RELEASE}-identity 9999:9000 >/tmp/pf.log 2>&1 &
PF_PID=$!
trap 'kill $PF_PID >/dev/null 2>&1 || true' EXIT
sleep 3

echo "[INFO] Health:"
curl -sS http://127.0.0.1:9999/actuator/health | jq . || true

echo "[INFO] Info:"
curl -sS http://127.0.0.1:9999/actuator/info | jq . || true
