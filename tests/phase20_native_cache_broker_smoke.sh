#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

TMP_ROOT="$(mktemp -d)"
HOME_DIR="${TMP_ROOT}/home"
STATE_DIR="${TMP_ROOT}/state"
MOCK_BIN="${TMP_ROOT}/bin"
mkdir -p "${HOME_DIR}/.config/plume" "${STATE_DIR}" "${MOCK_BIN}"
: > "${HOME_DIR}/.config/plume/.env"

cleanup() {
  if [[ -f "${STATE_DIR}/native-pids/mongo_webui.pid" ]]; then
    kill "$(cat "${STATE_DIR}/native-pids/mongo_webui.pid" 2>/dev/null || true)" 2>/dev/null || true
  fi
  if [[ -f "${STATE_DIR}/native-pids/redis_webui.pid" ]]; then
    kill "$(cat "${STATE_DIR}/native-pids/redis_webui.pid" 2>/dev/null || true)" 2>/dev/null || true
  fi
  rm -rf "${TMP_ROOT}"
}
trap cleanup EXIT

if [[ "$(uname -s)" == "Darwin" ]]; then
  cat > "${MOCK_BIN}/brew" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
  chmod +x "${MOCK_BIN}/brew"
else
  cat > "${MOCK_BIN}/apt-get" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
  chmod +x "${MOCK_BIN}/apt-get"
  cat > "${MOCK_BIN}/systemctl" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
  chmod +x "${MOCK_BIN}/systemctl"
fi

cat > "${MOCK_BIN}/npm" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "${MOCK_BIN}/npm"

cat > "${MOCK_BIN}/mongo-express" <<'EOF'
#!/usr/bin/env bash
exec sleep 3600
EOF
chmod +x "${MOCK_BIN}/mongo-express"

cat > "${MOCK_BIN}/redis-commander" <<'EOF'
#!/usr/bin/env bash
exec sleep 3600
EOF
chmod +x "${MOCK_BIN}/redis-commander"

BASE_ENV=(
  "HOME=${HOME_DIR}"
  "PLUME_STATE_DIR=${STATE_DIR}"
  "PATH=${MOCK_BIN}:/usr/bin:/bin"
  "PLUME_NATIVE_HOST_PROVISION=true"
  "PLUME_NATIVE_HOST_INSTALL_DRIVER=mock"
  "PLUME_ALLOW_NON_ROOT_INSTALL=true"
  "PLUME_SKIP_ON_FIRST_RUN_PROVISION=true"
  "PLUME_GLOBAL_ENV_FILE=${HOME_DIR}/.config/plume/.env"
  "PLUME_ENV_FILE=${HOME_DIR}/.config/plume/.env"
  "PLUME_MONGODB_ENABLED=true"
  "PLUME_RABBITMQ_ENABLED=true"
  "PLUME_MEMCACHED_ENABLED=true"
  "PLUME_MONGO_WEBUI_ENABLED=true"
  "PLUME_REDIS_WEBUI_ENABLED=true"
)

env "${BASE_ENV[@]}" ./plume.sh mode use native --force --yes >/dev/null

for svc in mongodb rabbitmq memcached; do
  env "${BASE_ENV[@]}" ./plume.sh services install "${svc}" --mode=native >/dev/null
  env "${BASE_ENV[@]}" ./plume.sh services up "${svc}" --mode=native >/dev/null
  CRED="$(env "${BASE_ENV[@]}" ./plume.sh services credentials "${svc}" --mode=native)"
  echo "${CRED}" | grep -q 'host=127.0.0.1' || {
    echo "[FAIL] ${svc} credentials host" >&2
    printf '%s\n' "${CRED}" >&2
    exit 1
  }
  echo "[PASS] ${svc} credentials"
done

RABBIT_URL="$(env "${BASE_ENV[@]}" ./plume.sh services url rabbitmq --mode=native)"
echo "${RABBIT_URL}" | grep -q 'url=http://127.0.0.1:15672' || {
  echo "[FAIL] rabbitmq management url" >&2
  printf '%s\n' "${RABBIT_URL}" >&2
  exit 1
}
echo "[PASS] rabbitmq url"

env "${BASE_ENV[@]}" ./plume.sh services install mongo_webui --mode=native >/dev/null
env "${BASE_ENV[@]}" ./plume.sh services up mongo_webui --mode=native >/dev/null
MONGO_URL="$(env "${BASE_ENV[@]}" ./plume.sh services url mongo_webui --mode=native)"
echo "${MONGO_URL}" | grep -q 'url=http://127.0.0.1:' || {
  echo "[FAIL] mongo_webui url" >&2
  printf '%s\n' "${MONGO_URL}" >&2
  exit 1
}
echo "[PASS] mongo_webui url"

env "${BASE_ENV[@]}" ./plume.sh services install redis_webui --mode=native >/dev/null
REDIS_URL="$(env "${BASE_ENV[@]}" ./plume.sh services url redis_webui --mode=native)"
echo "${REDIS_URL}" | grep -q 'url=http://127.0.0.1:8083' || {
  echo "[FAIL] redis_webui url" >&2
  printf '%s\n' "${REDIS_URL}" >&2
  exit 1
}
echo "[PASS] redis_webui url"

echo "phase20-native-cache-broker-smoke:ok"
