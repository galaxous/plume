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

OUT="$(env \
  HOME="${HOME_DIR}" \
  PLUME_STATE_DIR="${STATE_DIR}" \
  PLUME_PHP_DEFAULT_VERSION="8.4" \
  PLUME_PHP_INSTALLED_VERSIONS="8.4" \
  PLUME_PHP_EXT_PRESET="laravel-core" \
  PLUME_PHP_EXTENSIONS_GLOBAL="imagick" \
  PLUME_PHP_EXTENSIONS_84="redis" \
  PLUME_PHP_EXT_ENABLE_84_XDEBUG="true" \
  PLUME_PHP_EXT_DISABLE_84_IMAGICK="true" \
  ./plume.sh php ext resolve 8.4)"

RESOLVED_LINE="$(printf '%s\n' "${OUT}" | awk '$1=="8.4"{print $0}')"
[[ -n "${RESOLVED_LINE}" ]] || {
  echo "[FAIL] expected resolved row for 8.4" >&2
  printf '%s\n' "${OUT}" >&2
  exit 1
}

printf '%s\n' "${OUT}" | grep -q '^8.4[[:space:]]' || {
  echo "[FAIL] expected 8.4 row in php ext resolve output" >&2
  printf '%s\n' "${OUT}" >&2
  exit 1
}

printf '%s\n' "${RESOLVED_LINE}" | grep -q 'redis' || {
  echo "[FAIL] expected redis in resolved extension list" >&2
  printf '%s\n' "${OUT}" >&2
  exit 1
}

printf '%s\n' "${RESOLVED_LINE}" | grep -q 'xdebug' || {
  echo "[FAIL] expected xdebug from toggle enable in resolved list" >&2
  printf '%s\n' "${OUT}" >&2
  exit 1
}

if printf '%s\n' "${RESOLVED_LINE}" | grep -q 'imagick'; then
  echo "[FAIL] imagick should be removed by disable toggle" >&2
  printf '%s\n' "${OUT}" >&2
  exit 1
fi

echo "phase11-php-ext-resolve-contract-smoke:ok"
