#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

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

assert_ok "prereq base" ./plume.sh prereq check --profile=base
assert_ok "prereq explain" ./plume.sh prereq explain
assert_ok "prereq json" bash -lc './plume.sh --json prereq check --profile=git-ops | grep -q "\"ok\":"'
assert_fail_code 2 "unknown profile" ./plume.sh prereq check --profile=unknown
if [[ "$(id -u)" -eq 0 ]]; then
  echo "[SKIP] root guard tests skipped (running as root)"
else
  assert_fail_code 2 "root guard install" ./plume.sh services install php
  assert_fail_code 2 "root guard update" ./plume.sh services update
fi

if [[ "${PLUME_RUN_LINUX_TESTS:-0}" == "1" ]]; then
  assert_ok "linux matrix" ./tests/linux_prereq_matrix.sh
else
  echo "[SKIP] linux matrix disabled (set PLUME_RUN_LINUX_TESTS=1 to run)"
fi

echo "phase3-prereq-smoke:ok"
