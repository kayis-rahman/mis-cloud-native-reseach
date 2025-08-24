#!/usr/bin/env bash
set -euo pipefail
# Security scanning using Trivy.
# - If Trivy CLI is installed, use it.
# - Otherwise, if Docker is available, use ghcr.io/aquasecurity/trivy container as a fallback.
# Scans performed:
#   1) Image scan (if IMAGE env var is set)
#   2) Filesystem/IaC/Secrets scan of the repository
# Usage: IMAGE=ghcr.io/OWNER/identity:latest scripts/scan_security.sh

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
IMAGE="${IMAGE:-}"

# Tunables via env:
# - NO_PROGRESS=1 to hide progress bars (default: 0 -> show progress)
# - FAST=1 to disable secret scanning (scanners=vuln,misconfig) for speed (default: 0)
# - TRIVY_TIMEOUT to override default timeout (default: 15m)
NO_PROGRESS=${NO_PROGRESS:-0}
FAST=${FAST:-0}
TRIVY_TIMEOUT=${TRIVY_TIMEOUT:-15m}

# Graceful shutdown on Ctrl+C/TERM
cleanup() {
  echo "[INFO] Received interrupt, stopping scans gracefully..."
  exit 130
}
trap cleanup INT TERM

# Decide how to run trivy
TRIVY_CMD=""
USE_CONTAINER=false
if command -v trivy >/dev/null 2>&1; then
  TRIVY_CMD="trivy"
else
  if command -v docker >/dev/null 2>&1; then
    USE_CONTAINER=true
    # Mount repo for fs scan, mount docker socket for image scan, cache to speed up
    TRIVY_CMD=(docker run --rm \
      -v /var/run/docker.sock:/var/run/docker.sock \
      -v "$HOME/.cache/trivy":/root/.cache \
      -v "$ROOT_DIR":/repo \
      ghcr.io/aquasecurity/trivy:latest)
  else
    echo "[WARN] Neither trivy nor docker is available; cannot perform security scans."
    echo "       Install Trivy: https://trivy.dev/latest/getting-started/ or install Docker to use the fallback."
    echo "[INFO] Security scan complete (no scans run)."
    exit 0
  fi
fi

# Helper to run trivy uniformly (supports array for docker command)
run_trivy() {
  if [[ "$USE_CONTAINER" == true ]]; then
    "${TRIVY_CMD[@]}" "$@"
  else
    trivy "$@"
  fi
}

# Warm Trivy DB (first run may take a few minutes)
echo "[INFO] Preparing Trivy vulnerability database (first run may take several minutes; subsequent runs are faster)"
# Some trivy versions support --download-db-only globally
run_trivy --download-db-only --timeout "$TRIVY_TIMEOUT" || true

# Progress flag handling
PROGRESS_FLAG=()
if [[ "$NO_PROGRESS" == "1" ]]; then
  PROGRESS_FLAG+=(--no-progress)
fi

# Scanner set (FAST mode skips secret scanning)
SCANNERS="vuln,secret,misconfig"
if [[ "$FAST" == "1" ]]; then
  SCANNERS="vuln,misconfig"
  echo "[INFO] FAST=1 -> skipping secret scanning (scanners=$SCANNERS)"
fi

# 1) Image scan (optional)
if [[ -n "$IMAGE" ]]; then
  echo "[INFO] Trivy image scan: $IMAGE (severity >= HIGH, ignore-unfixed)"
  # shellcheck disable=SC2086
  run_trivy image --ignore-unfixed --severity HIGH,CRITICAL "${PROGRESS_FLAG[@]}" "$IMAGE" || true
else
  echo "[WARN] Set IMAGE to scan a container image (e.g., ghcr.io/OWNER/identity:latest). Skipping image scan."
fi

# 2) Filesystem + IaC + Secrets scan of repo
# Use scanners: vuln (OS/deps), secret, misconfig (IaC misconfiguration)
if [[ "$USE_CONTAINER" == true ]]; then
  SCAN_PATH="/repo"
else
  SCAN_PATH="$ROOT_DIR"
fi

# Skip heavy/generated directories to speed up and reduce noise
SKIP_DIRS=(
  "${SCAN_PATH}/.git"
  "${SCAN_PATH}/terraform/.terraform"
  "${SCAN_PATH}/services/identity/target"
  "${SCAN_PATH}/services/product/target"
  "${SCAN_PATH}/services/cart/target"
  "${SCAN_PATH}/services/order/target"
  "${SCAN_PATH}/services/payment/target"
)
SKIP_ARGS=()
for d in "${SKIP_DIRS[@]}"; do
  SKIP_ARGS+=(--skip-dirs "$d")
done

echo "[INFO] Trivy filesystem scan of repo (scanners=$SCANNERS; severity >= HIGH)"
# shellcheck disable=SC2086
run_trivy fs --ignore-unfixed --severity HIGH,CRITICAL \
  --scanners "$SCANNERS" "${PROGRESS_FLAG[@]}" --timeout "$TRIVY_TIMEOUT" \
  "${SKIP_ARGS[@]}" "$SCAN_PATH" || true

# Optional: brief tips
echo "[INFO] Tips:"
echo " - To hide progress bars: NO_PROGRESS=1 ./scripts/scan_security.sh"
echo " - To speed up by skipping secret scan: FAST=1 ./scripts/scan_security.sh"
echo " - To fail CI on HIGH/CRITICAL only, remove '|| true' and set --severity HIGH,CRITICAL"
echo " - To generate SARIF for GitHub code scanning: add '--format sarif --output trivy-report.sarif'"

echo "[INFO] Security scan complete."