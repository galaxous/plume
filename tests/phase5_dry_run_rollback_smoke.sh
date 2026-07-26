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
  "$@" >/tmp/plume-phase5-dryrun.out 2>&1
  local got=$?
  set -e
  if [[ "${got}" -eq "${expected}" ]]; then
    echo "[PASS] ${name}"
  else
    echo "[FAIL] ${name} (expected ${expected}, got ${got})" >&2
    cat /tmp/plume-phase5-dryrun.out >&2
    return 1
  fi
}

cleanup() {
  rm -rf "${TMP_ROOT}"
  rm -f /tmp/plume-phase5-dryrun.out
}
trap cleanup EXIT

TMP_ROOT="$(mktemp -d)"
MODE_HOME="${TMP_ROOT}/home"
SITE_ROOT="${TMP_ROOT}/project/public"
SITE_REGISTRY="${MODE_HOME}/.config/plume/sites"
mkdir -p "${SITE_ROOT}" "${MODE_HOME}"

SITE_ID="$(HOME="${MODE_HOME}" PLUME_SITE_REGISTRY_DIR="${SITE_REGISTRY}" PLUME_SITE_HOSTS_SYNC=false ./plume.sh site add --mode=native --path="${SITE_ROOT}" --domain="dryrun-old.test" --server=nginx --publish)"
assert_ok "site add" test -n "${SITE_ID}"

SITE_FILE="${SITE_REGISTRY}/${SITE_ID}.yml"
assert_ok "record has old domain" grep -q 'dryrun-old.test' "${SITE_FILE}"

assert_ok "update dry-run" bash -lc "HOME=${MODE_HOME} PLUME_SITE_REGISTRY_DIR=${SITE_REGISTRY} ./plume.sh site update ${SITE_ID} --domain=dryrun-new.test --publish --dry-run"
assert_ok "domain unchanged after update dry-run" grep -q 'dryrun-old.test' "${SITE_FILE}"

SNIPPET_FILE="${SITE_REGISTRY}/nginx/${SITE_ID}.conf"
OLD_SNIPPET_SUM="$(shasum "${SNIPPET_FILE}" | awk '{print $1}')"
assert_ok "publish dry-run" bash -lc "HOME=${MODE_HOME} PLUME_SITE_REGISTRY_DIR=${SITE_REGISTRY} ./plume.sh site publish ${SITE_ID} --reload --dry-run"
NEW_SNIPPET_SUM="$(shasum "${SNIPPET_FILE}" | awk '{print $1}')"
assert_ok "snippet unchanged after publish dry-run" test "${OLD_SNIPPET_SUM}" = "${NEW_SNIPPET_SUM}"

assert_ok "remove dry-run" bash -lc "HOME=${MODE_HOME} PLUME_SITE_REGISTRY_DIR=${SITE_REGISTRY} ./plume.sh site remove ${SITE_ID} --dry-run"
assert_ok "record still exists after remove dry-run" test -f "${SITE_FILE}"

assert_fail_code 2 "update publish fails when hosts required and missing" \
  env HOME="${MODE_HOME}" \
      PLUME_SITE_REGISTRY_DIR="${SITE_REGISTRY}" \
      PLUME_SITE_HOSTS_SYNC=true \
      PLUME_SITE_HOSTS_REQUIRED=true \
      PLUME_HOSTS_FILE="${TMP_ROOT}/missing/hosts" \
      ./plume.sh site update "${SITE_ID}" --domain=should-rollback.test --publish

assert_ok "record rolled back after failed publish" grep -q 'dryrun-old.test' "${SITE_FILE}"
assert_ok "rollback domain not persisted" bash -lc "! grep -q 'should-rollback.test' '${SITE_FILE}'"

HOME="${MODE_HOME}" PLUME_SITE_REGISTRY_DIR="${SITE_REGISTRY}" ./plume.sh site remove "${SITE_ID}" >/dev/null

echo "phase5-dry-run-rollback-smoke:ok"
