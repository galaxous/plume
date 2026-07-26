#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

TMP_ROOT="$(mktemp -d)"
STATE_DIR="${TMP_ROOT}/state"
DL_PATH="${TMP_ROOT}/dl"
mkdir -p "${STATE_DIR}" "${DL_PATH}"

cleanup() {
  rm -rf "${TMP_ROOT}"
}
trap cleanup EXIT

cat > "${DL_PATH}/.env.docker-lite" <<'EOF'
PLUME_PHP_VERSION=8.2
EOF

PLUME_STATE_DIR="${STATE_DIR}" ./plume.sh mode use docker-lite >/dev/null
PLUME_STATE_DIR="${STATE_DIR}" ./plume.sh mode path set "${DL_PATH}" >/dev/null 2>&1 || true

OUT="$(PLUME_STATE_DIR="${STATE_DIR}" ./plume.sh services status --mode=docker-lite)"
printf '%s\n' "${OUT}" | awk '$1=="php" {print $6}' | grep -q "^8.2$" || {
  echo "[FAIL] expected php version 8.2 from auto-loaded .env.docker-lite" >&2
  printf '%s\n' "${OUT}" >&2
  exit 1
}

echo "phase7-auto-load-mode-context-env-smoke:ok"
