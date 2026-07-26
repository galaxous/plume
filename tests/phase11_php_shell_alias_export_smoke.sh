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

OUT_FILE="${TMP_ROOT}/shim-env.out"

env \
  HOME="${HOME_DIR}" \
  PLUME_STATE_DIR="${STATE_DIR}" \
  PLUME_PHP_INSTALLED_VERSIONS="8.1,8.2,8.4" \
  PLUME_PHP_DEFAULT_VERSION="8.4" \
  ./plume.sh php shim env > "${OUT_FILE}"

grep -q '^export PATH="'"${HOME_DIR}"'/.config/plume/shims:\$PATH"$' "${OUT_FILE}" || {
  echo "[FAIL] missing PATH export line" >&2
  exit 1
}

grep -q "^alias php81='php8.1'$" "${OUT_FILE}" || {
  echo "[FAIL] missing php81 alias export" >&2
  exit 1
}

grep -q "^alias php82='php8.2'$" "${OUT_FILE}" || {
  echo "[FAIL] missing php82 alias export" >&2
  exit 1
}

grep -q "^alias phpfpm81='php-fpm-8.1'$" "${OUT_FILE}" || {
  echo "[FAIL] missing phpfpm81 alias export" >&2
  exit 1
}

if grep -q "^alias php84='php8.4'$" "${OUT_FILE}"; then
  echo "[FAIL] default version alias should not be exported (php84)" >&2
  exit 1
fi

echo "phase11-php-shell-alias-export-smoke:ok"
