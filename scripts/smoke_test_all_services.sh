#!/usr/bin/env bash
set -euo pipefail
# Smoke test all known services sequentially using scripts/smoke_test_a_service.sh
# Usage:
#   scripts/smoke_test_all_services.sh
#   NAMESPACE=default RELEASE=mis scripts/smoke_test_all_services.sh
#
# Notes:
# - Uses a single local port (9999) per run; tests run sequentially to avoid conflicts.
# - Continues through services even if one fails (best-effort).

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
NAMESPACE="${NAMESPACE:-default}"
RELEASE="${RELEASE:-mis}"
SERVICES=(identity product cart order payment)

for svc in "${SERVICES[@]}"; do
  echo "=============================="
  echo "[INFO] Smoke testing service: ${svc}"
  echo "=============================="
  SERVICE="$svc" NAMESPACE="$NAMESPACE" RELEASE="$RELEASE" \
    "$ROOT_DIR/scripts/smoke_test_a_service.sh" || echo "[WARN] Smoke test failed for ${svc} (continuing)"
  echo
  # brief pause between services
  sleep 1
done

echo "[OK] Completed smoke tests for: ${SERVICES[*]}"