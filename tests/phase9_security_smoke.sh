#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

if ! command -v sqlite3 >/dev/null 2>&1; then
  echo "phase9-security-smoke:skip (sqlite3 not found)"
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

check_out="$(env "${BASE_ENV[@]}" ./plume.sh security check --mode=native --skip-prereq)"
printf '%s\n' "${check_out}" | grep -q '^FIREWALL          ' || {
  echo "[FAIL] security check should print firewall line" >&2
  printf '%s\n' "${check_out}" >&2
  exit 1
}

env "${BASE_ENV[@]}" ./plume.sh security secrets set APP_KEY base64:test >/dev/null
value="$(env "${BASE_ENV[@]}" ./plume.sh security secrets get APP_KEY)"
[[ "${value}" == "base64:test" ]] || {
  echo "[FAIL] security secrets get mismatch" >&2
  exit 1
}

list_out="$(env "${BASE_ENV[@]}" ./plume.sh security secrets list)"
printf '%s\n' "${list_out}" | grep -q '^APP_KEY$' || {
  echo "[FAIL] security secrets list should include APP_KEY" >&2
  printf '%s\n' "${list_out}" >&2
  exit 1
}

gen_value="$(env "${BASE_ENV[@]}" ./plume.sh security secrets generate API_TOKEN --length=24)"
if [[ "${#gen_value}" -ne 24 ]]; then
  echo "[FAIL] generated secret length mismatch" >&2
  exit 1
fi

env "${BASE_ENV[@]}" ./plume.sh security secrets unset APP_KEY >/dev/null
set +e
env "${BASE_ENV[@]}" ./plume.sh security secrets get APP_KEY >/dev/null 2>&1
rc=$?
set -e
if [[ "${rc}" -ne 2 ]]; then
  echo "[FAIL] removed secret should not be readable" >&2
  exit 1
fi

DB_FILE="${STATE_DIR}/plume-state.db"
for event in \
  security.check.ok \
  security.secret.set \
  security.secret.get \
  security.secret.list \
  security.secret.generate \
  security.secret.unset; do
  count="$(sqlite3 "${DB_FILE}" "SELECT COUNT(*) FROM runtime_events WHERE event='${event}';")"
  if [[ "${count}" -lt 1 ]]; then
    echo "[FAIL] missing security audit event: ${event}" >&2
    sqlite3 "${DB_FILE}" "SELECT ts,event,details FROM runtime_events ORDER BY id DESC LIMIT 30;" >&2 || true
    exit 1
  fi
done

echo "phase9-security-smoke:ok"
