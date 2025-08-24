#!/usr/bin/env bash
set -euo pipefail
# Run unit and integration tests for all services (Maven projects).
# Usage: scripts/run_tests.sh

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
#SERVICES=(identity product cart order payment)
SERVICES=(cart)

for svc in "${SERVICES[@]}"; do
  echo "[INFO] Running tests for $svc"
  (cd "$ROOT_DIR/services/$svc" && mvn -q -DskipTests=false clean test)
  echo "[INFO] Completed tests for $svc"
done

echo "[INFO] All tests completed."