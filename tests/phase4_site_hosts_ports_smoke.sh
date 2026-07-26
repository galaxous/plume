#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"
SITE_REGISTRY_DIR="${TMPDIR:-/tmp}/plume-test-site-registry-${RANDOM}-${RANDOM}"

assert_ok() {
  local name="$1"
  shift
  if output="$($@ 2>&1)"; then
    echo "[PASS] ${name}"
  else
    echo "[FAIL] ${name}" >&2
    printf '%s\n' "${output}" >&2
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

assert_not_contains_file() {
  local needle="$1"
  local file="$2"
  if grep -Fq -- "${needle}" "${file}"; then
    echo "[FAIL] unexpected '${needle}' in ${file}" >&2
    return 1
  else
    echo "[PASS] removed '${needle}' from ${file}"
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
  if [[ -n "${SITE_ID:-}" ]]; then
    PLUME_HOSTS_FILE="${HOSTS_FILE}" ./plume.sh site remove "${SITE_ID}" >/dev/null 2>&1 || true
  fi
  rm -rf "${TMP_ROOT}" "${HOSTS_FILE}" "${PLUME_SITE_REGISTRY_DIR:-}"
}

trap cleanup EXIT

TMP_ROOT="$(mktemp -d)"
HOSTS_FILE="${TMP_ROOT}/hosts"
printf '%s\n' '127.0.0.1 localhost' > "${HOSTS_FILE}"
export PLUME_SITE_REGISTRY_DIR="${SITE_REGISTRY_DIR}"
export PLUME_SITE_HOSTS_REQUIRED=true

SITE_ROOT_1="${TMP_ROOT}/project-one"
SITE_ROOT_2="${TMP_ROOT}/project-two"
mkdir -p "${SITE_ROOT_1}/public" "${SITE_ROOT_2}/public"
SITE_SNIPPET_CACHE_DIR="${PLUME_SITE_REGISTRY_DIR}"

SITE_ID="$(PLUME_HOSTS_FILE="${HOSTS_FILE}" PLUME_SITE_HOSTS_SYNC=true ./plume.sh site add --path="${SITE_ROOT_1}" --domain=hostedone.test --port=8080 --publish)"
SITE_MODE="$(awk '/^mode:/ {print $2; exit}' "${PLUME_SITE_REGISTRY_DIR}/${SITE_ID}.yml")"
case "${SITE_MODE}" in
  native) SITE_SNIPPET_CACHE_DIR="${PLUME_SITE_REGISTRY_DIR}" ;;
  docker-lite) SITE_SNIPPET_CACHE_DIR="${HOME}/.config/plume/docker-lite/sites" ;;
  laradock-bridge) SITE_SNIPPET_CACHE_DIR="${HOME}/.config/plume/laradock-bridge/sites" ;;
  *) SITE_SNIPPET_CACHE_DIR="${PLUME_SITE_REGISTRY_DIR}" ;;
esac

assert_ok "site add with custom port" test -n "${SITE_ID}" >/dev/null
assert_ok "snippet contains custom port" grep -Fq -- 'listen 8080;' "${SITE_SNIPPET_CACHE_DIR}/nginx/${SITE_ID}.conf"
assert_file_has "plume-site:${SITE_ID}" "${HOSTS_FILE}"
assert_file_has "hostedone.test" "${HOSTS_FILE}"

assert_fail_code 2 "port conflict blocked on add (strict mode)" env PLUME_HOSTS_FILE="${HOSTS_FILE}" PLUME_SITE_HOSTS_SYNC=true PLUME_SITE_PORT_CONFLICT_CHECK=true ./plume.sh site add --path="${SITE_ROOT_2}" --domain=hostedtwo.test --port=8080 --publish >/dev/null

PLUME_HOSTS_FILE="${HOSTS_FILE}" ./plume.sh site update "${SITE_ID}" --domain=hostedone-updated.test --publish
assert_file_has "hostedone-updated.test" "${HOSTS_FILE}"
assert_not_contains_file "hostedone.test" "${HOSTS_FILE}"

PLUME_HOSTS_FILE="${HOSTS_FILE}" ./plume.sh site publish "${SITE_ID}"
assert_file_has "# plume-site:${SITE_ID}" "${HOSTS_FILE}"

echo "phase4-site-hosts-ports-smoke:ok"
