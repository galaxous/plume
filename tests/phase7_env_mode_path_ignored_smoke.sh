#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

TMP_ROOT="$(mktemp -d)"
STATE_DIR="${TMP_ROOT}/state"
ENV_FILE="${TMP_ROOT}/.env.test"
mkdir -p "${STATE_DIR}"

cleanup() {
  rm -rf "${TMP_ROOT}"
}
trap cleanup EXIT

cat > "${ENV_FILE}" <<'EOF'
PLUME_MODE=docker-lite
PLUME_DOCKER_LITE_COMPOSE_FILE=/tmp/should-not-apply-compose.yml
PLUME_LARADOCK_PATH=/tmp/should-not-apply-laradock
EOF

MODE_OUT="$(PLUME_STATE_DIR="${STATE_DIR}" ./plume.sh --env-file "${ENV_FILE}" mode current)"
if [[ "${MODE_OUT}" != "native" ]]; then
  echo "[FAIL] mode should ignore .env PLUME_MODE, got: ${MODE_OUT}" >&2
  exit 1
fi

PATH_OUT="$(PLUME_STATE_DIR="${STATE_DIR}" ./plume.sh --env-file "${ENV_FILE}" mode path get docker-lite || true)"
if [[ -n "${PATH_OUT}" ]]; then
  echo "[FAIL] docker-lite path should ignore .env path values, got: ${PATH_OUT}" >&2
  exit 1
fi

echo "phase7-env-mode-path-ignored-smoke:ok"
