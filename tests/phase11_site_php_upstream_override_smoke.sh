#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

TMP_ROOT="$(mktemp -d)"
HOME_DIR="${TMP_ROOT}/home"
SITE_REGISTRY="${TMP_ROOT}/registry"
PROJECT_DIR="${TMP_ROOT}/project"
mkdir -p "${HOME_DIR}" "${SITE_REGISTRY}" "${PROJECT_DIR}/public"

cleanup() {
  rm -rf "${TMP_ROOT}"
}
trap cleanup EXIT

BASE_ENV=(
  "HOME=${HOME_DIR}"
  "PLUME_SITE_REGISTRY_DIR=${SITE_REGISTRY}"
  "PLUME_SITE_HOSTS_SYNC=false"
)

SITE_ID="$(env "${BASE_ENV[@]}" ./plume.sh site add --mode=native --path="${PROJECT_DIR}" --domain="upstream.test" --server=nginx --php=8.2 --php-upstream="unix:/tmp/php82-fpm.sock" --publish | tail -n 1)"
[[ -n "${SITE_ID}" ]] || {
  echo "[FAIL] site add should return id" >&2
  exit 1
}

CONF_FILE="${SITE_REGISTRY}/nginx/${SITE_ID}.conf"
[[ -f "${CONF_FILE}" ]] || {
  echo "[FAIL] expected nginx conf file: ${CONF_FILE}" >&2
  exit 1
}

grep -q 'fastcgi_pass unix:/tmp/php82-fpm.sock;' "${CONF_FILE}" || {
  echo "[FAIL] expected custom unix upstream in nginx conf" >&2
  cat "${CONF_FILE}" >&2 || true
  exit 1
}

CHECK_OUT="$(env "${BASE_ENV[@]}" ./plume.sh site check "${SITE_ID}")"
printf '%s\n' "${CHECK_OUT}" | grep -q '^php_upstream: unix:/tmp/php82-fpm.sock$' || {
  echo "[FAIL] expected php_upstream in site check output" >&2
  printf '%s\n' "${CHECK_OUT}" >&2
  exit 1
}
printf '%s\n' "${CHECK_OUT}" | grep -q '^php_upstream_resolved: unix:/tmp/php82-fpm.sock$' || {
  echo "[FAIL] expected resolved upstream in site check output" >&2
  printf '%s\n' "${CHECK_OUT}" >&2
  exit 1
}

env "${BASE_ENV[@]}" ./plume.sh site update "${SITE_ID}" --php-upstream="php82-fpm:9100" --publish >/dev/null

grep -q 'fastcgi_pass php82-fpm:9100;' "${CONF_FILE}" || {
  echo "[FAIL] expected updated tcp upstream in nginx conf" >&2
  cat "${CONF_FILE}" >&2 || true
  exit 1
}

set +e
env "${BASE_ENV[@]}" ./plume.sh site update "${SITE_ID}" --php-upstream="bad format" >/tmp/plume-phase11-site-upstream-invalid.out 2>&1
rc=$?
set -e
if [[ ${rc} -ne 2 ]]; then
  echo "[FAIL] invalid php-upstream should return exit 2, got ${rc}" >&2
  cat /tmp/plume-phase11-site-upstream-invalid.out >&2 || true
  exit 1
fi

grep -q 'invalid php upstream format' /tmp/plume-phase11-site-upstream-invalid.out || {
  echo "[FAIL] expected invalid php upstream error output" >&2
  cat /tmp/plume-phase11-site-upstream-invalid.out >&2 || true
  exit 1
}

echo "phase11-site-php-upstream-override-smoke:ok"
