#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

TMP_ROOT="$(mktemp -d)"
HOME_DIR="${TMP_ROOT}/home"
STATE_DIR="${TMP_ROOT}/state"
mkdir -p "${HOME_DIR}" "${STATE_DIR}"

cleanup() {
  rm -rf "${TMP_ROOT}"
}
trap cleanup EXIT

BASE_ENV=(
  "HOME=${HOME_DIR}"
  "PLUME_STATE_DIR=${STATE_DIR}"
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

assert_ok "php list works" env "${BASE_ENV[@]}" ./plume.sh php list
assert_ok "php install custom version 8.4" env "${BASE_ENV[@]}" ./plume.sh php install 8.4
assert_ok "php use custom version 8.4" env "${BASE_ENV[@]}" ./plume.sh php use 8.4
# [INFO] start hook … [version=…] is on stderr (D-157) — capture both streams.
assert_ok "services up php uses default 8.4" \
  bash -lc "env HOME='${HOME_DIR}' PLUME_STATE_DIR='${STATE_DIR}' ./plume.sh services up php --mode=native >/tmp/plume-phase11-php.out 2>&1 && grep -q 'version=8.4' /tmp/plume-phase11-php.out"

assert_ok "php alias set php84x -> 8.4" env "${BASE_ENV[@]}" ./plume.sh php alias set php84x 8.4
assert_ok "services up php with custom alias" \
  bash -lc "env HOME='${HOME_DIR}' PLUME_STATE_DIR='${STATE_DIR}' ./plume.sh services up php --mode=native --version=php84x >/tmp/plume-phase11-php-alias.out 2>&1 && grep -q 'version=8.4' /tmp/plume-phase11-php-alias.out"

assert_fail_code 2 "invalid php version blocked" env "${BASE_ENV[@]}" ./plume.sh php install eight.four
assert_fail_code 2 "unsupported alias version blocked" env "${BASE_ENV[@]}" ./plume.sh services up php --mode=native --version=php999

echo "phase11-native-php-matrix-smoke:ok"
