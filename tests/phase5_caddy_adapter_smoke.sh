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

assert_contains_file() {
  local expected="$1"
  local file="$2"
  if grep -Fq -- "${expected}" "${file}"; then
    echo "[PASS] contains '${expected}' in ${file}"
  else
    echo "[FAIL] missing '${expected}' in ${file}" >&2
    return 1
  fi
}

assert_not_exists() {
  local file="$1"
  if [[ ! -f "${file}" ]]; then
    echo "[PASS] removed ${file}"
  else
    echo "[FAIL] unexpected file still exists: ${file}" >&2
    return 1
  fi
}

cleanup() {
  rm -rf "${TMP_ROOT}"
}

trap cleanup EXIT

TMP_ROOT="$(mktemp -d)"

for mode in native docker-lite laradock-bridge; do
  MODE_HOME="${TMP_ROOT}/${mode}-home"
  SITE_ROOT="${TMP_ROOT}/${mode}-caddy-project/public"
  mkdir -p "${SITE_ROOT}" "${MODE_HOME}"

  PLUME_MODE_ENV="${mode}"
  PLUME_SITE_REGISTRY_DIR="${MODE_HOME}/.config/plume/sites"
  PLUME_SITE_HOSTS_SYNC="false"
  PLUME_SITE_HOSTS_REQUIRED="false"

  DOMAIN="plume-caddy-${mode}.test"
  SITE_ID="$(HOME="${MODE_HOME}" PLUME_SITE_REGISTRY_DIR="${PLUME_SITE_REGISTRY_DIR}" PLUME_SITE_HOSTS_SYNC="${PLUME_SITE_HOSTS_SYNC}" ./plume.sh site add --mode="${PLUME_MODE_ENV}" --path="${SITE_ROOT}" --domain="${DOMAIN}" --server=caddy --publish)"

  if [[ -z "${SITE_ID}" ]]; then
    echo "[FAIL] site add id empty for ${mode}" >&2
    exit 1
  fi

  case "${mode}" in
    native) snippet_dir="${PLUME_SITE_REGISTRY_DIR}/caddy" ;;
    docker-lite) snippet_dir="${MODE_HOME}/.config/plume/docker-lite/sites/caddy" ;;
    laradock-bridge) snippet_dir="${MODE_HOME}/.config/plume/laradock-bridge/sites/caddy" ;;
  esac

  SNIPPET_FILE="${snippet_dir}/${SITE_ID}.conf"
  assert_contains_file "${DOMAIN} {" "${SNIPPET_FILE}"
  assert_contains_file "root * ${SITE_ROOT}" "${SNIPPET_FILE}"
  assert_contains_file "file_server" "${SNIPPET_FILE}"

  assert_ok "site publish reload (${mode})" bash -lc "HOME=${MODE_HOME} PLUME_SITE_REGISTRY_DIR=${PLUME_SITE_REGISTRY_DIR} ./plume.sh site publish --mode=${PLUME_MODE_ENV} ${SITE_ID} --reload"

  HOME="${MODE_HOME}" PLUME_SITE_REGISTRY_DIR="${PLUME_SITE_REGISTRY_DIR}" ./plume.sh site remove --mode="${PLUME_MODE_ENV}" "${SITE_ID}" >/dev/null
  assert_not_exists "${SNIPPET_FILE}"
done

echo "phase5-caddy-adapter-smoke:ok"
