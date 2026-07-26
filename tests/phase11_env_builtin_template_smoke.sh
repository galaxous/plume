#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

TMP_ROOT="$(mktemp -d)"
HOME_DIR="${TMP_ROOT}/home"
STATE_DIR="${TMP_ROOT}/state"
mkdir -p "${HOME_DIR}" "${STATE_DIR}"

cleanup() {
  rm -rf "${TMP_ROOT}"
}
trap cleanup EXIT

BASE_ENV=(
  "HOME=${HOME_DIR}"
  "PLUME_STATE_DIR=${STATE_DIR}"
)

env "${BASE_ENV[@]}" ./plume.sh env init >/dev/null

GLOBAL_ENV="${HOME_DIR}/.config/plume/.env"
[[ -f "${GLOBAL_ENV}" ]] || {
  echo "[FAIL] expected global env from built-in template" >&2
  exit 1
}

grep -q '^PLUME_WEB_SERVER_DRIVER=nginx$' "${GLOBAL_ENV}" || {
  echo "[FAIL] expected nginx driver in built-in template output" >&2
  exit 1
}

grep -q '^PLUME_REDIS_ENABLED=true$' "${GLOBAL_ENV}" || {
  echo "[FAIL] expected redis enabled in built-in template output" >&2
  exit 1
}

echo "phase11-env-builtin-template-smoke:ok"
