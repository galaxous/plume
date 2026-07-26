#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

TMP_ROOT="$(mktemp -d)"
HOME_DIR="${TMP_ROOT}/home"
STATE_DIR="${TMP_ROOT}/state"
SITE_REGISTRY="${TMP_ROOT}/sites"
mkdir -p "${HOME_DIR}" "${STATE_DIR}" "${SITE_REGISTRY}"

cleanup() {
  rm -rf "${TMP_ROOT}"
}
trap cleanup EXIT

BASE_ENV=(
  "HOME=${HOME_DIR}"
  "PLUME_STATE_DIR=${STATE_DIR}"
  "PLUME_SITE_REGISTRY_DIR=${SITE_REGISTRY}"
  "PLUME_PHP_INSTALLED_VERSIONS=8.3,8.4"
  "PLUME_PHP_DEFAULT_VERSION=8.3"
  "PLUME_PHP_ALIAS_PHP84=8.4"
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

env "${BASE_ENV[@]}" ./plume.sh mode use native --force --yes >/dev/null

assert_ok "services up php84 targets php@8.4" \
  bash -lc "env HOME='${HOME_DIR}' PLUME_STATE_DIR='${STATE_DIR}' PLUME_SITE_REGISTRY_DIR='${SITE_REGISTRY}' PLUME_PHP_INSTALLED_VERSIONS='8.3,8.4' PLUME_PHP_DEFAULT_VERSION='8.3' PLUME_PHP_ALIAS_PHP84='8.4' ./plume.sh services up php84 --mode=native | grep -q 'version=8.4'"

assert_ok "services status php84 resolves to php row" \
  bash -lc "env HOME='${HOME_DIR}' PLUME_STATE_DIR='${STATE_DIR}' PLUME_SITE_REGISTRY_DIR='${SITE_REGISTRY}' PLUME_PHP_INSTALLED_VERSIONS='8.3,8.4' PLUME_PHP_DEFAULT_VERSION='8.3' PLUME_PHP_ALIAS_PHP84='8.4' ./plume.sh services status php84 --mode=native | grep -q '^php[[:space:]]'"

assert_ok "services health php84 resolves to php row" \
  bash -lc "env HOME='${HOME_DIR}' PLUME_STATE_DIR='${STATE_DIR}' PLUME_SITE_REGISTRY_DIR='${SITE_REGISTRY}' PLUME_PHP_INSTALLED_VERSIONS='8.3,8.4' PLUME_PHP_DEFAULT_VERSION='8.3' PLUME_PHP_ALIAS_PHP84='8.4' ./plume.sh services health php84 --mode=native | grep -q '^php[[:space:]]'"

assert_ok "services logs php84 runs" \
  env "${BASE_ENV[@]}" ./plume.sh services logs php84 --mode=native --tail=1

echo "phase11-services-php-alias-target-smoke:ok"
