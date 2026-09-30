#!/usr/bin/env bash
set -euo pipefail

# D-153: Homebrew supervisord includes etc/supervisor.d/*.ini — not opt/supervisor/.../*.conf

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

TMP_ROOT="$(mktemp -d)"
HOME_DIR="${TMP_ROOT}/home"
STATE_DIR="${TMP_ROOT}/state"
MOCK_BIN="${TMP_ROOT}/bin"
BREW_PREFIX="${TMP_ROOT}/brew"
ETC_DIR="${BREW_PREFIX}/etc"
PROG_DIR="${ETC_DIR}/supervisor.d"
WRONG_DIR="${BREW_PREFIX}/opt/supervisor/etc/supervisor.d"
PROJECT="${TMP_ROOT}/app"
mkdir -p "${HOME_DIR}/.config/plume/sites" "${STATE_DIR}" "${MOCK_BIN}" "${PROG_DIR}" "${WRONG_DIR}" "${PROJECT}"
: > "${HOME_DIR}/.config/plume/.env"
printf '#!/usr/bin/env php\n<?php\n' > "${PROJECT}/artisan"

cat > "${ETC_DIR}/supervisord.conf" <<EOF
[supervisord]
[include]
files = ${PROG_DIR}/*.ini
EOF

# Stale host cache pointing at formula opt path (pre-D-153 bug)
cat > "${HOME_DIR}/.config/plume/host.env" <<EOF
os=macos
package_manager=brew
supervisor_runtime=brew
supervisor_config_schema=1
supervisor_main_conf=
supervisor_programs_dir=${WRONG_DIR}
EOF

SITE_ID="site-brew-ini"
cat > "${HOME_DIR}/.config/plume/sites/index.yml" <<EOF
sites:
  - ${SITE_ID}
EOF
cat > "${HOME_DIR}/.config/plume/sites/${SITE_ID}.yml" <<EOF
id: ${SITE_ID}
mode: native
path: ${PROJECT}
server: nginx
port: 80
document_root: public
php_version: 8.3
horizon: true
status: active
created_at: 1
domains:
  - ${SITE_ID}.test
EOF

cleanup() { rm -rf "${TMP_ROOT}"; }
trap cleanup EXIT

cat > "${MOCK_BIN}/brew" <<EOF
#!/usr/bin/env bash
case "\${1:-}" in
  services) exit 0 ;;
  --prefix)
    if [[ "\${2:-}" == "supervisor" ]]; then
      echo "${BREW_PREFIX}/opt/supervisor"
    else
      echo "${BREW_PREFIX}"
    fi
    ;;
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
echo "plume-horizon-${SITE_ID}                            RUNNING   pid 1, uptime 0:00:01"
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
  "PLUME_SUPERVISOR_ENABLED=true"
  "PLUME_HORIZON_ENABLED=true"
  "PLUME_PHP_BIN=${MOCK_BIN}/php"
  "PLUME_NATIVE_SUPERVISOR_HOMEBREW_PREFIX=${BREW_PREFIX}"
)

env "${BASE_ENV[@]}" ./plume.sh mode use native --force --yes >/dev/null
env "${BASE_ENV[@]}" ./plume.sh services install supervisor --mode=native >/dev/null
env "${BASE_ENV[@]}" ./plume.sh services up horizon --site="${SITE_ID}" --mode=native >/dev/null

INI="${PROG_DIR}/plume-horizon-${SITE_ID}.ini"
[[ -f "${INI}" ]] || {
  echo "[FAIL] expected program at Homebrew include path ${INI}" >&2
  ls -la "${PROG_DIR}" "${WRONG_DIR}" >&2 || true
  exit 1
}
[[ ! -f "${WRONG_DIR}/plume-horizon-${SITE_ID}.conf" ]] || {
  echo "[FAIL] stale .conf should not remain in formula opt supervisor.d" >&2
  exit 1
}
grep -q 'artisan horizon' "${INI}" || {
  echo "[FAIL] .ini should run artisan horizon" >&2
  cat "${INI}" >&2
  exit 1
}
echo "[PASS] brew supervisor drop-in uses etc/supervisor.d/*.ini (D-153)"

echo "phase26-supervisor-brew-ini-smoke:ok"
