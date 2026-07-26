#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

TMP_ROOT="$(mktemp -d)"
STATE_DIR="${TMP_ROOT}/state"
BIN_DIR="${TMP_ROOT}/bin"
CRON_FILE="${TMP_ROOT}/crontab.txt"
mkdir -p "${STATE_DIR}" "${BIN_DIR}"

cleanup() {
  rm -rf "${TMP_ROOT}"
}
trap cleanup EXIT

cat > "${BIN_DIR}/crontab" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
file="${PLUME_TEST_CRON_FILE}"
if [[ "${1:-}" == "-l" ]]; then
  if [[ -f "${file}" ]]; then
    cat "${file}"
    exit 0
  fi
  exit 1
fi
cat > "${file}"
EOF
chmod +x "${BIN_DIR}/crontab"

BASE_ENV=("PLUME_STATE_DIR=${STATE_DIR}" "PATH=${BIN_DIR}:${PATH}" "PLUME_TEST_CRON_FILE=${CRON_FILE}")

env "${BASE_ENV[@]}" ./plume.sh sync cron install --mode=docker-lite --schedule="15 * * * *" >/tmp/plume-phase7-sync-cron.out 2>&1
grep -q "plume-sync-hourly" "${CRON_FILE}" || {
  echo "[FAIL] expected sync cron marker after install" >&2
  cat "${CRON_FILE}" >&2 || true
  exit 1
}

env "${BASE_ENV[@]}" ./plume.sh sync cron status | grep -q "enabled" || {
  echo "[FAIL] expected sync cron status enabled" >&2
  exit 1
}

env "${BASE_ENV[@]}" ./plume.sh sync cron remove >/tmp/plume-phase7-sync-cron.out 2>&1
if grep -q "plume-sync-hourly" "${CRON_FILE}" 2>/dev/null; then
  echo "[FAIL] expected sync cron entry removed" >&2
  cat "${CRON_FILE}" >&2 || true
  exit 1
fi

echo "phase7-sync-cron-smoke:ok"
