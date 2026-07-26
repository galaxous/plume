#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

TMP_ROOT="$(mktemp -d)"
STATE_DIR="${TMP_ROOT}/state"
DL_PATH="${TMP_ROOT}/dl"
LB_PATH="${TMP_ROOT}/lb"
mkdir -p "${DL_PATH}" "${LB_PATH}"

cleanup() {
  rm -rf "${TMP_ROOT}"
}
trap cleanup EXIT

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
  "$@" >/tmp/plume-phase7-mode-path.out 2>&1
  local got=$?
  set -e
  if [[ "${got}" -eq "${expected}" ]]; then
    echo "[PASS] ${name}"
  else
    echo "[FAIL] ${name} (expected ${expected}, got ${got})" >&2
    cat /tmp/plume-phase7-mode-path.out >&2
    return 1
  fi
}

BASE_ENV=("PLUME_STATE_DIR=${STATE_DIR}")

assert_ok "set docker-lite path" env "${BASE_ENV[@]}" ./plume.sh mode path set docker-lite "${DL_PATH}"
assert_ok "get docker-lite path" bash -lc "env PLUME_STATE_DIR='${STATE_DIR}' ./plume.sh mode path get docker-lite | grep -q '${DL_PATH}'"
assert_ok "set laradock path" env "${BASE_ENV[@]}" ./plume.sh mode path set laradock-bridge "${LB_PATH}"
assert_ok "list paths" bash -lc "env PLUME_STATE_DIR='${STATE_DIR}' ./plume.sh mode path list | grep -q 'docker-lite'"
assert_ok "clear docker-lite path" env "${BASE_ENV[@]}" ./plume.sh mode path clear docker-lite
assert_fail_code 2 "reject invalid mode for mode path set" env "${BASE_ENV[@]}" ./plume.sh mode path set native "${DL_PATH}"

echo "phase7-mode-path-registry-smoke:ok"
