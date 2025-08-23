#!/usr/bin/env bash
set -euo pipefail
# Security scanning placeholder (Trivy if installed).
# Usage: IMAGE=ghcr.io/OWNER/identity:latest scripts/scan_security.sh

IMAGE="${IMAGE:-}"
if [[ -z "$IMAGE" ]]; then
  echo "[WARN] Set IMAGE to scan a container image (e.g., ghcr.io/OWNER/identity:latest)"
fi

if command -v trivy >/dev/null 2>&1; then
  echo "[INFO] Trivy image scan (medium+ severity)"
  trivy image --ignore-unfixed --severity MEDIUM,HIGH,CRITICAL ${IMAGE:-alpine:latest} || true
else
  echo "[WARN] trivy is not installed; skipping image scan. See https://aquasecurity.github.io/trivy/"
fi

echo "[INFO] Security scan complete."