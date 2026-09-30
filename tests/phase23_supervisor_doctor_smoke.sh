#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

TMP_ROOT="$(mktemp -d)"
HOME_DIR="${TMP_ROOT}/home"
STATE_DIR="${TMP_ROOT}/state"
MOCK_BIN="${TMP_ROOT}/bin"
MOCK_SUP="${STATE_DIR}/mock-supervisor"
MOCK_PROG="${MOCK_SUP}/programs"
PROJECT="${TMP_ROOT}/app"
mkdir -p "${HOME_DIR}/.config/plume" "${STATE_DIR}" "${MOCK_BIN}" "${MOCK_PROG}" "${PROJECT}"
: > "${HOME_DIR}/.config/plume/.env"
printf '#!/usr/bin/env php\n<?php\n' > "${PROJECT}/artisan"
printf '[supervisord]\n[include]\nfiles = %s/*.conf\n' "${MOCK_PROG}" > "${MOCK_SUP}/supervisord.conf"

cat > "${HOME_DIR}/.config/plume/host.env" <<EOF
os=macos
package_manager=brew
supervisor_runtime=brew
supervisor_config_schema=1
supervisor_main_conf=${MOCK_SUP}/supervisord.conf
supervisor_programs_dir=${MOCK_PROG}
EOF

cleanup() { rm -rf "${TMP_ROOT}"; }
trap cleanup EXIT

cat > "${MOCK_BIN}/brew" <<'EOF'
#!/usr/bin/env bash
case "${1:-}" in
  services) exit 0 ;;
  upgrade) exit 0 ;;
  --prefix) echo "/mock/brew" ;;
esac
exit 0
EOF
chmod +x "${MOCK_BIN}/brew"

cat > "${MOCK_BIN}/supervisord" <<'EOF'
#!/usr/bin/env bash
echo "4.3.0"
exit 0
EOF
chmod +x "${MOCK_BIN}/supervisord"

cat > "${MOCK_BIN}/supervisorctl" <<'EOF'
#!/usr/bin/env bash
echo "plume-horizon                            RUNNING   pid 1, uptime 0:00:01"
exit 0
EOF
chmod +x "${MOCK_BIN}/supervisorctl"

cat > "${MOCK_BIN}/php" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "${MOCK_BIN}/php"

BASE_ENV=(
  "HOME=${HOME_DIR}"
  "PLUME_STATE_DIR=${STATE_DIR}"
  "PATH=${MOCK_BIN}:/usr/bin:/bin"
  "PLUME_NATIVE_HOST_INSTALL_DRIVER=mock"
  "PLUME_NATIVE_HOST_PROVISION=true"
  "PLUME_ALLOW_NON_ROOT_INSTALL=true"
  "PLUME_SKIP_ON_FIRST_RUN_PROVISION=true"
  "PLUME_PHP_EXTENSIONS_AUTO_SYNC=false"
  "PLUME_GLOBAL_ENV_FILE=${HOME_DIR}/.config/plume/.env"
  "PLUME_ENV_FILE=${HOME_DIR}/.config/plume/.env"
  "PLUME_NATIVE_SUPERVISOR_MAIN_CONF=${MOCK_SUP}/supervisord.conf"
  "PLUME_NATIVE_SUPERVISOR_PROGRAMS_DIR=${MOCK_PROG}"
  "PLUME_HORIZON_PATH=${PROJECT}"
  "PLUME_SUPERVISOR_ENABLED=true"
  "PLUME_HORIZON_ENABLED=true"
  "PLUME_PHP_BIN=${MOCK_BIN}/php"
)

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

DOC_OUT="$(env "${BASE_ENV[@]}" ./plume.sh doctor supervisor 2>&1)" || {
  echo "[FAIL] doctor supervisor should succeed" >&2
  printf '%s\n' "${DOC_OUT}" >&2
  exit 1
}
echo "${DOC_OUT}" | grep -q 'OVERALL.*OK' || {
  echo "[FAIL] doctor supervisor overall OK" >&2
  printf '%s\n' "${DOC_OUT}" >&2
  exit 1
}
echo "[PASS] doctor supervisor"

assert_fail_code 2 "upgrade requires --force" \
  env "${BASE_ENV[@]}" ./plume.sh services supervisor upgrade --yes

assert_fail_code 2 "upgrade requires --yes" \
  env "${BASE_ENV[@]}" ./plume.sh services supervisor upgrade --force

env "${BASE_ENV[@]}" ./plume.sh services supervisor upgrade --force --yes --dry-run >/dev/null
echo "[PASS] upgrade dry-run"

env "${BASE_ENV[@]}" ./plume.sh services supervisor program add \
  --template=horizon --non-interactive --name=plume-horizon >/dev/null

PROG="${MOCK_PROG}/plume-horizon.conf"
[[ -f "${PROG}" ]] || {
  echo "[FAIL] missing horizon program conf in system dir" >&2
  exit 1
}
grep -q 'artisan horizon' "${PROG}" || {
  echo "[FAIL] program should run artisan horizon" >&2
  cat "${PROG}" >&2
  exit 1
}
echo "[PASS] program add horizon"

env "${BASE_ENV[@]}" ./plume.sh services up supervisor >/dev/null
env "${BASE_ENV[@]}" ./plume.sh services up horizon >/dev/null

HOR="$(env "${BASE_ENV[@]}" ./plume.sh services status horizon --mode=native 2>/dev/null | grep '^horizon' || true)"
echo "${HOR}" | grep -q 'healthy' || {
  echo "[FAIL] horizon should be healthy" >&2
  printf '%s\n' "${HOR}" >&2
  exit 1
}
echo "[PASS] horizon healthy after system supervisor"

echo "phase23-supervisor-doctor-smoke:ok"
