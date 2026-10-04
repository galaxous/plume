#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

assert_ok() {
  local name="$1"
  shift
  if "$@" >/tmp/plume-phase6-output.txt 2>&1; then
    echo "[PASS] ${name}"
  else
    echo "[FAIL] ${name}" >&2
    return 1
  fi
}

assert_fail_code() {
  local expected="$1"
  local name="$2"
  shift 2
  set +e
  "$@" >/tmp/plume-phase6-output.txt 2>&1
  local got=$?
  set -e
  if [[ "${got}" -eq "${expected}" ]]; then
    echo "[PASS] ${name}"
  else
    echo "[FAIL] ${name} (expected ${expected}, got ${got})" >&2
    cat /tmp/plume-phase6-output.txt >&2
    return 1
  fi
}

PHASE6_HERMETIC_ROOT="$(mktemp -d)"
PHASE6_HOME_DIR="${PHASE6_HERMETIC_ROOT}/home"
PHASE6_STATE_DIR="${PHASE6_HERMETIC_ROOT}/state"
PHASE6_FAKE_BIN="${PHASE6_HERMETIC_ROOT}/fake-bin"
mkdir -p "${PHASE6_HOME_DIR}" "${PHASE6_STATE_DIR}" "${PHASE6_FAKE_BIN}"
mkdir -p "${PHASE6_HOME_DIR}/.config/plume"
: > "${PHASE6_HOME_DIR}/.config/plume/.env"

cat > "${PHASE6_FAKE_BIN}/php8.3" <<'EOF'
#!/usr/bin/env bash
echo "PHP 8.3.99-cli"
EOF
chmod +x "${PHASE6_FAKE_BIN}/php8.3"

cat > "${PHASE6_FAKE_BIN}/php-fpm-8.3" <<'EOF'
#!/usr/bin/env bash
echo "PHP 8.3.99-fpm"
EOF
chmod +x "${PHASE6_FAKE_BIN}/php-fpm-8.3"

cleanup() {
  rm -f /tmp/plume-phase6-output.txt
  if [[ -n "${TMP_STATE_DIR:-}" && -d "${TMP_STATE_DIR}" ]]; then
    rm -rf "${TMP_STATE_DIR}"
  fi
  if [[ -n "${PHASE6_HERMETIC_ROOT:-}" && -d "${PHASE6_HERMETIC_ROOT}" ]]; then
    rm -rf "${PHASE6_HERMETIC_ROOT}"
  fi
}
trap cleanup EXIT

PHASE6_RUN=(
  env
  -u PLUME_SERVICES_MANIFEST_FILE
  "HOME=${PHASE6_HOME_DIR}"
  "PLUME_STATE_DIR=${PHASE6_STATE_DIR}"
  "PLUME_AUTO_HOST_BOOTSTRAP=false"
  "PLUME_SKIP_ON_FIRST_RUN_PROVISION=true"
)

assert_ok "services supported json includes version" bash -lc "cd '${ROOT_DIR}' && ${PHASE6_RUN[*]} ./plume.sh --json services supported --mode=native | grep -q '\"name\":\"php\".*\"version\":'"
assert_ok "services status json includes runtime+health+port" bash -lc "cd '${ROOT_DIR}' && ${PHASE6_RUN[*]} ./plume.sh --json services status --mode=native | grep -q '\"name\":\"php\".*\"running\".*\"health\".*\"port\"'"
assert_ok "services health json works" bash -lc "cd '${ROOT_DIR}' && ${PHASE6_RUN[*]} ./plume.sh --json services health php --mode=native | grep -q '\"health\"'"

assert_ok "services up php with alias" bash -lc "cd '${ROOT_DIR}' && ${PHASE6_RUN[*]} PLUME_ALLOW_NON_ROOT_INSTALL=true PLUME_PHP_NATIVE_INSTALL_DRIVER=mock PLUME_PHP_SHIM_SEARCH_PATH='${PHASE6_FAKE_BIN}' PLUME_PHP_AUTOPROVISION_ALL_ON_UP=false PLUME_PHP_INSTALLED_VERSIONS=8.3 PLUME_PHP_DEFAULT_VERSION=8.3 PLUME_PHP_EXTENSIONS_AUTO_SYNC=false PLUME_MODE=native ./plume.sh services up php --mode=native --version=php83 >/tmp/plume-phase6-output.txt 2>&1 && grep -q 'start hook: php (native) \[version=8.3\]' /tmp/plume-phase6-output.txt"
assert_fail_code 2 "invalid php version alias" bash -lc "cd '${ROOT_DIR}' && ${PHASE6_RUN[*]} PLUME_MODE=native ./plume.sh services up php --mode=native --version=php99"

assert_fail_code 2 "horizon requires supervisor" bash -lc "cd '${ROOT_DIR}' && ${PHASE6_RUN[*]} PLUME_MODE=native PLUME_HORIZON_ENABLED=true PLUME_SUPERVISOR_ENABLED=false ./plume.sh services up horizon --mode=native"
assert_ok "horizon starts when supervisor enabled" bash -lc "cd '${ROOT_DIR}' && ${PHASE6_RUN[*]} PLUME_MODE=native PLUME_NATIVE_HOST_INSTALL_DRIVER=mock PLUME_HORIZON_ENABLED=true PLUME_SUPERVISOR_ENABLED=true ./plume.sh services up horizon --mode=native"
assert_ok "services logs works for native" bash -lc "cd '${ROOT_DIR}' && ${PHASE6_RUN[*]} PLUME_MODE=native ./plume.sh services logs php --mode=native --tail=5 >/tmp/plume-phase6-output.txt && test -s /tmp/plume-phase6-output.txt"

if [[ "$(id -u)" -eq 0 ]]; then
  TMP_STATE_DIR="$(mktemp -d)"
  assert_ok "services update writes state" bash -lc "PLUME_HORIZON_ENABLED=true PLUME_SUPERVISOR_ENABLED=true PLUME_STATE_DIR='${TMP_STATE_DIR}' ./plume.sh services update"
  assert_ok "services state file includes service enabled and version keys" bash -lc "test -f '${TMP_STATE_DIR}/services_enabled.env' && grep -q '^php.enabled=' '${TMP_STATE_DIR}/services_enabled.env' && grep -q '^php.version=' '${TMP_STATE_DIR}/services_enabled.env'"
  assert_ok "services update reconcile false->true installs redis" bash -lc "PLUME_STATE_DIR='${TMP_STATE_DIR}' PLUME_REDIS_ENABLED=false ./plume.sh services update >/dev/null && PLUME_STATE_DIR='${TMP_STATE_DIR}' PLUME_REDIS_ENABLED=true ./plume.sh services update >/tmp/plume-phase6-output.txt 2>&1 && grep -q 'reconcile enable detected: redis' /tmp/plume-phase6-output.txt"
else
  assert_fail_code 2 "root guard services update" ./plume.sh services update
fi

echo "phase6-service-smoke:ok"
