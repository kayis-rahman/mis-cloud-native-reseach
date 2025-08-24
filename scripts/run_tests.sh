#!/usr/bin/env bash
set -euo pipefail
# Run unit and integration tests for all services using H2 (no Testcontainers).
# This script runs Maven inside a container to ensure consistent tooling, but
# does not require access to the host Docker daemon.
# Usage: scripts/run_tests.sh

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
SERVICES=(identity product cart order payment)

# Use a multi-arch Maven image tag so it works on amd64/arm64
MVN_IMAGE="maven:3.9.8-eclipse-temurin-17"

# Reuse the local Maven repository for speed if available
M2_DIR="$HOME/.m2"

for svc in "${SERVICES[@]}"; do
  echo "[INFO] Running tests (H2) for service: $svc"
  SERVICE_DIR="$ROOT_DIR/services/$svc"
  if [[ ! -d "$SERVICE_DIR" ]]; then
    echo "[ERROR] Service directory not found: $SERVICE_DIR" >&2
    exit 1
  fi
  docker run --rm \
    -v "$SERVICE_DIR":/workspace \
    -w /workspace \
    -v "$M2_DIR":/root/.m2 \
    "$MVN_IMAGE" \
    mvn -q -e -DskipTests=false clean test
  echo "[INFO] Tests passed for $svc"
done

echo "[INFO] All tests completed successfully."