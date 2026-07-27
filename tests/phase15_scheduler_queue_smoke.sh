#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

TMP_ROOT="$(mktemp -d)"
HOME_DIR="${TMP_ROOT}/home"
STATE_DIR="${TMP_ROOT}/state"
REG_DIR="${TMP_ROOT}/registry"
PROJECT_DIR="${TMP_ROOT}/project"
mkdir -p "${HOME_DIR}" "${STATE_DIR}" "${REG_DIR}" "${PROJECT_DIR}/public"

cleanup() {
  if [[ -n "${SITE_ID:-}" ]]; then
    env "${BASE_ENV[@]}" ./plume.sh site remove "${SITE_ID}" >/dev/null 2>&1 || true
  fi
  rm -rf "${TMP_ROOT}"
}
trap cleanup EXIT

BASE_ENV=(
  "HOME=${HOME_DIR}"
  "PLUME_STATE_DIR=${STATE_DIR}"
  "PLUME_SITE_REGISTRY_DIR=${REG_DIR}"
  "PLUME_SKIP_ON_FIRST_RUN_PROVISION=true"
)

printf '#!/usr/bin/env php\n<?php\n' > "${PROJECT_DIR}/artisan"
chmod +x "${PROJECT_DIR}/artisan"

SITE_ID="$(env "${BASE_ENV[@]}" ./plume.sh site add --path="${PROJECT_DIR}" --domain=sched-queue.test --server=nginx)"
[[ -n "${SITE_ID}" && -f "${REG_DIR}/${SITE_ID}.yml" ]] || {
  echo "[FAIL] site add failed" >&2
  exit 1
}

sched_out="$(cd "${PROJECT_DIR}" && env "${BASE_ENV[@]}" "${ROOT_DIR}/plume.sh" schedule status --mode=native)"
echo "${sched_out}" | grep -qF "${PROJECT_DIR}" || {
  echo "[FAIL] schedule status missing project path" >&2
  printf '%s\n' "${sched_out}" >&2
  exit 1
}
echo "${sched_out}" | grep -q 'schedule:run' || {
  echo "[FAIL] schedule status missing cron hint" >&2
  exit 1
}
echo "${sched_out}" | grep -q 'ARTISAN.*present' || {
  echo "[FAIL] schedule status should detect artisan" >&2
  exit 1
}

queue_out="$(env "${BASE_ENV[@]}" PLUME_HORIZON_ENABLED=true PLUME_SUPERVISOR_ENABLED=true "${ROOT_DIR}/plume.sh" queue status --mode=native --path="${PROJECT_DIR}")"
echo "${queue_out}" | grep -q 'HORIZON.*env=true' || {
  echo "[FAIL] queue status should show horizon env enabled" >&2
  printf '%s\n' "${queue_out}" >&2
  exit 1
}
echo "${queue_out}" | grep -q 'services up horizon' || {
  echo "[FAIL] queue status should hint services up horizon" >&2
  exit 1
}

json_out="$(env "${BASE_ENV[@]}" ./plume.sh --json schedule status --path="${PROJECT_DIR}" --mode=native)"
if command -v python3 >/dev/null 2>&1; then
  printf '%s' "${json_out}" | python3 -c "
import json, sys
data = json.load(sys.stdin)
assert data.get('ok') is True
assert data.get('command') == 'schedule status'
assert 'project_path' in data.get('data', {})
assert 'cron_hint' in data.get('data', {})
" || {
    echo "[FAIL] schedule status json contract" >&2
    exit 1
  }
fi

echo "phase15_scheduler_queue_smoke:ok"
