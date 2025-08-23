#!/usr/bin/env bash
set -euo pipefail
# Lint chart and Kubernetes manifests
# Usage: scripts/scan_lint.sh

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)

if command -v helm >/dev/null 2>&1; then
  echo "[INFO] Helm lint"
  helm lint "$ROOT_DIR/helm/mis-cloud-native" || true
else
  echo "[WARN] Helm not found; skipping helm lint"
fi

# Placeholder for kubectl schema validation if kubeconform/kubeval installed
if command -v kubeconform >/dev/null 2>&1; then
  echo "[INFO] kubeconform validation (rendered templates with default values)"
  helm template test "$ROOT_DIR/helm/mis-cloud-native" | kubeconform -strict -summary || true
fi

echo "[INFO] Lint scan complete."