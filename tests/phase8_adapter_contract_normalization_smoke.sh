#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

TMP_ROOT="$(mktemp -d)"
STATE_DIR="${TMP_ROOT}/state"
HOME_DIR="${TMP_ROOT}/home"
mkdir -p "${STATE_DIR}" "${HOME_DIR}"
mkdir -p "${HOME_DIR}/.config/plume"
: > "${HOME_DIR}/.config/plume/.env"

cleanup() {
  rm -rf "${TMP_ROOT}"
}
trap cleanup EXIT

BASE_ENV=(
  "HOME=${HOME_DIR}"
  "PLUME_STATE_DIR=${STATE_DIR}"
  "PLUME_HORIZON_REQUIRE_SUPERVISOR=false"
  "PLUME_SKIP_ON_FIRST_RUN_PROVISION=true"
  "PLUME_PHP_FPM_VERIFY_AFTER_START=false"
)

env "${BASE_ENV[@]}" ./plume.sh mode use native --force --yes >/dev/null

env "${BASE_ENV[@]}" ./plume.sh services up php-fpm --mode=native >/dev/null
env "${BASE_ENV[@]}" ./plume.sh services up workspace --mode=native >/dev/null
env "${BASE_ENV[@]}" ./plume.sh services up php-worker --mode=native >/dev/null
env "${BASE_ENV[@]}" ./plume.sh services up laravel-horizon --mode=native >/dev/null

STATUS_PHP="$(env "${BASE_ENV[@]}" ./plume.sh services status php --mode=native)"
printf '%s\n' "${STATUS_PHP}" | grep -Eq '^php[[:space:]]+true[[:space:]]+true[[:space:]]+healthy' || {
  echo "[FAIL] expected php to be healthy after php-fpm alias up" >&2
  printf '%s\n' "${STATUS_PHP}" >&2
  exit 1
}

STATUS_COMPOSER="$(env "${BASE_ENV[@]}" ./plume.sh services status composer --mode=native)"
printf '%s\n' "${STATUS_COMPOSER}" | grep -Eq '^composer[[:space:]]+true[[:space:]]+true[[:space:]]+healthy' || {
  echo "[FAIL] expected composer to be healthy after workspace alias up" >&2
  printf '%s\n' "${STATUS_COMPOSER}" >&2
  exit 1
}

STATUS_WORKER="$(env "${BASE_ENV[@]}" ./plume.sh services status php_worker --mode=native)"
printf '%s\n' "${STATUS_WORKER}" | grep -Eq '^php_worker[[:space:]]+' || {
  echo "[FAIL] expected php_worker status to be queryable after php-worker alias up" >&2
  printf '%s\n' "${STATUS_WORKER}" >&2
  exit 1
}

STATUS_HORIZON="$(env "${BASE_ENV[@]}" ./plume.sh services status horizon --mode=native)"
printf '%s\n' "${STATUS_HORIZON}" | grep -Eq '^horizon[[:space:]]+' || {
  echo "[FAIL] expected horizon status to be queryable after laravel-horizon alias up" >&2
  printf '%s\n' "${STATUS_HORIZON}" >&2
  exit 1
}

echo "phase8-adapter-contract-normalization-smoke:ok"
