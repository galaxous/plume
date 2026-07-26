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

assert_file_has() {
  local expected="$1"
  local file="$2"
  if grep -Fq -- "${expected}" "${file}"; then
    echo "[PASS] found '${expected}' in ${file}"
  else
    echo "[FAIL] missing '${expected}' in ${file}" >&2
    return 1
  fi
}

assert_file_not_has() {
  local expected="$1"
  local file="$2"
  if grep -Fq -- "${expected}" "${file}"; then
    echo "[FAIL] unexpected '${expected}' in ${file}" >&2
    return 1
  else
    echo "[PASS] removed '${expected}' from ${file}"
  fi
}

cleanup() {
  rm -rf "${TMP_ROOT}"
}

trap cleanup EXIT

TMP_ROOT="$(mktemp -d)"
HOSTS_FILE="${TMP_ROOT}/hosts"
printf '%s\n' '127.0.0.1 localhost' > "${HOSTS_FILE}"

for mode in native docker-lite laradock-bridge; do
  MODE_HOME="${TMP_ROOT}/${mode}-home"
  SITE_ROOT="${TMP_ROOT}/${mode}-hosts-project/public"
  SITE_REGISTRY="${MODE_HOME}/.config/plume/sites"
  mkdir -p "${SITE_ROOT}" "${MODE_HOME}"

  DOMAIN="plume-hosts-${mode}.test"
  SITE_ID="$(HOME="${MODE_HOME}" PLUME_SITE_REGISTRY_DIR="${SITE_REGISTRY}" PLUME_SITE_HOSTS_SYNC=true PLUME_HOSTS_FILE="${HOSTS_FILE}" ./plume.sh site add --mode="${mode}" --path="${SITE_ROOT}" --domain="${DOMAIN}" --server=nginx --publish)"

  assert_ok "site id created (${mode})" test -n "${SITE_ID}"
  assert_ok "publish reload (${mode})" bash -lc "HOME=${MODE_HOME} PLUME_SITE_REGISTRY_DIR=${SITE_REGISTRY} PLUME_SITE_HOSTS_SYNC=true PLUME_HOSTS_FILE=${HOSTS_FILE} ./plume.sh site publish --mode=${mode} ${SITE_ID} --reload"

  assert_file_has "plume-site:${SITE_ID}" "${HOSTS_FILE}"
  assert_file_has "${DOMAIN}" "${HOSTS_FILE}"

  HOME="${MODE_HOME}" PLUME_SITE_REGISTRY_DIR="${SITE_REGISTRY}" PLUME_SITE_HOSTS_SYNC=true PLUME_HOSTS_FILE="${HOSTS_FILE}" ./plume.sh site remove --mode="${mode}" "${SITE_ID}" >/dev/null
  assert_file_not_has "plume-site:${SITE_ID}" "${HOSTS_FILE}"
  assert_file_not_has "${DOMAIN}" "${HOSTS_FILE}"
done

echo "phase5-hosts-reload-parity-smoke:ok"
