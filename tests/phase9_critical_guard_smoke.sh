#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

if ! command -v sqlite3 >/dev/null 2>&1; then
  echo "phase9-critical-guard-smoke:skip (sqlite3 not found)"
  exit 0
fi

TMP_ROOT="$(mktemp -d)"
HOME_DIR="${TMP_ROOT}/home"
STATE_DIR="${TMP_ROOT}/state"
DL_PATH="${TMP_ROOT}/docker-lite"
mkdir -p "${HOME_DIR}" "${STATE_DIR}" "${DL_PATH}"

cleanup() {
  rm -rf "${TMP_ROOT}"
}
trap cleanup EXIT

BASE_ENV=(
  "HOME=${HOME_DIR}"
  "PLUME_STATE_DIR=${STATE_DIR}"
)

set +e
env "${BASE_ENV[@]}" ./plume.sh mode use native --force >/dev/null 2>&1
rc=$?
set -e
if [[ "${rc}" -ne 2 ]]; then
  echo "[FAIL] mode use --force should be blocked without --yes" >&2
  exit 1
fi

env "${BASE_ENV[@]}" ./plume.sh --yes mode use native --force >/dev/null

env "${BASE_ENV[@]}" ./plume.sh mode path set docker-lite "${DL_PATH}" >/dev/null

set +e
env "${BASE_ENV[@]}" ./plume.sh services workspace reinit --mode=docker-lite --path="${DL_PATH}" >/dev/null 2>&1
rc=$?
set -e
if [[ "${rc}" -ne 2 ]]; then
  echo "[FAIL] workspace reinit should be blocked without --yes" >&2
  exit 1
fi

env "${BASE_ENV[@]}" ./plume.sh --yes services workspace reinit --mode=docker-lite --path="${DL_PATH}" >/dev/null

if [[ ! -f "${DL_PATH}/docker-compose.yml" ]]; then
  echo "[FAIL] workspace reinit with --yes should recreate compose file" >&2
  exit 1
fi

DB_FILE="${STATE_DIR}/plume-state.db"
for event in \
  critical.mode.use.force.blocked \
  critical.mode.use.force.approved \
  critical.workspace.reinit.blocked \
  critical.workspace.reinit.approved; do
  count="$(sqlite3 "${DB_FILE}" "SELECT COUNT(*) FROM runtime_events WHERE event='${event}';")"
  if [[ "${count}" -lt 1 ]]; then
    echo "[FAIL] missing audit event: ${event}" >&2
    sqlite3 "${DB_FILE}" "SELECT ts,event,details FROM runtime_events ORDER BY id DESC LIMIT 20;" >&2 || true
    exit 1
  fi
done

echo "phase9-critical-guard-smoke:ok"
