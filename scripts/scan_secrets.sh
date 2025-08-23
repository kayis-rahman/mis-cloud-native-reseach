#!/usr/bin/env bash
set -euo pipefail
# Secret scanning placeholder using gitleaks if available.
# Usage: scripts/scan_secrets.sh

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)

if command -v gitleaks >/dev/null 2>&1; then
  echo "[INFO] Running gitleaks scan (repo root)"
  gitleaks detect -v -s "$ROOT_DIR" || true
else
  echo "[WARN] gitleaks not installed; skipping. See https://github.com/gitleaks/gitleaks"
fi

echo "[INFO] Secret scan complete."