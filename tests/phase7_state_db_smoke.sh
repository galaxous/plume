#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

if ! command -v sqlite3 >/dev/null 2>&1; then
  echo "phase7-state-db-smoke:skip (sqlite3 not found)"
  exit 0
fi

TMP_ROOT="$(mktemp -d)"
STATE_DIR="${TMP_ROOT}/state"
DB_FILE="${STATE_DIR}/plume-state.db"
mkdir -p "${STATE_DIR}"

cleanup() {
  rm -rf "${TMP_ROOT}"
}
trap cleanup EXIT

PLUME_STATE_DIR="${STATE_DIR}" ./plume.sh mode use native >/dev/null
PLUME_STATE_DIR="${STATE_DIR}" ./plume.sh services up php --mode=native >/dev/null

test -f "${DB_FILE}" || {
  echo "[FAIL] state db file not created: ${DB_FILE}" >&2
  exit 1
}

SERVICE_ROW="$(sqlite3 "${DB_FILE}" "SELECT service||':'||running FROM services WHERE mode='native' AND service='php' LIMIT 1;")"
[[ "${SERVICE_ROW}" == "php:true" ]] || {
  echo "[FAIL] services table not synced for native/php, got: ${SERVICE_ROW}" >&2
  exit 1
}

LOCK_ROW="$(sqlite3 "${DB_FILE}" "SELECT locked FROM locks WHERE name='global_context' LIMIT 1;")"
[[ "${LOCK_ROW}" == "true" ]] || {
  echo "[FAIL] locks table not synced, got: ${LOCK_ROW}" >&2
  exit 1
}

EVENT_COUNT="$(sqlite3 "${DB_FILE}" "SELECT COUNT(*) FROM runtime_events;")"
[[ "${EVENT_COUNT}" =~ ^[0-9]+$ ]] || {
  echo "[FAIL] runtime_events query failed: ${EVENT_COUNT}" >&2
  exit 1
}
if [[ "${EVENT_COUNT}" -lt 1 ]]; then
  echo "[FAIL] expected at least one runtime event row" >&2
  exit 1
fi

echo "phase7-state-db-smoke:ok"
