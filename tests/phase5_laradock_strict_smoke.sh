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
  "$@" >/tmp/plume-phase5-laradock.out 2>&1
  local got=$?
  set -e
  if [[ "${got}" -eq "${expected}" ]]; then
    echo "[PASS] ${name}"
  else
    echo "[FAIL] ${name} (expected ${expected}, got ${got})" >&2
    cat /tmp/plume-phase5-laradock.out >&2
    return 1
  fi
}

cleanup() {
  rm -rf "${TMP_ROOT}"
  rm -f /tmp/plume-phase5-laradock.out
}
trap cleanup EXIT

TMP_ROOT="$(mktemp -d)"
MODE_HOME="${TMP_ROOT}/home"
SITE_ROOT="${TMP_ROOT}/project/public"
SITE_REGISTRY="${MODE_HOME}/.config/plume/sites"
SITE_ROOT_2="${TMP_ROOT}/project-2/public"
mkdir -p "${SITE_ROOT}" "${SITE_ROOT_2}" "${MODE_HOME}"

SITE_OK="$(HOME="${MODE_HOME}" PLUME_SITE_REGISTRY_DIR="${SITE_REGISTRY}" PLUME_SITE_HOSTS_SYNC=false ./plume.sh site add --mode=laradock-bridge --path="${SITE_ROOT}" --domain="laradock-loose.test" --server=nginx --publish)"
assert_ok "laradock publish works in non-strict mode" test -n "${SITE_OK}"

assert_fail_code 2 "laradock strict blocks publish when path missing" \
  env HOME="${MODE_HOME}" \
      PLUME_SITE_REGISTRY_DIR="${SITE_REGISTRY}" \
      PLUME_LARADOCK_STRICT=true \
      PLUME_LARADOCK_PATH="${TMP_ROOT}/missing-laradock" \
      ./plume.sh site add --mode=laradock-bridge --path="${SITE_ROOT}" --domain="laradock-strict.test" --server=nginx --publish

SITE_STRICT="$(HOME="${MODE_HOME}" PLUME_SITE_REGISTRY_DIR="${SITE_REGISTRY}" ./plume.sh site add --mode=laradock-bridge --path="${SITE_ROOT_2}" --domain="laradock-strict-existing.test" --server=nginx --port=8081)"
assert_ok "site add without publish still works" test -n "${SITE_STRICT}"

assert_fail_code 2 "laradock strict blocks publish on existing site" \
  env HOME="${MODE_HOME}" \
      PLUME_SITE_REGISTRY_DIR="${SITE_REGISTRY}" \
      PLUME_LARADOCK_STRICT=true \
      PLUME_LARADOCK_PATH="${TMP_ROOT}/missing-laradock" \
      ./plume.sh site publish --mode=laradock-bridge "${SITE_STRICT}"

HOME="${MODE_HOME}" PLUME_SITE_REGISTRY_DIR="${SITE_REGISTRY}" ./plume.sh site remove --mode=laradock-bridge "${SITE_OK}" >/dev/null
HOME="${MODE_HOME}" PLUME_SITE_REGISTRY_DIR="${SITE_REGISTRY}" ./plume.sh site remove --mode=laradock-bridge "${SITE_STRICT}" >/dev/null

echo "phase5-laradock-strict-smoke:ok"
