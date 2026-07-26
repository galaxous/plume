#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

TMP_ROOT="$(mktemp -d)"
cleanup() {
  rm -rf "${TMP_ROOT}"
}
trap cleanup EXIT

HOME_DIR="${TMP_ROOT}/home"
STATE_DIR="${TMP_ROOT}/state"
GLOBAL_ENV="${HOME_DIR}/.config/plume/.env"
mkdir -p "${HOME_DIR}" "${STATE_DIR}"

env HOME="${HOME_DIR}" PLUME_STATE_DIR="${STATE_DIR}" ./plume.sh php list >/dev/null

[[ -f "${GLOBAL_ENV}" ]] || {
  echo "[FAIL] expected global env to be bootstrapped from .env.example" >&2
  exit 1
}

grep -q '^PLUME_WEB_SERVER_ENABLED=' "${GLOBAL_ENV}" || {
  echo "[FAIL] bootstrapped .env should include core variables" >&2
  exit 1
}

echo "phase11-env-autobootstrap-smoke:ok"
