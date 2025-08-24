#!/usr/bin/env bash
set -euo pipefail
# Secret scanning using Gitleaks.
# - If gitleaks CLI is installed, use it.
# - Otherwise, if Docker is available, use the official gitleaks container as a fallback.
#
# Defaults (tunable via env):
#   HISTORY=0           # 0 = scan working tree only (fast), 1 = scan full git history
#   FAIL_ON_FINDINGS=0  # 1 = exit non-zero on leaks (CI-enforcing), 0 = do not fail build
#   REPORT_FORMAT=""   # e.g., sarif, json, csv (empty = no report file)
#   REPORT="gitleaks-report"  # base filename without extension (used if REPORT_FORMAT set)
#
# Usage:
#   scripts/scan_secrets.sh
#   HISTORY=1 FAIL_ON_FINDINGS=1 scripts/scan_secrets.sh
#   REPORT_FORMAT=sarif REPORT=gitleaks scripts/scan_secrets.sh

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
HISTORY=${HISTORY:-0}
FAIL_ON_FINDINGS=${FAIL_ON_FINDINGS:-0}
REPORT_FORMAT=${REPORT_FORMAT:-}
REPORT=${REPORT:-gitleaks-report}

EXIT_CODE_FLAG=("--exit-code" "0")
if [[ "$FAIL_ON_FINDINGS" == "1" ]]; then
  EXIT_CODE_FLAG=("--exit-code" "1")
fi

NO_GIT_FLAG=("--no-git")
if [[ "$HISTORY" == "1" ]]; then
  NO_GIT_FLAG=()
  echo "[INFO] HISTORY=1 -> scanning full git history"
else
  echo "[INFO] Scanning working tree only (HISTORY=0). Set HISTORY=1 to scan full git history."
fi

REPORT_ARGS=()
if [[ -n "$REPORT_FORMAT" ]]; then
  REPORT_PATH="$ROOT_DIR/${REPORT}.${REPORT_FORMAT}"
  REPORT_ARGS=("--report-format" "$REPORT_FORMAT" "--report-path" "$REPORT_PATH")
  echo "[INFO] Will write report to: $REPORT_PATH"
fi

# Optional repo-local config
CONFIG_ARGS=()
if [[ -f "$ROOT_DIR/.gitleaks.toml" ]]; then
  CONFIG_ARGS=("--config" "$ROOT_DIR/.gitleaks.toml")
  echo "[INFO] Using config: .gitleaks.toml"
fi

run_gitleaks() {
  # shellcheck disable=SC2068
  gitleaks detect -v -s "$ROOT_DIR" \
    ${NO_GIT_FLAG[@]+"${NO_GIT_FLAG[@]}"} \
    ${EXIT_CODE_FLAG[@]+"${EXIT_CODE_FLAG[@]}"} \
    ${REPORT_ARGS[@]+"${REPORT_ARGS[@]}"} \
    ${CONFIG_ARGS[@]+"${CONFIG_ARGS[@]}"}
}

run_gitleaks_container() {
  local image="zricethezav/gitleaks:latest"
  echo "[INFO] Running gitleaks via Docker image: $image"
  # shellcheck disable=SC2068
  docker run --rm -t \
    -v "$ROOT_DIR":/repo \
    -w /repo \
    "$image" detect -v -s /repo \
    ${NO_GIT_FLAG[@]+"${NO_GIT_FLAG[@]}"} \
    ${EXIT_CODE_FLAG[@]+"${EXIT_CODE_FLAG[@]}"} \
    ${REPORT_ARGS[@]+"${REPORT_ARGS[@]}"} \
    ${CONFIG_ARGS[@]+"${CONFIG_ARGS[@]}"}
}

if command -v gitleaks >/dev/null 2>&1; then
  echo "[INFO] Running gitleaks (local CLI)"
  run_gitleaks || true
else
  if command -v docker >/dev/null 2>&1; then
    run_gitleaks_container || true
  else
    echo "[WARN] gitleaks not installed and Docker not available; skipping scan."
    echo "      Install: https://github.com/gitleaks/gitleaks or install Docker to use the fallback."
  fi
fi

# Tips
if [[ "$FAIL_ON_FINDINGS" != "1" ]]; then
  echo "[INFO] Tip: set FAIL_ON_FINDINGS=1 to make this script fail the build on leaks."
fi

echo "[INFO] Secret scan complete."