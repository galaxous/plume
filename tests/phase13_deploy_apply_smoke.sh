#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

if ! command -v sqlite3 >/dev/null 2>&1; then
  echo "phase13-deploy-apply-smoke:skip (sqlite3 not found)"
  exit 0
fi

TMP_ROOT="$(mktemp -d)"
HOME_DIR="${TMP_ROOT}/home"
STATE_DIR="${TMP_ROOT}/state"
ENV_FILE="${TMP_ROOT}/min.env"
mkdir -p "${HOME_DIR}" "${STATE_DIR}"

cat > "${ENV_FILE}" <<'EOF'
PLUME_PHP_ENABLED=false
PLUME_MARIADB_ENABLED=false
PLUME_COMPOSER_ENABLED=false
PLUME_WEB_SERVER_ENABLED=false
PLUME_REDIS_ENABLED=false
PLUME_MYSQL_ENABLED=false
PLUME_POSTGRES_ENABLED=false
PLUME_SUPERVISOR_ENABLED=false
PLUME_HORIZON_ENABLED=false
EOF

cleanup() {
  rm -rf "${TMP_ROOT}"
}
trap cleanup EXIT

BASE=(--env-file "${ENV_FILE}")
RUN=(env "HOME=${HOME_DIR}" "PLUME_STATE_DIR=${STATE_DIR}")

"${RUN[@]}" ./plume.sh "${BASE[@]}" mode use native --force --yes >/dev/null

set +e
"${RUN[@]}" ./plume.sh "${BASE[@]}" deploy apply --mode=native --skip-backup --skip-reconcile >/dev/null 2>&1
rc=$?
set -e
if [[ "${rc}" -ne 2 ]]; then
  echo "[FAIL] deploy apply should require --yes" >&2
  exit 1
fi
echo "[PASS] deploy apply blocked without --yes"

"${RUN[@]}" ./plume.sh "${BASE[@]}" deploy apply --mode=native --dry-run >/dev/null
echo "[PASS] deploy apply dry-run"

"${RUN[@]}" ./plume.sh "${BASE[@]}" --yes deploy apply --mode=native --skip-backup --skip-reconcile --skip-health >/dev/null
echo "[PASS] deploy apply with skips"

DB_FILE="${STATE_DIR}/plume-state.db"
count="$(sqlite3 "${DB_FILE}" "SELECT COUNT(*) FROM runtime_events WHERE event='deploy.apply.ok';")"
if [[ "${count}" -lt 1 ]]; then
  echo "[FAIL] missing deploy.apply.ok audit event" >&2
  exit 1
fi
echo "[PASS] deploy apply audit event"

echo "phase13-deploy-apply-smoke:ok"
