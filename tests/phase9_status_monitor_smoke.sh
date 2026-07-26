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

status_out="$(env "${BASE_ENV[@]}" ./plume.sh status --mode=native)"
printf '%s\n' "${status_out}" | grep -q '^SERVICE' || {
  echo "[FAIL] status should print service table" >&2
  printf '%s\n' "${status_out}" >&2
  exit 1
}

health_out="$(env "${BASE_ENV[@]}" ./plume.sh health --mode=native)"
printf '%s\n' "${health_out}" | grep -q '^SERVICE           HEALTH$' || {
  echo "[FAIL] health should print health table" >&2
  printf '%s\n' "${health_out}" >&2
  exit 1
}

summary_out="$(env "${BASE_ENV[@]}" ./plume.sh monitor summary --mode=native)"
printf '%s\n' "${summary_out}" | grep -q '^SECTION           COMMAND$' || {
  echo "[FAIL] monitor summary should print summary header" >&2
  printf '%s\n' "${summary_out}" >&2
  exit 1
}
printf '%s\n' "${summary_out}" | grep -q '^OVERALL           ' || {
  echo "[FAIL] monitor summary should print overall state" >&2
  printf '%s\n' "${summary_out}" >&2
  exit 1
}

set +e
env "${BASE_ENV[@]}" ./plume.sh monitor summary --mode=native --strict >/dev/null 2>&1
strict_rc=$?
set -e
if [[ "${strict_rc}" -ne 2 ]]; then
  echo "[FAIL] monitor summary --strict should return 2 when critical issues exist" >&2
  exit 1
fi

# logs wrapper should delegate successfully for at least one known service.
env "${BASE_ENV[@]}" ./plume.sh logs php --mode=native --tail=1 >/dev/null

if command -v sqlite3 >/dev/null 2>&1; then
  events_out="$(env "${BASE_ENV[@]}" ./plume.sh monitor events --mode=native --limit=20)"
  printf '%s\n' "${events_out}" | grep -q 'ops.status.ok' || {
    echo "[FAIL] monitor events should include audit events" >&2
    printf '%s\n' "${events_out}" >&2
    exit 1
  }
fi

echo "phase9-status-monitor-smoke:ok"
