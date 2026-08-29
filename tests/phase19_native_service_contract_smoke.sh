#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

TMP_ROOT="$(mktemp -d)"
HOME_DIR="${TMP_ROOT}/home"
STATE_DIR="${TMP_ROOT}/state"
MOCK_BIN="${TMP_ROOT}/bin"
CONFIG_DIR="${HOME_DIR}/.config/plume"
mkdir -p "${HOME_DIR}" "${STATE_DIR}" "${MOCK_BIN}" "${CONFIG_DIR}"
: > "${CONFIG_DIR}/.env"

cleanup() { rm -rf "${TMP_ROOT}"; }
trap cleanup EXIT

cat > "${MOCK_BIN}/brew" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "${MOCK_BIN}/brew"

BASE_ENV=(
  "HOME=${HOME_DIR}"
  "PLUME_STATE_DIR=${STATE_DIR}"
  "PATH=${MOCK_BIN}:/usr/bin:/bin"
  "PLUME_NATIVE_HOST_PROVISION=true"
  "PLUME_NATIVE_HOST_INSTALL_DRIVER=mock"
  "PLUME_ALLOW_NON_ROOT_INSTALL=true"
  "PLUME_SKIP_ON_FIRST_RUN_PROVISION=true"
  "PLUME_SERVICES_MANIFEST_FILE=${CONFIG_DIR}/services.yml"
  "PLUME_GLOBAL_ENV_FILE=${CONFIG_DIR}/.env"
  "PLUME_ENV_FILE=${CONFIG_DIR}/.env"
)

cp "${ROOT_DIR}/templates/services.yml.example" "${CONFIG_DIR}/services.yml"

env "${BASE_ENV[@]}" ./plume.sh mode use native --force --yes >/dev/null

SUPPORTED="$(env "${BASE_ENV[@]}" ./plume.sh services supported --mode=native)"
echo "${SUPPORTED}" | grep -Eq '^@core[[:space:]]+' || {
  echo "[FAIL] expected @core in supported" >&2
  printf '%s\n' "${SUPPORTED}" >&2
  exit 1
}
CORE_LINE="$(printf '%s\n' "${SUPPORTED}" | grep -E '^@core[[:space:]]+' || true)"
echo "${CORE_LINE}" | grep -q 'horizon' && {
  echo "[FAIL] @core must not include horizon" >&2
  printf '%s\n' "${CORE_LINE}" >&2
  exit 1
}
echo "${CORE_LINE}" | grep -q 'php_worker' && {
  echo "[FAIL] @core must not include php_worker" >&2
  printf '%s\n' "${CORE_LINE}" >&2
  exit 1
}
echo "${CORE_LINE}" | grep -q 'postgres' || {
  echo "[FAIL] @core should include postgres" >&2
  printf '%s\n' "${CORE_LINE}" >&2
  exit 1
}
echo "${SUPPORTED}" | grep -Eq '^@cache[[:space:]]+' || {
  echo "[FAIL] expected @cache in supported" >&2
  exit 1
}
WEB_LINE="$(printf '%s\n' "${SUPPORTED}" | grep -E '^@web[[:space:]]+' || true)"
echo "${WEB_LINE}" | grep -Eq 'web' || {
  echo "[FAIL] @web must include registry service web (nginx/apache2/caddy variants)" >&2
  printf '%s\n' "${SUPPORTED}" >&2
  exit 1
}
echo "[PASS] @core membership (no queue; postgres present)"

RUNTIME="${STATE_DIR}/services_runtime_native.env"
mkdir -p "${STATE_DIR}/native-pids"
printf '%s\n' 'phpmyadmin.running=true' > "${RUNTIME}"
printf '%s\n' '999999' > "${STATE_DIR}/native-pids/phpmyadmin.pid"
STALE="$(env "${BASE_ENV[@]}" PLUME_PHPMYADMIN_ENABLED=true PHPMYADMIN_ENABLED=true \
  PLUME_MARIADB_ENABLED=true MARIADB_ENABLED=true \
  PMA_PORT=18081 PLUME_PHPMYADMIN_PORT=18081 \
  ./plume.sh services status phpmyadmin --mode=native 2>/dev/null | grep '^phpmyadmin' || true)"
echo "${STALE}" | grep -q 'stopped' || {
  echo "[FAIL] stale PID should be stopped" >&2
  printf '%s\n' "${STALE}" >&2
  exit 1
}
echo "${STALE}" | grep -q 'starting' && {
  echo "[FAIL] stale PID must not stay starting" >&2
  printf '%s\n' "${STALE}" >&2
  exit 1
}
echo "[PASS] stale HTTP PID → stopped"

USE_OUT="$(env "${BASE_ENV[@]}" ./plume.sh services use mysql --mode=native)"
echo "${USE_OUT}" | grep -q 'engine=mysql' || {
  echo "[FAIL] services use mysql engine" >&2
  printf '%s\n' "${USE_OUT}" >&2
  exit 1
}
echo "${USE_OUT}" | grep -q 'enabled_mysql=true' || {
  echo "[FAIL] mysql enabled" >&2
  printf '%s\n' "${USE_OUT}" >&2
  exit 1
}
echo "${USE_OUT}" | grep -q 'enabled_mariadb=false' || {
  echo "[FAIL] mariadb disabled after use mysql" >&2
  printf '%s\n' "${USE_OUT}" >&2
  exit 1
}
echo "${USE_OUT}" | grep -q 'enabled_phpmyadmin=true' || {
  echo "[FAIL] phpmyadmin mapped for mysql" >&2
  printf '%s\n' "${USE_OUT}" >&2
  exit 1
}
grep -q 'engine: mysql' "${CONFIG_DIR}/services.yml" || {
  echo "[FAIL] manifest database.engine not mysql" >&2
  grep -n 'engine:' "${CONFIG_DIR}/services.yml" >&2 || true
  exit 1
}
echo "[PASS] services use mysql XOR + phpmyadmin"

USE_PG="$(env "${BASE_ENV[@]}" ./plume.sh services use postgres --mode=native)"
echo "${USE_PG}" | grep -q 'engine=postgres' || {
  echo "[FAIL] services use postgres" >&2
  printf '%s\n' "${USE_PG}" >&2
  exit 1
}
echo "${USE_PG}" | grep -q 'enabled_phpmyadmin=false' || {
  echo "[FAIL] phpmyadmin off for postgres" >&2
  printf '%s\n' "${USE_PG}" >&2
  exit 1
}
echo "${USE_PG}" | grep -q 'enabled_pgadmin=true' || {
  echo "[FAIL] pgadmin mapped for postgres" >&2
  printf '%s\n' "${USE_PG}" >&2
  exit 1
}
echo "[PASS] services use postgres XOR + pgadmin"

env "${BASE_ENV[@]}" PLUME_REDIS_ENABLED=true ./plume.sh services install redis --mode=native >/dev/null
CRED="$(env "${BASE_ENV[@]}" ./plume.sh services credentials redis --mode=native)"
echo "${CRED}" | grep -q 'host=127.0.0.1' || {
  echo "[FAIL] redis credentials host" >&2
  printf '%s\n' "${CRED}" >&2
  exit 1
}
echo "${CRED}" | grep -q 'port=6379' || {
  echo "[FAIL] redis credentials port" >&2
  printf '%s\n' "${CRED}" >&2
  exit 1
}
echo "[PASS] redis credentials"

if [[ "$(uname -s)" == "Darwin" ]]; then
  env "${BASE_ENV[@]}" PLUME_MAILPIT_ENABLED=true ./plume.sh services install mailpit --mode=native >/dev/null
  MAIL_CRED="$(env "${BASE_ENV[@]}" ./plume.sh services credentials mailpit --mode=native)"
  echo "${MAIL_CRED}" | grep -q 'smtp_port=1025' || {
    echo "[FAIL] mailpit smtp_port" >&2
    printf '%s\n' "${MAIL_CRED}" >&2
    exit 1
  }
  MAIL_URL="$(env "${BASE_ENV[@]}" ./plume.sh services url mailpit --mode=native)"
  echo "${MAIL_URL}" | grep -q 'url=http://127.0.0.1:8025' || {
    echo "[FAIL] mailpit url" >&2
    printf '%s\n' "${MAIL_URL}" >&2
    exit 1
  }
  echo "[PASS] mailpit credentials/url"
else
  echo "[PASS] mailpit credentials skipped (not macOS brew)"
fi

echo "phase19-native-service-contract-smoke:ok"
