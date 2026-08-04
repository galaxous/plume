#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

TMP_ROOT="$(mktemp -d)"
HOME_DIR="${TMP_ROOT}/home"
STATE_DIR="${TMP_ROOT}/state"
MOCK_BIN="${TMP_ROOT}/bin"
mkdir -p "${HOME_DIR}" "${STATE_DIR}" "${MOCK_BIN}"

cleanup() { rm -rf "${TMP_ROOT}"; }
trap cleanup EXIT

cat > "${MOCK_BIN}/npm" <<'EOF'
#!/usr/bin/env bash
echo "npm $*"
exit 0
EOF
chmod +x "${MOCK_BIN}/npm"

cat > "${MOCK_BIN}/mongo-express" <<'EOF'
#!/usr/bin/env bash
sleep 3600 &
exit 0
EOF
chmod +x "${MOCK_BIN}/mongo-express"

cat > "${MOCK_BIN}/redis-commander" <<'EOF'
#!/usr/bin/env bash
sleep 3600 &
exit 0
EOF
chmod +x "${MOCK_BIN}/redis-commander"

cat > "${MOCK_BIN}/php" <<'EOF'
#!/usr/bin/env bash
sleep 3600 &
exit 0
EOF
chmod +x "${MOCK_BIN}/php"

BASE_ENV=(
  "HOME=${HOME_DIR}"
  "PLUME_STATE_DIR=${STATE_DIR}"
  "PATH=${MOCK_BIN}:/usr/bin:/bin"
  "PLUME_NATIVE_HOST_PROVISION=true"
  "PLUME_NATIVE_HOST_INSTALL_DRIVER=mock"
  "PLUME_ALLOW_NON_ROOT_INSTALL=true"
  "PLUME_SKIP_ON_FIRST_RUN_PROVISION=true"
  "PLUME_MONGO_WEBUI_ENABLED=true"
  "PLUME_REDIS_WEBUI_ENABLED=true"
)

env "${BASE_ENV[@]}" ./plume.sh mode use native --force --yes >/dev/null

env "${BASE_ENV[@]}" ./plume.sh services install mongo_webui --mode=native >/dev/null
env "${BASE_ENV[@]}" ./plume.sh services up mongo_webui --mode=native >/dev/null
URL_ME="$(env "${BASE_ENV[@]}" ./plume.sh services url mongo_webui --mode=native)"
echo "${URL_ME}" | grep -q 'url=http://127.0.0.1:' || {
  echo "[FAIL] mongo_webui url" >&2
  printf '%s\n' "${URL_ME}" >&2
  exit 1
}
echo "[PASS] mongo_webui url"

env "${BASE_ENV[@]}" ./plume.sh services install redis_webui --mode=native >/dev/null
URL_RE="$(env "${BASE_ENV[@]}" ./plume.sh services url redis_webui --mode=native)"
echo "${URL_RE}" | grep -q 'url=http://127.0.0.1:8083' || {
  echo "[FAIL] redis_webui url" >&2
  printf '%s\n' "${URL_RE}" >&2
  exit 1
}
echo "[PASS] redis_webui url"

echo "phase17-native-stack-webui-smoke:ok"
