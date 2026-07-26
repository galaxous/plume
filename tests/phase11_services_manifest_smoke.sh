#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

TMP_ROOT="$(mktemp -d)"
cleanup() {
  rm -rf "${TMP_ROOT}"
}
trap cleanup EXIT

HOME_DIR="${TMP_ROOT}/home"
STATE_DIR="${TMP_ROOT}/state"
CONFIG_DIR="${HOME_DIR}/.config/plume"
MANIFEST="${CONFIG_DIR}/services.yml"
GLOBAL_ENV="${CONFIG_DIR}/.env"
mkdir -p "${CONFIG_DIR}" "${STATE_DIR}"

cat > "${MANIFEST}" <<'EOF'
version: 1
services:
  web:
    engine: nginx
    manage_main_config: true
    http_port: 8088
    auto_provision: true
  php:
    default_version: "8.4"
    versions:
      - "8.3"
      - "8.4"
    extensions_profile: target
  database:
    engine: mysql
    version: "8.0"
    auto_start: true
  redis:
    enabled: true
  provision:
    interactive: false
EOF

# Minimal .env overrides one key (env must win over manifest).
cat > "${GLOBAL_ENV}" <<'EOF'
PLUME_WEB_PORT=9090
EOF

RUN=(
  env
  "HOME=${HOME_DIR}"
  "PLUME_STATE_DIR=${STATE_DIR}"
  "PLUME_AUTO_HOST_BOOTSTRAP=false"
  "PLUME_SERVICES_MANIFEST_FILE=${MANIFEST}"
  "PLUME_ENV_FILE=${GLOBAL_ENV}"
)

OUT="$("${RUN[@]}" ./plume.sh services manifest show 2>/dev/null)"

echo "${OUT}" | grep -q 'services_manifest=' || {
  echo "[FAIL] manifest show missing services_manifest line" >&2
  exit 1
}

echo "${OUT}" | grep -q 'effective_nginx_manage_main=true' || {
  echo "[FAIL] expected manage_main_config from yaml" >&2
  exit 1
}

echo "${OUT}" | grep -q 'effective_php_default=8.4' || {
  echo "[FAIL] expected php default from yaml" >&2
  exit 1
}

echo "${OUT}" | grep -q 'effective_mysql_enabled=true' || {
  echo "[FAIL] expected mysql engine from yaml" >&2
  exit 1
}

echo "${OUT}" | grep -q 'effective_redis_enabled=true' || {
  echo "[FAIL] expected redis enabled from yaml" >&2
  exit 1
}

# .env PLUME_WEB_PORT must override manifest http_port for PLUME_WEB_PORT after merge.
echo "${OUT}" | grep -q 'effective_plume_web_port=9090' || {
  echo "[FAIL] .env should override PLUME_WEB_PORT" >&2
  exit 1
}

echo "${OUT}" | grep -q 'effective_http_port=8088' || {
  echo "[FAIL] expected nginx http port from manifest" >&2
  exit 1
}

DRY="$("${RUN[@]}" ./plume.sh services provision --from-manifest --dry-run 2>&1)" || {
  echo "[FAIL] dry-run provision failed" >&2
  exit 1
}
echo "${DRY}" | grep -q 'dry-run' || {
  echo "[FAIL] dry-run should log dry-run message" >&2
  exit 1
}

# on_first_run: first substantive command runs mock provision once; second is no-op.
ON_FIRST_MANIFEST="${TMP_ROOT}/on-first-services.yml"
MOCK_BIN="${TMP_ROOT}/bin"
MOCK_LOG="${TMP_ROOT}/on-first-brew.log"
mkdir -p "${MOCK_BIN}"
cat > "${ON_FIRST_MANIFEST}" <<'EOF'
version: 1
services:
  web:
    engine: nginx
    auto_provision: true
  php:
    enabled: false
  database:
    engine: mariadb
  mariadb:
    enabled: false
  mysql:
    enabled: false
  redis:
    enabled: false
  provision:
    on_first_run: true
    interactive: false
EOF

if [[ "$(uname -s)" == "Darwin" ]]; then
  cat > "${MOCK_BIN}/brew" <<EOF
#!/usr/bin/env bash
echo "brew \$*" >> "${MOCK_LOG}"
case "\$1" in
  list) exit 1 ;;
  install|services) exit 0 ;;
  *) exit 0 ;;
esac
EOF
  chmod +x "${MOCK_BIN}/brew"
else
  cat > "${MOCK_BIN}/apt-get" <<EOF
#!/usr/bin/env bash
echo "apt-get \$*" >> "${MOCK_LOG}"
exit 0
EOF
  chmod +x "${MOCK_BIN}/apt-get"
fi

ON_FIRST_STATE="${TMP_ROOT}/on-first-state"
mkdir -p "${ON_FIRST_STATE}"
ON_FIRST_RUN=(
  env
  "HOME=${HOME_DIR}"
  "PLUME_STATE_DIR=${ON_FIRST_STATE}"
  "PLUME_AUTO_HOST_BOOTSTRAP=false"
  "PLUME_SERVICES_MANIFEST_FILE=${ON_FIRST_MANIFEST}"
  "PLUME_NONINTERACTIVE=1"
  "PATH=${MOCK_BIN}:/usr/bin:/bin"
  "PLUME_ALLOW_NON_ROOT_INSTALL=true"
)

"${ON_FIRST_RUN[@]}" ./plume.sh mode use native --force --yes >/dev/null

"${ON_FIRST_RUN[@]}" ./plume.sh services manifest show >/dev/null || {
  echo "[FAIL] on_first_run bootstrap command failed" >&2
  exit 1
}

FLAG="${ON_FIRST_STATE}/on_first_run_provision.done"
[[ -f "${FLAG}" ]] || {
  echo "[FAIL] expected on_first_run_provision.done after first bootstrap" >&2
  exit 1
}

if [[ "$(uname -s)" == "Darwin" ]]; then
  grep -q 'brew install nginx' "${MOCK_LOG}" || {
    echo "[FAIL] on_first_run should invoke mock brew install nginx" >&2
    exit 1
  }
fi

: > "${MOCK_LOG}"
"${ON_FIRST_RUN[@]}" ./plume.sh services manifest show >/dev/null
if [[ "$(uname -s)" == "Darwin" ]] && grep -q 'brew install nginx' "${MOCK_LOG}"; then
  echo "[FAIL] on_first_run should not re-provision after done flag" >&2
  exit 1
fi

echo "[PASS] provision.on_first_run idempotent (mock host)"

echo "phase11_services_manifest_smoke:ok"
