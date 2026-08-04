#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

TMP_ROOT="$(mktemp -d)"
HOME_DIR="${TMP_ROOT}/home"
STATE_DIR="${TMP_ROOT}/state"
ENV_FILE="${TMP_ROOT}/home/.config/plume/.env"
MOCK_BIN="${TMP_ROOT}/bin"
mkdir -p "${HOME_DIR}/.config/plume" "${STATE_DIR}" "${MOCK_BIN}"

cleanup() { rm -rf "${TMP_ROOT}"; }
trap cleanup EXIT

cat > "${MOCK_BIN}/npm" <<'EOF'
#!/usr/bin/env bash
echo "npm $*"
exit 0
EOF
chmod +x "${MOCK_BIN}/npm"

cat > "${MOCK_BIN}/redis-commander" <<'EOF'
#!/usr/bin/env bash
sleep 3600 &
exit 0
EOF
chmod +x "${MOCK_BIN}/redis-commander"

BASE_ENV=(
  "HOME=${HOME_DIR}"
  "PLUME_STATE_DIR=${STATE_DIR}"
  "PLUME_GLOBAL_ENV_FILE=${ENV_FILE}"
  "PATH=${MOCK_BIN}:/usr/bin:/bin"
  "PLUME_NATIVE_HOST_PROVISION=true"
  "PLUME_NATIVE_HOST_INSTALL_DRIVER=mock"
  "PLUME_ALLOW_NON_ROOT_INSTALL=true"
  "PLUME_SKIP_ON_FIRST_RUN_PROVISION=true"
  "PLUME_REDIS_ENABLED=true"
  "PLUME_REDIS_WEBUI_ENABLED=true"
)

env "${BASE_ENV[@]}" ./plume.sh mode use native --force --yes >/dev/null
touch "${ENV_FILE}"

env "${BASE_ENV[@]}" ./plume.sh services install redis --mode=native >/dev/null
CREDS="$(env "${BASE_ENV[@]}" ./plume.sh services credentials redis --mode=native)"
echo "${CREDS}" | grep -q 'password=secret_redis' || {
  echo "[FAIL] default redis password in credentials" >&2
  printf '%s\n' "${CREDS}" >&2
  exit 1
}
echo "[PASS] default redis credentials"

env "${BASE_ENV[@]}" ./plume.sh services env set redis password=custom_redis --mode=native >/dev/null
CREDS2="$(env "${BASE_ENV[@]}" ./plume.sh services credentials redis --mode=native)"
echo "${CREDS2}" | grep -q 'password=custom_redis' || {
  echo "[FAIL] services env set redis password" >&2
  printf '%s\n' "${CREDS2}" >&2
  exit 1
}
echo "[PASS] services env set redis"

grep -q '^PLUME_REDIS_PASSWORD=custom_redis$' "${ENV_FILE}" || {
  echo "[FAIL] global env file not updated" >&2
  cat "${ENV_FILE}" >&2
  exit 1
}
echo "[PASS] global env persisted"

env "${BASE_ENV[@]}" ./plume.sh services install redis_webui --mode=native >/dev/null
env "${BASE_ENV[@]}" ./plume.sh services up redis_webui --mode=native >/dev/null
env "${BASE_ENV[@]}" ./plume.sh services restart redis_webui --mode=native >/dev/null
echo "[PASS] services restart redis_webui"

SHOW="$(env "${BASE_ENV[@]}" ./plume.sh services env show redis --mode=native)"
echo "${SHOW}" | grep -q 'PLUME_REDIS_PASSWORD=custom_redis' || {
  echo "[FAIL] services env show redis" >&2
  printf '%s\n' "${SHOW}" >&2
  exit 1
}
echo "[PASS] services env show"

echo "phase17-native-stack-env-smoke:ok"
