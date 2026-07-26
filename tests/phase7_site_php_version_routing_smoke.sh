#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

assert_ok() {
  local name="$1"
  shift
  if "$@"; then
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

cleanup() {
  set +e
  if [[ -n "${SITE_IDS:-}" ]]; then
    local id
    for id in ${SITE_IDS}; do
      ./plume.sh site remove "${id}" >/dev/null 2>&1 || true
    done
  fi
  rm -rf "${TMP_ROOT}" "${PLUME_SITE_REGISTRY_DIR}"
  set -e
}

TMP_ROOT="$(mktemp -d)"
export PLUME_SITE_REGISTRY_DIR="${TMPDIR:-/tmp}/plume-test-site-php-${RANDOM}-${RANDOM}"
SITE_IDS=""
trap cleanup EXIT

PORT=18080
for SERVER in nginx apache2 caddy; do
  PROJECT="${TMP_ROOT}/sample-${SERVER}/public"
  mkdir -p "${PROJECT}"
  DOMAIN="php-${SERVER}-${RANDOM}.test"
  SITE_ID="$(./plume.sh site add --path="${PROJECT}" --domain="${DOMAIN}" --server="${SERVER}" --port="${PORT}" --php=8.2 --publish)"
  SITE_IDS="${SITE_IDS} ${SITE_ID}"
  RECORD="${PLUME_SITE_REGISTRY_DIR}/${SITE_ID}.yml"
  SITE_MODE="$(awk '/^mode:/ {print $2; exit}' "${RECORD}")"
  case "${SITE_MODE}" in
    native) SNIPPET_DIR="${PLUME_SITE_REGISTRY_DIR}/${SERVER}" ;;
    docker-lite) SNIPPET_DIR="${HOME}/.config/plume/docker-lite/sites/${SERVER}" ;;
    laradock-bridge) SNIPPET_DIR="${HOME}/.config/plume/laradock-bridge/sites/${SERVER}" ;;
    *) SNIPPET_DIR="${PLUME_SITE_REGISTRY_DIR}/${SERVER}" ;;
  esac
  SNIPPET="${SNIPPET_DIR}/${SITE_ID}.conf"

  assert_ok "${SERVER} record php_version 8.2" grep -q '^php_version: 8.2$' "${RECORD}"
  case "${SERVER}" in
    nginx)
      assert_ok "${SERVER} upstream php82" grep -Eq 'fastcgi_pass (php82-fpm:9000|unix:.*php(82|8\.2).*-fpm\.sock);' "${SNIPPET}"
      ;;
    apache2)
      assert_ok "${SERVER} upstream php82" grep -Eq 'SetHandler "(proxy:fcgi://php82-fpm:9000|proxy:unix:.*php(82|8\.2).*-fpm\.sock\|fcgi://localhost/)"' "${SNIPPET}"
      ;;
    caddy)
      assert_ok "${SERVER} upstream php82" grep -Eq 'php_fastcgi (php82-fpm:9000|unix//.*php(82|8\.2).*-fpm\.sock)' "${SNIPPET}"
      ;;
  esac

  ./plume.sh site update "${SITE_ID}" --php=default --publish >/dev/null
  UPDATED_PHP="$(awk '/^php_version:/ {print $2; exit}' "${RECORD}")"
  assert_ok "${SERVER} update php default in record" test -n "${UPDATED_PHP}"
  case "${SERVER}" in
    nginx)
      assert_ok "${SERVER} upstream default" grep -Eq 'fastcgi_pass (php-fpm:9000|unix:.*php.*-fpm\.sock);' "${SNIPPET}"
      ;;
    apache2)
      assert_ok "${SERVER} upstream default" grep -Eq 'SetHandler "(proxy:fcgi://php-fpm:9000|proxy:unix:.*php.*-fpm\.sock\|fcgi://localhost/)"' "${SNIPPET}"
      ;;
    caddy)
      assert_ok "${SERVER} upstream default" grep -Eq 'php_fastcgi (php-fpm:9000|unix//.*php.*-fpm\.sock)' "${SNIPPET}"
      ;;
  esac

  assert_ok "${SERVER} site check includes php_version" bash -lc "./plume.sh site check ${SITE_ID} | grep -q '^php_version: ${UPDATED_PHP}$'"
  PORT=$((PORT + 1))
done

INVALID_PROJECT="${TMP_ROOT}/sample-invalid/public"
mkdir -p "${INVALID_PROJECT}"
assert_fail_code 2 "invalid php version rejected" ./plume.sh site add --path="${INVALID_PROJECT}" --domain="invalid-php.test" --server=nginx --php=8.9

echo "phase7-site-php-version-routing-smoke:ok"
