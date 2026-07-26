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
  "PLUME_PHP_DEFAULT_VERSION=8.3"
  "PLUME_PHP_VERSION=8.3"
)

SITE_ID="$(env "${BASE_ENV[@]}" ./plume.sh site add --mode=native --path="${PROJECT_DIR}" --domain="php82-resolver.test" --server=nginx --php=8.2 --publish | tail -n 1)"
[[ -n "${SITE_ID}" ]] || {
  echo "[FAIL] site add should return id" >&2
  exit 1
}

CONF_FILE="${SITE_REGISTRY}/nginx/${SITE_ID}.conf"
RECORD="${SITE_REGISTRY}/${SITE_ID}.yml"
[[ -f "${CONF_FILE}" ]] || {
  echo "[FAIL] expected nginx conf file: ${CONF_FILE}" >&2
  exit 1
}

grep -q '# Plume-generated nginx site.*php=8.2' "${CONF_FILE}" || {
  echo "[FAIL] expected php=8.2 in nginx conf header" >&2
  cat "${CONF_FILE}" >&2 || true
  exit 1
}

if [[ -x /opt/homebrew/opt/php@8.2/sbin/php-fpm ]]; then
  grep -q 'fastcgi_pass unix:/opt/homebrew/var/run/php@8.2-fpm.sock;' "${CONF_FILE}" || {
    echo "[FAIL] non-default php 8.2 must not fall back to shared 127.0.0.1:9000 on Homebrew" >&2
    cat "${CONF_FILE}" >&2 || true
    exit 1
  }
  grep -q 'fastcgi_pass 127.0.0.1:9000;' "${CONF_FILE}" && {
    echo "[FAIL] php 8.2 site must not use default TCP pool 127.0.0.1:9000" >&2
    cat "${CONF_FILE}" >&2 || true
    exit 1
  }
else
  grep -Eq 'fastcgi_pass (unix:|php82-fpm:9000|127\.0\.0\.1:9000);' "${CONF_FILE}" || {
    echo "[FAIL] expected a resolved fastcgi_pass upstream" >&2
    cat "${CONF_FILE}" >&2 || true
    exit 1
  }
fi

env "${BASE_ENV[@]}" ./plume.sh site update "${SITE_ID}" --php=8.1 --publish >/dev/null
grep -q 'php=8.1' "${CONF_FILE}" || {
  echo "[FAIL] publish after php_version change should refresh snippet header" >&2
  cat "${CONF_FILE}" >&2 || true
  exit 1
}
grep -q '^php_version: 8.1$' "${RECORD}" || {
  echo "[FAIL] site record php_version should be 8.1" >&2
  cat "${RECORD}" >&2 || true
  exit 1
}

echo "phase11-site-php-upstream-resolver-smoke:ok"
