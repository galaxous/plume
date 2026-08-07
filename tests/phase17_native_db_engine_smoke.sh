#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

TMP_ROOT="$(mktemp -d)"
HOME_DIR="${TMP_ROOT}/home"
STATE_DIR="${TMP_ROOT}/state"
MOCK_BIN="${TMP_ROOT}/bin"
CONFIG_DIR="${HOME_DIR}/.config/plume"
MANIFEST="${CONFIG_DIR}/services.yml"
mkdir -p "${HOME_DIR}" "${STATE_DIR}" "${MOCK_BIN}" "${CONFIG_DIR}"

cleanup() { rm -rf "${TMP_ROOT}"; }
trap cleanup EXIT

cat > "${MOCK_BIN}/brew" <<'EOF'
#!/usr/bin/env bash
case "$1" in
  list) exit 1 ;;
  services) exit 0 ;;
  *) exit 0 ;;
esac
EOF
chmod +x "${MOCK_BIN}/brew"

cat > "${MOCK_BIN}/mysqladmin" <<'EOF'
#!/usr/bin/env bash
exit 1
EOF
chmod +x "${MOCK_BIN}/mysqladmin"

BASE_ENV=(
  "HOME=${HOME_DIR}"
  "PLUME_STATE_DIR=${STATE_DIR}"
  "PATH=${MOCK_BIN}:/usr/bin:/bin"
  "PLUME_SKIP_ON_FIRST_RUN_PROVISION=true"
  "PLUME_SERVICES_MANIFEST_FILE=${TMP_ROOT}/no-manifest.yml"
  "PLUME_ENV_FILE=${TMP_ROOT}/empty.env"
)
touch "${TMP_ROOT}/empty.env"

# Stale running=true without health probe must not report healthy.
RUNTIME="${STATE_DIR}/services_runtime_native.env"
printf '%s\n' 'mysql.running=true' > "${RUNTIME}"
OUT="$(env "${BASE_ENV[@]}" PLUME_MYSQL_ENABLED=true ./plume.sh services status mysql --mode=native 2>/dev/null | grep '^mysql' || true)"
echo "${OUT}" | grep -q 'starting' || {
  echo "[FAIL] stale running must not show healthy (expected starting)" >&2
  printf '%s\n' "${OUT}" >&2
  exit 1
}
echo "${OUT}" | grep -q 'healthy' && {
  echo "[FAIL] stale running must not show healthy" >&2
  printf '%s\n' "${OUT}" >&2
  exit 1
}
echo "[PASS] native status uses health probe not stale running flag"

# Dual engine: start must fail on brew when both enabled (non-mock health path uses real pm check).
if [[ "$(uname -s)" == "Darwin" ]]; then
  START_OUT="$(env "${BASE_ENV[@]}" \
    PLUME_MARIADB_ENABLED=true \
    PLUME_MYSQL_ENABLED=true \
    ./plume.sh services up mysql --mode=native 2>&1)" && {
    echo "[FAIL] dual engine start should fail" >&2
    printf '%s\n' "${START_OUT}" >&2
    exit 1
  }
  echo "${START_OUT}" | grep -qi 'cannot start mariadb and mysql' || {
    echo "[FAIL] expected dual engine error message" >&2
    printf '%s\n' "${START_OUT}" >&2
    exit 1
  }
  echo "[PASS] dual engine brew guard on start"
else
  echo "[PASS] dual engine brew guard skipped (not macOS)"
fi

# Manifest ${VAR} interpolation from defaults.
cat > "${MANIFEST}" <<'EOF'
version: 1
services:
  web:
    engine: nginx
  php:
    enabled: false
  database:
    engine: mariadb
  phpmyadmin:
    enabled: ${PHPMYADMIN_ENABLED}
  provision:
    interactive: false
EOF

SHOW="$(env \
  "HOME=${HOME_DIR}" \
  "PLUME_STATE_DIR=${STATE_DIR}" \
  "PLUME_SERVICES_MANIFEST_FILE=${MANIFEST}" \
  "PLUME_ENV_FILE=${TMP_ROOT}/empty.env" \
  "PLUME_SKIP_ON_FIRST_RUN_PROVISION=true" \
  ./plume.sh services manifest show 2>/dev/null)"
echo "${SHOW}" | grep -q 'effective_phpmyadmin_enabled=false' || {
  echo "[FAIL] expected phpmyadmin enabled=false from \${PHPMYADMIN_ENABLED} default" >&2
  printf '%s\n' "${SHOW}" >&2
  exit 1
}
echo "[PASS] manifest \${VAR} interpolation (Laradock-style)"

# Backward compat: ${PLUME_PHPMYADMIN_ENABLED} still resolves via alias mirror.
cat > "${MANIFEST}" <<'EOF'
version: 1
services:
  web:
    engine: nginx
  php:
    enabled: false
  database:
    engine: mariadb
  phpmyadmin:
    enabled: ${PLUME_PHPMYADMIN_ENABLED}
  provision:
    interactive: false
EOF

SHOW_LEGACY="$(env \
  "HOME=${HOME_DIR}" \
  "PLUME_STATE_DIR=${STATE_DIR}" \
  "PLUME_SERVICES_MANIFEST_FILE=${MANIFEST}" \
  "PLUME_ENV_FILE=${TMP_ROOT}/empty.env" \
  "PLUME_SKIP_ON_FIRST_RUN_PROVISION=true" \
  ./plume.sh services manifest show 2>/dev/null)"
echo "${SHOW_LEGACY}" | grep -q 'effective_phpmyadmin_enabled=false' || {
  echo "[FAIL] expected phpmyadmin enabled=false from legacy \${PLUME_PHPMYADMIN_ENABLED}" >&2
  printf '%s\n' "${SHOW_LEGACY}" >&2
  exit 1
}
echo "[PASS] manifest \${PLUME_*} backward compat"

echo "phase17-native-db-engine-smoke:ok"
