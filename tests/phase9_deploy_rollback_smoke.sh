#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

if ! command -v sqlite3 >/dev/null 2>&1; then
  echo "phase9-deploy-rollback-smoke:skip (sqlite3 not found)"
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

printf 'v1\n' > "${STATE_DIR}/custom.flag"
env "${BASE_ENV[@]}" ./plume.sh backup create --mode=native --scope=config --name=v1 >/dev/null
printf 'v2\n' > "${STATE_DIR}/custom.flag"
env "${BASE_ENV[@]}" ./plume.sh backup create --mode=native --scope=config --name=v2 >/dev/null
printf 'broken\n' > "${STATE_DIR}/custom.flag"

set +e
env "${BASE_ENV[@]}" ./plume.sh deploy rollback latest --mode=native >/dev/null 2>&1
rc=$?
set -e
if [[ "${rc}" -ne 2 ]]; then
  echo "[FAIL] deploy rollback should be blocked without --yes" >&2
  exit 1
fi

env "${BASE_ENV[@]}" ./plume.sh --yes deploy rollback latest --mode=native >/dev/null

rolled="$(cat "${STATE_DIR}/custom.flag")"
if [[ "${rolled}" != "v2" ]]; then
  echo "[FAIL] deploy rollback latest should restore latest backup state (v2)" >&2
  printf 'got=%s\n' "${rolled}" >&2
  exit 1
fi

set +e
env "${BASE_ENV[@]}" ./plume.sh deploy failback --mode=native >/dev/null 2>&1
rc=$?
set -e
if [[ "${rc}" -ne 2 ]]; then
  echo "[FAIL] deploy failback should be blocked without --yes" >&2
  exit 1
fi

env "${BASE_ENV[@]}" ./plume.sh --yes deploy failback --mode=native >/dev/null

failbacked="$(cat "${STATE_DIR}/custom.flag")"
if [[ "${failbacked}" != "broken" ]]; then
  echo "[FAIL] deploy failback should restore pre-rollback failback point" >&2
  printf 'got=%s\n' "${failbacked}" >&2
  exit 1
fi

DB_FILE="${STATE_DIR}/plume-state.db"
for event in \
  critical.deploy.rollback.blocked \
  critical.deploy.rollback.approved \
  deploy.rollback.ok \
  deploy.failback.point.created \
  critical.deploy.failback.blocked \
  critical.deploy.failback.approved \
  deploy.failback.ok; do
  count="$(sqlite3 "${DB_FILE}" "SELECT COUNT(*) FROM runtime_events WHERE event='${event}';")"
  if [[ "${count}" -lt 1 ]]; then
    echo "[FAIL] missing deploy audit event: ${event}" >&2
    sqlite3 "${DB_FILE}" "SELECT ts,event,details FROM runtime_events ORDER BY id DESC LIMIT 30;" >&2 || true
    exit 1
  fi
done

echo "phase9-deploy-rollback-smoke:ok"
