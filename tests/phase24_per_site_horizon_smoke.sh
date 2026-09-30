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
PROJECT_A="${TMP_ROOT}/app-a"
PROJECT_B="${TMP_ROOT}/app-b"
SITE_A="site-smoke-a"
SITE_B="site-smoke-b"
mkdir -p "${HOME_DIR}/.config/plume/sites" "${STATE_DIR}" "${MOCK_BIN}" "${MOCK_PROG}" "${PROJECT_A}" "${PROJECT_B}"
: > "${HOME_DIR}/.config/plume/.env"
printf '#!/usr/bin/env php\n<?php\n' > "${PROJECT_A}/artisan"
printf '#!/usr/bin/env php\n<?php\n' > "${PROJECT_B}/artisan"
printf '[supervisord]\n[include]\nfiles = %s/*.conf\n' "${MOCK_PROG}" > "${MOCK_SUP}/supervisord.conf"

cat > "${HOME_DIR}/.config/plume/host.env" <<EOF
os=macos
package_manager=brew
supervisor_runtime=brew
supervisor_config_schema=1
supervisor_main_conf=${MOCK_SUP}/supervisord.conf
supervisor_programs_dir=${MOCK_PROG}
EOF

cat > "${HOME_DIR}/.config/plume/sites/index.yml" <<EOF
sites:
  - ${SITE_A}
  - ${SITE_B}
EOF

write_site() {
  local id="$1" path="$2"
  cat > "${HOME_DIR}/.config/plume/sites/${id}.yml" <<EOF
id: ${id}
mode: native
path: ${path}
server: nginx
port: 80
document_root: public
php_version: 8.3
horizon: true
status: active
created_at: 1
domains:
  - ${id}.test
EOF
}

write_site "${SITE_A}" "${PROJECT_A}"
write_site "${SITE_B}" "${PROJECT_B}"

cleanup() { rm -rf "${TMP_ROOT}"; }
trap cleanup EXIT

cat > "${MOCK_BIN}/brew" <<'EOF'
#!/usr/bin/env bash
case "${1:-}" in
  services) exit 0 ;;
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

cat > "${MOCK_BIN}/supervisorctl" <<EOF
#!/usr/bin/env bash
echo "plume-horizon-${SITE_A}                            RUNNING   pid 1, uptime 0:00:01"
echo "plume-horizon-${SITE_B}                            RUNNING   pid 2, uptime 0:00:02"
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
  "PLUME_SUPERVISOR_ENABLED=true"
  "PLUME_HORIZON_ENABLED=true"
  "PLUME_PHP_BIN=${MOCK_BIN}/php"
)

env "${BASE_ENV[@]}" ./plume.sh mode use native --force --yes >/dev/null
env "${BASE_ENV[@]}" ./plume.sh services install supervisor --mode=native >/dev/null
env "${BASE_ENV[@]}" ./plume.sh services up supervisor --mode=native >/dev/null
env "${BASE_ENV[@]}" ./plume.sh services up horizon --mode=native >/dev/null

for site_id in "${SITE_A}" "${SITE_B}"; do
  prog="${MOCK_PROG}/plume-horizon-${site_id}.conf"
  [[ -f "${prog}" ]] || {
    echo "[FAIL] missing program conf for ${site_id}" >&2
    exit 1
  }
  grep -q 'artisan horizon' "${prog}" || {
    echo "[FAIL] ${site_id} program should run artisan horizon" >&2
    cat "${prog}" >&2
    exit 1
  }
done
echo "[PASS] per-site horizon program confs"

env "${BASE_ENV[@]}" ./plume.sh services up horizon --site="${SITE_A}" --mode=native >/dev/null
[[ -f "${MOCK_PROG}/plume-horizon-${SITE_A}.conf" ]] || {
  echo "[FAIL] --site single target conf missing" >&2
  exit 1
}
echo "[PASS] services up horizon --site= single target"

DOC_OUT="$(env "${BASE_ENV[@]}" ./plume.sh doctor supervisor 2>&1)"
echo "${DOC_OUT}" | grep -q "horizon-program:${SITE_A}.*PASS" || {
  echo "[FAIL] doctor should report per-site horizon programs" >&2
  printf '%s\n' "${DOC_OUT}" >&2
  exit 1
}
echo "[PASS] doctor per-site horizon checks"

LOG_DIR="${STATE_DIR}/logs/services/native"
mkdir -p "${LOG_DIR}"
printf 'horizon worker boot ok\n' > "${LOG_DIR}/horizon-${SITE_A}.log"
LOG_OUT="$(env "${BASE_ENV[@]}" ./plume.sh services logs horizon --site="${SITE_A}" --mode=native --tail=10 2>&1)"
echo "${LOG_OUT}" | grep -q "horizon worker boot ok" || {
  echo "[FAIL] services logs horizon should show per-site worker log" >&2
  printf '%s\n' "${LOG_OUT}" >&2
  exit 1
}
echo "[PASS] services logs horizon (per-site, plumectl-only)"

echo "phase24-per-site-horizon-smoke:ok"
