#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

TMP_ROOT="$(mktemp -d)"
HERMETIC_HOME="${TMP_ROOT}/home"
MOCK_BIN="${TMP_ROOT}/bin"
MAIN_CONF="${TMP_ROOT}/redis.conf"
export HOME="${HERMETIC_HOME}"
export PLUME_STATE_DIR="${TMP_ROOT}/state"
export PLUME_LOG_DIR="${TMP_ROOT}/logs"
export PLUME_MODE="native"
export PLUME_SKIP_ON_FIRST_RUN_PROVISION=true
export PLUME_NATIVE_HOST_INSTALL_DRIVER=mock
export PLUME_NATIVE_REDIS_MAIN_CONF="${MAIN_CONF}"
export PLUME_PHP_EXTENSIONS_AUTO_SYNC=false
export PATH="${MOCK_BIN}:/usr/bin:/bin"
mkdir -p "${HERMETIC_HOME}/.config/plume" "${PLUME_STATE_DIR}" "${PLUME_LOG_DIR}" "${MOCK_BIN}"
: > "${HERMETIC_HOME}/.config/plume/.env"
printf '%s\n' 'port 6379' 'bind 127.0.0.1' > "${MAIN_CONF}"

cat > "${MOCK_BIN}/brew" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "${MOCK_BIN}/brew"

cleanup() {
  rm -rf "${TMP_ROOT}"
}
trap cleanup EXIT

assert_ok() {
  local name="$1"
  shift
  if "$@"; then
    echo "[PASS] ${name}"
  else
    echo "[FAIL] ${name}" >&2
    return 1
  fi
}

assert_ok "native up redis" ./plume.sh services up redis
assert_ok "native status shows running field" bash -lc "./plume.sh services status --mode=native | grep -q 'redis'"
assert_ok "native health redis shows value" bash -lc "./plume.sh services health redis --mode=native | grep -Eq 'healthy|stopped|disabled'"
assert_ok "native logs redis readable" bash -lc "./plume.sh services logs redis --mode=native --tail=20 >/tmp/plume-phase6-native-e2e.log"
assert_ok "native down redis" ./plume.sh services down redis
assert_ok "native health all works" ./plume.sh services health --mode=native

echo "phase6-native-e2e-smoke:ok"
