#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

TMP_ROOT="$(mktemp -d)"
HOME_DIR="${TMP_ROOT}/home"
STATE_DIR="${TMP_ROOT}/state"
MOCK_BIN="${TMP_ROOT}/bin"
PROJECT="${TMP_ROOT}/app"
mkdir -p "${HOME_DIR}/.config/plume" "${STATE_DIR}" "${MOCK_BIN}" "${PROJECT}"
: > "${HOME_DIR}/.config/plume/.env"
printf '#!/usr/bin/env php\n<?php\n' > "${PROJECT}/artisan"

cleanup() {
  if [[ -f "${STATE_DIR}/native-pids/supervisor.pid" ]]; then
    kill "$(cat "${STATE_DIR}/native-pids/supervisor.pid" 2>/dev/null || true)" 2>/dev/null || true
  fi
  rm -rf "${TMP_ROOT}"
}
trap cleanup EXIT

cat > "${MOCK_BIN}/brew" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "${MOCK_BIN}/brew"

cat > "${MOCK_BIN}/supervisord" <<'EOF'
#!/usr/bin/env bash
exec sleep 3600
EOF
chmod +x "${MOCK_BIN}/supervisord"

cat > "${MOCK_BIN}/supervisorctl" <<'EOF'
#!/usr/bin/env bash
echo "plume-horizon                            RUNNING   pid 1, uptime 0:00:01"
exit 0
EOF
chmod +x "${MOCK_BIN}/supervisorctl"

BASE_ENV=(
  "HOME=${HOME_DIR}"
  "PLUME_STATE_DIR=${STATE_DIR}"
  "PATH=${MOCK_BIN}:/usr/bin:/bin"
  "PLUME_NATIVE_HOST_PROVISION=true"
  "PLUME_ALLOW_NON_ROOT_INSTALL=true"
  "PLUME_SKIP_ON_FIRST_RUN_PROVISION=true"
  "PLUME_PHP_EXTENSIONS_AUTO_SYNC=false"
  "PLUME_GLOBAL_ENV_FILE=${HOME_DIR}/.config/plume/.env"
  "PLUME_ENV_FILE=${HOME_DIR}/.config/plume/.env"
  "PLUME_HORIZON_PATH=${PROJECT}"
  "PLUME_SUPERVISOR_ENABLED=true"
  "PLUME_HORIZON_ENABLED=true"
  "PLUME_PHP_BIN=${MOCK_BIN}/php"
)

cat > "${MOCK_BIN}/php" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "${MOCK_BIN}/php"

env "${BASE_ENV[@]}" ./plume.sh mode use native --force --yes >/dev/null

assert_fail_code() {
  local expected="$1"
  local name="$2"
  shift 2
  set +e
  "$@" >/dev/null 2>&1
  local got=$?
  set -e
  if [[ "${got}" -eq "${expected}" ]]; then
    echo "[PASS] ${name}"
  else
    echo "[FAIL] ${name} (expected ${expected}, got ${got})" >&2
    return 1
  fi
}

assert_fail_code 2 "horizon still requires supervisor" \
  env "${BASE_ENV[@]}" PLUME_SUPERVISOR_ENABLED=false ./plume.sh services up horizon --mode=native

env "${BASE_ENV[@]}" ./plume.sh services install supervisor --mode=native >/dev/null
env "${BASE_ENV[@]}" ./plume.sh services up supervisor --mode=native >/dev/null
env "${BASE_ENV[@]}" ./plume.sh services install horizon --mode=native >/dev/null
env "${BASE_ENV[@]}" ./plume.sh services up horizon --mode=native >/dev/null

SUP="$(env "${BASE_ENV[@]}" ./plume.sh services status supervisor --mode=native 2>/dev/null | grep '^supervisor' || true)"
echo "${SUP}" | grep -q 'healthy' || {
  echo "[FAIL] supervisor should be healthy" >&2
  printf '%s\n' "${SUP}" >&2
  exit 1
}
echo "[PASS] supervisor healthy"

HOR="$(env "${BASE_ENV[@]}" ./plume.sh services status horizon --mode=native 2>/dev/null | grep '^horizon' || true)"
echo "${HOR}" | grep -q 'healthy' || {
  echo "[FAIL] horizon should be healthy" >&2
  printf '%s\n' "${HOR}" >&2
  exit 1
}
echo "${HOR}" | grep -q 'registry' && {
  echo "[FAIL] horizon must not stay registry-only" >&2
  printf '%s\n' "${HOR}" >&2
  exit 1
}
echo "[PASS] horizon healthy (not registry)"

PROG="${STATE_DIR}/native/supervisor/programs/plume-horizon.conf"
[[ -f "${PROG}" ]] || {
  echo "[FAIL] missing horizon program conf" >&2
  exit 1
}
grep -q 'artisan horizon' "${PROG}" || {
  echo "[FAIL] program should run artisan horizon" >&2
  cat "${PROG}" >&2
  exit 1
}
echo "[PASS] horizon program written"

echo "phase22-native-horizon-smoke:ok"
