#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

if ! command -v sqlite3 >/dev/null 2>&1; then
  echo "phase9-backup-smoke:skip (sqlite3 not found)"
  exit 0
fi

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

# Seed custom state for config backup/restore check.
printf 'before\n' > "${STATE_DIR}/custom.flag"

create_out="$(env "${BASE_ENV[@]}" ./plume.sh backup create --mode=native --scope=config --name=smoke)"
backup_id="$(printf '%s\n' "${create_out}" | tail -n 1)"
[[ -n "${backup_id}" ]] || {
  echo "[FAIL] backup create should output backup id" >&2
  printf '%s\n' "${create_out}" >&2
  exit 1
}

list_out="$(env "${BASE_ENV[@]}" ./plume.sh backup list --mode=native)"
printf '%s\n' "${list_out}" | grep -q "${backup_id}" || {
  echo "[FAIL] backup list should include created id" >&2
  printf '%s\n' "${list_out}" >&2
  exit 1
}

show_out="$(env "${BASE_ENV[@]}" ./plume.sh backup show "${backup_id}" --mode=native)"
printf '%s\n' "${show_out}" | grep -q '^SCOPE=config$' || {
  echo "[FAIL] backup show should include metadata scope" >&2
  printf '%s\n' "${show_out}" >&2
  exit 1
}

# mutate and verify restore guard behavior
printf 'after\n' > "${STATE_DIR}/custom.flag"

set +e
env "${BASE_ENV[@]}" ./plume.sh backup restore "${backup_id}" --mode=native >/dev/null 2>&1
rc=$?
set -e
if [[ "${rc}" -ne 2 ]]; then
  echo "[FAIL] backup restore should be blocked without --yes" >&2
  exit 1
fi

env "${BASE_ENV[@]}" ./plume.sh backup restore "${backup_id}" --mode=native --dry-run >/dev/null

env "${BASE_ENV[@]}" ./plume.sh --yes backup restore "${backup_id}" --mode=native >/dev/null

restored="$(cat "${STATE_DIR}/custom.flag")"
if [[ "${restored}" != "before" ]]; then
  echo "[FAIL] backup restore should restore config files" >&2
  printf 'got=%s\n' "${restored}" >&2
  exit 1
fi

DB_FILE="${STATE_DIR}/plume-state.db"
for event in \
  backup.create.ok \
  critical.backup.restore.blocked \
  critical.backup.restore.approved \
  backup.restore.ok; do
  count="$(sqlite3 "${DB_FILE}" "SELECT COUNT(*) FROM runtime_events WHERE event='${event}';")"
  if [[ "${count}" -lt 1 ]]; then
    echo "[FAIL] missing backup audit event: ${event}" >&2
    sqlite3 "${DB_FILE}" "SELECT ts,event,details FROM runtime_events ORDER BY id DESC LIMIT 25;" >&2 || true
    exit 1
  fi
done

echo "phase9-backup-smoke:ok"
