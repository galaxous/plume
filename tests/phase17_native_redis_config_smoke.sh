#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

TMP_ROOT="$(mktemp -d)"
HOME_DIR="${TMP_ROOT}/home"
STATE_DIR="${TMP_ROOT}/state"
MAIN_CONF="${TMP_ROOT}/redis.conf"
mkdir -p "${HOME_DIR}" "${STATE_DIR}"

cleanup() { rm -rf "${TMP_ROOT}"; }
trap cleanup EXIT

cat > "${MAIN_CONF}" <<'EOF'
# sample redis.conf
port 6379
bind 127.0.0.1
EOF

BASE_ENV=(
  "HOME=${HOME_DIR}"
  "PLUME_STATE_DIR=${STATE_DIR}"
  "PATH=/usr/bin:/bin"
  "PLUME_NATIVE_HOST_PROVISION=true"
  "PLUME_NATIVE_HOST_INSTALL_DRIVER=mock"
  "PLUME_NATIVE_REDIS_MAIN_CONF=${MAIN_CONF}"
  "PLUME_REDIS_PASSWORD=deneme"
  "PLUME_REDIS_PORT=6379"
)

export HOME="${HOME_DIR}"
export PLUME_STATE_DIR="${STATE_DIR}"
export PATH="/usr/bin:/bin"
export PLUME_NATIVE_HOST_PROVISION=true
export PLUME_NATIVE_HOST_INSTALL_DRIVER=mock
export PLUME_NATIVE_REDIS_MAIN_CONF="${MAIN_CONF}"
export PLUME_REDIS_PASSWORD=deneme
export PLUME_REDIS_PORT=6379

# shellcheck source=../lib/bootstrap.sh
source "${ROOT_DIR}/lib/bootstrap.sh"

DRY="$(plume_native_redis_sync_config true false)"
echo "${DRY}" | grep -q 'action: redis-sync-config' || {
  echo "[FAIL] dry-run action" >&2
  printf '%s\n' "${DRY}" >&2
  exit 1
}

plume_native_redis_sync_config false false

PLUME_CONF="$(plume_native_redis_plume_conf_path)"
grep -q '^requirepass deneme$' "${PLUME_CONF}" || {
  echo "[FAIL] plume-redis.conf missing requirepass" >&2
  cat "${PLUME_CONF}" >&2
  exit 1
}
grep -Fq '# >>> plume-managed include >>>' "${MAIN_CONF}" || {
  echo "[FAIL] main redis.conf missing plume include" >&2
  cat "${MAIN_CONF}" >&2
  exit 1
}
echo "[PASS] redis config sync + include"

echo "phase17-native-redis-config-smoke:ok"
