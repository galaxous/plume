#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

TMP_ROOT="$(mktemp -d)"
HOME_DIR="${TMP_ROOT}/home"
STATE_DIR="${TMP_ROOT}/state"
REG_DIR="${TMP_ROOT}/registry"
PROJECT_DIR="${TMP_ROOT}/project"
BIN_DIR="${TMP_ROOT}/bin"
CMD_LOG="${TMP_ROOT}/php-artisan.log"
CRON_FILE="${TMP_ROOT}/user.crontab"
mkdir -p "${HOME_DIR}" "${STATE_DIR}" "${REG_DIR}" "${PROJECT_DIR}/public" "${BIN_DIR}"

cleanup() {
  if [[ -n "${SITE_ID:-}" ]]; then
    env "${BASE_ENV[@]}" ./plume.sh site remove "${SITE_ID}" >/dev/null 2>&1 || true
  fi
  rm -rf "${TMP_ROOT}"
}
trap cleanup EXIT

cat > "${BIN_DIR}/php" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'php %s\n' "$*" >> "${PLUME_TEST_PHP_LOG}"
if [[ "${1:-}" == "artisan" ]]; then
  shift
  case "${1:-}" in
    schedule:list)
      printf 'stub schedule:list\n'
      exit 0
      ;;
    schedule:run)
      printf 'stub schedule:run\n'
      exit 0
      ;;
    queue:failed)
      printf 'stub queue:failed\n'
      exit 0
      ;;
    *)
      exit 1
      ;;
  esac
fi
exit 0
EOF
chmod +x "${BIN_DIR}/php"

BASE_ENV=(
  "HOME=${HOME_DIR}"
  "PLUME_STATE_DIR=${STATE_DIR}"
  "PLUME_SITE_REGISTRY_DIR=${REG_DIR}"
  "PLUME_SKIP_ON_FIRST_RUN_PROVISION=true"
  "PATH=${BIN_DIR}:/usr/bin:/bin"
  "PLUME_PHP_BIN=${BIN_DIR}/php"
  "PLUME_TEST_PHP_LOG=${CMD_LOG}"
  "PLUME_CRONTAB_FILE=${CRON_FILE}"
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

list_out="$(env "${BASE_ENV[@]}" "${ROOT_DIR}/plume.sh" schedule list --path="${PROJECT_DIR}")"
echo "${list_out}" | grep -q 'stub schedule:list' || {
  echo "[FAIL] schedule list should run artisan schedule:list" >&2
  printf '%s\n' "${list_out}" >&2
  exit 1
}
grep -Fq 'php artisan schedule:list' "${CMD_LOG}" || {
  echo "[FAIL] schedule list should invoke php artisan schedule:list" >&2
  cat "${CMD_LOG}" >&2
  exit 1
}

dry_out="$(env "${BASE_ENV[@]}" "${ROOT_DIR}/plume.sh" schedule run-once --path="${PROJECT_DIR}" --dry-run 2>&1)"
echo "${dry_out}" | grep -qF "schedule:run --no-interaction" || {
  echo "[FAIL] schedule run-once --dry-run missing planned command" >&2
  printf '%s\n' "${dry_out}" >&2
  exit 1
}
grep -Fq 'php artisan schedule:run' "${CMD_LOG}" && {
  echo "[FAIL] dry-run should not execute artisan" >&2
  exit 1
} || true

run_out="$(env "${BASE_ENV[@]}" "${ROOT_DIR}/plume.sh" schedule run-once --path="${PROJECT_DIR}" 2>&1)"
echo "${run_out}" | grep -q 'stub schedule:run' || {
  echo "[FAIL] schedule run-once should run artisan" >&2
  printf '%s\n' "${run_out}" >&2
  exit 1
}

queue_out="$(env "${BASE_ENV[@]}" PLUME_HORIZON_ENABLED=true PLUME_SUPERVISOR_ENABLED=true "${ROOT_DIR}/plume.sh" queue status --mode=native --path="${PROJECT_DIR}" 2>&1)"
echo "${queue_out}" | grep -q 'HORIZON.*env=true' || {
  echo "[FAIL] queue status should show horizon env enabled" >&2
  printf '%s\n' "${queue_out}" >&2
  exit 1
}
echo "${queue_out}" | grep -q 'services up horizon' || {
  echo "[FAIL] queue status should hint services up horizon" >&2
  printf '%s\n' "${queue_out}" >&2
  exit 1
}

queue_list_out="$(env "${BASE_ENV[@]}" PLUME_HORIZON_ENABLED=true "${ROOT_DIR}/plume.sh" queue list --mode=native --path="${PROJECT_DIR}" 2>&1)"
echo "${queue_list_out}" | grep -q 'stub queue:failed' || {
  echo "[FAIL] queue list should run queue:failed" >&2
  printf '%s\n' "${queue_list_out}" >&2
  exit 1
}
echo "${queue_list_out}" | grep -q 'horizon:status' || {
  echo "[FAIL] queue list should hint horizon:status when horizon enabled" >&2
  exit 1
}

cron_dry_out="$(env "${BASE_ENV[@]}" "${ROOT_DIR}/plume.sh" schedule cron-install --path="${PROJECT_DIR}" --dry-run 2>&1)"
echo "${cron_dry_out}" | grep -qF '# plume-laravel-schedule-cron' || {
  echo "[FAIL] cron-install --dry-run missing marker" >&2
  printf '%s\n' "${cron_dry_out}" >&2
  exit 1
}
echo "${cron_dry_out}" | grep -qF "${PROJECT_DIR}" || {
  echo "[FAIL] cron-install --dry-run missing project path" >&2
  exit 1
}
[[ ! -f "${CRON_FILE}" ]] || [[ ! -s "${CRON_FILE}" ]] || {
  echo "[FAIL] cron-install --dry-run should not write crontab file" >&2
  cat "${CRON_FILE}" >&2
  exit 1
}

env "${BASE_ENV[@]}" "${ROOT_DIR}/plume.sh" schedule cron-install --path="${PROJECT_DIR}" >/dev/null
grep -Fq '# plume-laravel-schedule-cron' "${CRON_FILE}" || {
  echo "[FAIL] cron-install should write marked line" >&2
  cat "${CRON_FILE}" >&2
  exit 1
}
grep -Fq "schedule:run" "${CRON_FILE}" || {
  echo "[FAIL] cron-install missing schedule:run" >&2
  exit 1
}

sched_after="$(env "${BASE_ENV[@]}" "${ROOT_DIR}/plume.sh" schedule status --mode=native --path="${PROJECT_DIR}")"
echo "${sched_after}" | grep -q 'SCHEDULER_CRON.*configured' || {
  echo "[FAIL] schedule status should detect installed cron" >&2
  printf '%s\n' "${sched_after}" >&2
  exit 1
}

env "${BASE_ENV[@]}" "${ROOT_DIR}/plume.sh" schedule cron-install --path="${PROJECT_DIR}" 2>&1 | grep -qi 'already installed' || {
  echo "[FAIL] cron-install should be idempotent when marker present" >&2
  exit 1
}
line_count="$(grep -c '# plume-laravel-schedule-cron' "${CRON_FILE}" || true)"
[[ "${line_count}" -eq 1 ]] || {
  echo "[FAIL] cron-install should keep exactly one marked line" >&2
  cat "${CRON_FILE}" >&2
  exit 1
}

env "${BASE_ENV[@]}" "${ROOT_DIR}/plume.sh" schedule cron-install --path="${PROJECT_DIR}" --remove >/dev/null
grep -Fq '# plume-laravel-schedule-cron' "${CRON_FILE}" && {
  echo "[FAIL] cron-install --remove should delete marked line" >&2
  cat "${CRON_FILE}" >&2
  exit 1
} || true

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
