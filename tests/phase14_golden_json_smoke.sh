#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

assert_json_keys() {
  local name="$1"
  local json="$2"
  shift 2
  if ! command -v python3 >/dev/null 2>&1; then
    echo "[SKIP] ${name} (python3 missing)"
    return 0
  fi
  if ! printf '%s' "${json}" | python3 -c "
import json, sys
data = json.load(sys.stdin)
required = sys.argv[1:]
for k in required:
    if k not in data:
        raise SystemExit(f'missing key: {k}')
" "$@" 2>/dev/null; then
    echo "[FAIL] ${name}" >&2
    printf '%s\n' "${json}" >&2
    return 1
  fi
  echo "[PASS] ${name}"
}

out="$(./plume.sh --json prereq check --profile=base 2>/dev/null || true)"
assert_json_keys "prereq check json" "${out}" ok command data

out="$(./plume.sh --json services supported --mode=native 2>/dev/null || true)"
assert_json_keys "services supported json" "${out}" ok command data

out="$(./plume.sh --json services status --mode=native 2>/dev/null || true)"
assert_json_keys "services status json" "${out}" ok command data

echo "phase14-golden-json-smoke:ok"
