#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

TMP_ROOT="$(mktemp -d)"
HOME_DIR="${TMP_ROOT}/home"
STATE_DIR="${TMP_ROOT}/state"
SITE_REGISTRY="${TMP_ROOT}/sites"
mkdir -p "${HOME_DIR}" "${STATE_DIR}" "${SITE_REGISTRY}"
mkdir -p "${HOME_DIR}/.config/plume"
: > "${HOME_DIR}/.config/plume/.env"

cleanup() {
  rm -rf "${TMP_ROOT}"
}
trap cleanup EXIT

BASE_ENV=(
  "HOME=${HOME_DIR}"
  "PLUME_STATE_DIR=${STATE_DIR}"
  "PLUME_SITE_REGISTRY_DIR=${SITE_REGISTRY}"
  "PLUME_SKIP_ON_FIRST_RUN_PROVISION=true"
  "PLUME_PHP_FPM_VERIFY_AFTER_START=false"
)

assert_ok() {
  local name="$1"
  shift
  if "$@" >/dev/null 2>&1; then
    echo "[PASS] ${name}"
  else
    echo "[FAIL] ${name}" >&2
    return 1
  fi
}

assert_fail_code() {
  local expected="$1"
  local name="$2"
  shift 2
  set +e
  "$@" >/dev/null 2>&1
  local got=$?
  set -e
  if [[ "${got}" -eq "${expected}" ]]; then
    echo "[PASS] ${name}"
  else
    echo "[FAIL] ${name} (expected ${expected}, got ${got})" >&2
    return 1
  fi
}

env "${BASE_ENV[@]}" ./plume.sh mode use native --force --yes >/dev/null

assert_ok "native alias php-fpm -> php (up)" \
  env "${BASE_ENV[@]}" ./plume.sh services up php-fpm --mode=native

assert_ok "native alias workspace -> composer (up)" \
  env "${BASE_ENV[@]}" ./plume.sh services up workspace --mode=native

assert_ok "native status shows php running after php-fpm alias" \
  bash -lc "env HOME='${HOME_DIR}' PLUME_STATE_DIR='${STATE_DIR}' ./plume.sh services status --mode=native | grep -q '^php[[:space:]].*true'"

assert_ok "native status shows composer running after workspace alias" \
  bash -lc "env HOME='${HOME_DIR}' PLUME_STATE_DIR='${STATE_DIR}' ./plume.sh services status --mode=native | grep -q '^composer[[:space:]].*true'"

assert_fail_code 2 "native alias laravel-horizon requires supervisor" \
  env "${BASE_ENV[@]}" PLUME_SUPERVISOR_ENABLED=false ./plume.sh services up laravel-horizon --mode=native

assert_ok "native alias laravel-horizon works with supervisor enabled" \
  env "${BASE_ENV[@]}" PLUME_SUPERVISOR_ENABLED=true PLUME_HORIZON_ENABLED=true ./plume.sh services up laravel-horizon --mode=native

echo "phase11-native-adapter-contract-smoke:ok"
