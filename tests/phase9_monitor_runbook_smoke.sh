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

for scenario in incident recovery ports-conflict; do
  out="$(env "${BASE_ENV[@]}" ./plume.sh monitor runbook --mode=native --scenario="${scenario}")"
  printf '%s\n' "${out}" | grep -q "^RUNBOOK           ${scenario}$" || {
    echo "[FAIL] runbook output should include selected scenario: ${scenario}" >&2
    printf '%s\n' "${out}" >&2
    exit 1
  }
  printf '%s\n' "${out}" | grep -q '^STEP              COMMAND$' || {
    echo "[FAIL] runbook output should include step table header" >&2
    printf '%s\n' "${out}" >&2
    exit 1
  }
done

set +e
env "${BASE_ENV[@]}" ./plume.sh monitor runbook --mode=native --scenario=unknown >/dev/null 2>&1
rc=$?
set -e
if [[ "${rc}" -ne 2 ]]; then
  echo "[FAIL] unknown runbook scenario should return code 2" >&2
  exit 1
fi

echo "phase9-monitor-runbook-smoke:ok"
