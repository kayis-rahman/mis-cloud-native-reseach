#!/usr/bin/env bash
set -euo pipefail
# Run unit and integration tests for all services via Docker multi-stage test targets.
# Usage: scripts/run_tests.sh

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
SERVICES=(identity product cart order payment)

for svc in "${SERVICES[@]}"; do
  echo "[INFO] Building test stage for service: $svc"
  DOCKERFILE="$ROOT_DIR/services/$svc/Dockerfile"
  CONTEXT="$ROOT_DIR/services/$svc"
  if [[ ! -f "$DOCKERFILE" ]]; then
    echo "[ERROR] Dockerfile not found for service '$svc' at $DOCKERFILE" >&2
    exit 1
  fi
  # Build the 'test' stage; the build will fail if tests fail inside the stage
  docker build --progress=plain --target test -f "$DOCKERFILE" "$CONTEXT"
  echo "[INFO] Tests passed for $svc"
done

echo "[INFO] All tests completed successfully."