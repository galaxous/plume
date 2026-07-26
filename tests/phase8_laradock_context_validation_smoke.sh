#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

TMP_ROOT="$(mktemp -d)"
STATE_DIR="${TMP_ROOT}/state"
HOME_DIR="${TMP_ROOT}/home"
mkdir -p "${STATE_DIR}" "${HOME_DIR}"

cleanup() {
  rm -rf "${TMP_ROOT}"
}
trap cleanup EXIT

BASE_ENV=(
  "HOME=${HOME_DIR}"
  "PLUME_STATE_DIR=${STATE_DIR}"
)

set +e
env "${BASE_ENV[@]}" ./plume.sh mode use laradock-bridge --force --yes >/dev/null 2>&1
env "${BASE_ENV[@]}" ./plume.sh services containers --mode=laradock-bridge >/tmp/plume-phase8-laradock-context.out 2>&1
code_a=$?
env "${BASE_ENV[@]}" ./plume.sh services exec composer --mode=laradock-bridge --cmd=sh --no-tty >/tmp/plume-phase8-laradock-context-exec.out 2>&1
code_b=$?
set -e

if [[ "${code_a}" -ne 2 ]]; then
  echo "[FAIL] expected services containers to fail with exit 2 when laradock path is missing (got ${code_a})" >&2
  cat /tmp/plume-phase8-laradock-context.out >&2
  exit 1
fi

if ! grep -q "laradock path is not configured" /tmp/plume-phase8-laradock-context.out; then
  echo "[FAIL] expected containers validation error message" >&2
  cat /tmp/plume-phase8-laradock-context.out >&2
  exit 1
fi

if [[ "${code_b}" -ne 2 ]]; then
  echo "[FAIL] expected services exec to fail with exit 2 when laradock path is missing (got ${code_b})" >&2
  cat /tmp/plume-phase8-laradock-context-exec.out >&2
  exit 1
fi

if ! grep -q "laradock path is not configured" /tmp/plume-phase8-laradock-context-exec.out; then
  echo "[FAIL] expected exec validation error message" >&2
  cat /tmp/plume-phase8-laradock-context-exec.out >&2
  exit 1
fi

echo "phase8-laradock-context-validation-smoke:ok"
