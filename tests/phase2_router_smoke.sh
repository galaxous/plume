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

assert_ok "help" ./plume.sh --help
assert_ok "version" ./plume.sh --version
assert_ok "mode current" ./plume.sh mode current
assert_ok "mode context" ./plume.sh mode context
assert_ok "env where" ./plume.sh env where
assert_ok "services supported" ./plume.sh services supported
assert_ok "services status json" ./plume.sh --json services status
assert_ok "prereq check" ./plume.sh prereq check
assert_ok "env-file load" bash -lc 'echo "PLUME_REDIS_ENABLED=true" > /tmp/plume-phase2.env && ./plume.sh --env-file /tmp/plume-phase2.env services status | grep -q "redis             true"'
assert_fail_code 2 "env-file missing" ./plume.sh --env-file /tmp/does-not-exist.env services status
assert_fail_code 2 "unknown command" ./plume.sh does-not-exist
assert_ok "site command defaults to list" ./plume.sh site

echo "phase2-router-smoke:ok"
