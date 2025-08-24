#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
SERVICE=${1:-}  # Accept service name as argument

# Use a multi-arch Maven image tag so it works on amd64/arm64
MVN_IMAGE="maven:3.9.8-eclipse-temurin-17"

# Reuse the local Maven repository for speed if available
M2_DIR="$HOME/.m2"

run_tests() {
    local svc=$1
    echo "[INFO] Running tests (H2) for service: $svc"
    SERVICE_DIR="$ROOT_DIR/services/$svc"
    if [[ ! -d "$SERVICE_DIR" ]]; then
        echo "[ERROR] Service directory not found: $SERVICE_DIR" >&2
        exit 1
    fi

    # Run tests with H2 database
    cd "$SERVICE_DIR"
    mvn -B verify \
        -Dspring.profiles.active=test \
        -Dspring.datasource.url=jdbc:h2:mem:testdb \
        -Dspring.datasource.driver-class-name=org.h2.Driver
}

if [[ -n "$SERVICE" ]]; then
    # Run tests for single service
    run_tests "$SERVICE"
else
    # Run tests for all services
    SERVICES=(identity product cart order payment api-gateway)
    for svc in "${SERVICES[@]}"; do
        run_tests "$svc"
    done
fi
