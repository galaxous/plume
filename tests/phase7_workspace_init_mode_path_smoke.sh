#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

TMP_ROOT="$(mktemp -d)"
STATE_DIR="${TMP_ROOT}/state"
TARGET="${TMP_ROOT}/workspace"
mkdir -p "${STATE_DIR}" "${TARGET}"

cleanup() {
  rm -rf "${TMP_ROOT}"
}
trap cleanup EXIT

printf '%s\n' "${TARGET}" > "${STATE_DIR}/mode-path-docker-lite"

PLUME_STATE_DIR="${STATE_DIR}" \
./plume.sh services workspace init --mode=docker-lite >/tmp/plume-phase7-workspace-init-modepath.out 2>&1

test -f "${TARGET}/docker-compose.yml" || {
  echo "[FAIL] compose not generated via mode path fallback" >&2
  cat /tmp/plume-phase7-workspace-init-modepath.out >&2 || true
  exit 1
}

test -f "${TARGET}/.env.docker-lite" || {
  echo "[FAIL] env stub not generated via mode path fallback" >&2
  cat /tmp/plume-phase7-workspace-init-modepath.out >&2 || true
  exit 1
}

echo "phase7-workspace-init-mode-path-smoke:ok"
