#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

if ! command -v sqlite3 >/dev/null 2>&1; then
  echo "phase9-project-env-sync-secrets-smoke:skip (sqlite3 not found)"
  exit 0
fi

TMP_ROOT="$(mktemp -d)"
HOME_DIR="${TMP_ROOT}/home"
STATE_DIR="${TMP_ROOT}/state"
PROJECT_DIR="${TMP_ROOT}/project"
mkdir -p "${HOME_DIR}" "${STATE_DIR}" "${PROJECT_DIR}"

cleanup() {
  rm -rf "${TMP_ROOT}"
}
trap cleanup EXIT

BASE_ENV=(
  "HOME=${HOME_DIR}"
  "PLUME_STATE_DIR=${STATE_DIR}"
)

cat > "${STATE_DIR}/secrets.env" <<'EOF_SEC'
APP_KEY=base64:my-app-key
DB_PASSWORD=top-secret
CACHE_PREFIX=plume
EOF_SEC

cat > "${PROJECT_DIR}/.env.example" <<'EOF_ENV_EX'
APP_NAME=Laravel
APP_KEY=
DB_PASSWORD=
CACHE_PREFIX=
EOF_ENV_EX

# dry-run should not create .env
env "${BASE_ENV[@]}" ./plume.sh project env sync-secrets --path="${PROJECT_DIR}" --keys=APP_KEY,DB_PASSWORD --dry-run --create-env >/dev/null
[[ ! -f "${PROJECT_DIR}/.env" ]] || {
  echo "[FAIL] dry-run should not create .env" >&2
  exit 1
}

env "${BASE_ENV[@]}" ./plume.sh project env sync-secrets --path="${PROJECT_DIR}" --keys=APP_KEY,DB_PASSWORD --create-env >/dev/null

[[ -f "${PROJECT_DIR}/.env" ]] || {
  echo "[FAIL] .env should be created when --create-env is set" >&2
  exit 1
}

grep -q '^APP_KEY=base64:my-app-key$' "${PROJECT_DIR}/.env" || {
  echo "[FAIL] APP_KEY should be synced to project .env" >&2
  cat "${PROJECT_DIR}/.env" >&2
  exit 1
}

grep -q '^DB_PASSWORD=top-secret$' "${PROJECT_DIR}/.env" || {
  echo "[FAIL] DB_PASSWORD should be synced to project .env" >&2
  cat "${PROJECT_DIR}/.env" >&2
  exit 1
}

# without keys, sync all known keys from secrets store
env "${BASE_ENV[@]}" ./plume.sh project env sync-secrets --path="${PROJECT_DIR}" >/dev/null

grep -q '^CACHE_PREFIX=plume$' "${PROJECT_DIR}/.env" || {
  echo "[FAIL] expected CACHE_PREFIX from all-keys sync" >&2
  cat "${PROJECT_DIR}/.env" >&2
  exit 1
}

DB_FILE="${STATE_DIR}/plume-state.db"
count="$(sqlite3 "${DB_FILE}" "SELECT COUNT(*) FROM runtime_events WHERE event='project.env.sync-secrets.ok';")"
if [[ "${count}" -lt 1 ]]; then
  echo "[FAIL] expected project env sync audit event" >&2
  sqlite3 "${DB_FILE}" "SELECT ts,event,details FROM runtime_events ORDER BY id DESC LIMIT 20;" >&2 || true
  exit 1
fi

echo "phase9-project-env-sync-secrets-smoke:ok"
