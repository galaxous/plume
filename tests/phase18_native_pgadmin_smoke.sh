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

cat > "${MOCK_BIN}/python3" <<'EOF'
#!/usr/bin/env bash
# Mock python3 -m venv is unused when install driver=mock
exit 0
EOF
chmod +x "${MOCK_BIN}/python3"

BASE_ENV=(
  "HOME=${HOME_DIR}"
  "PLUME_STATE_DIR=${STATE_DIR}"
  "PATH=${MOCK_BIN}:/usr/bin:/bin"
  "PLUME_NATIVE_HOST_PROVISION=true"
  "PLUME_NATIVE_HOST_INSTALL_DRIVER=mock"
  "PLUME_ALLOW_NON_ROOT_INSTALL=true"
  "PLUME_SKIP_ON_FIRST_RUN_PROVISION=true"
  "PLUME_POSTGRES_ENABLED=true"
  "PLUME_PGADMIN_ENABLED=true"
  "PLUME_PGADMIN_PORT=5050"
)

env "${BASE_ENV[@]}" ./plume.sh mode use native --force --yes >/dev/null

# postgres disabled → pgadmin must fail dependency
code=0
OUT="$(env "${BASE_ENV[@]}" PLUME_POSTGRES_ENABLED=false ./plume.sh services up pgadmin --mode=native 2>&1)" || code=$?
if [[ "${code}" -eq 0 ]]; then
  echo "[FAIL] pgadmin should require postgres enabled" >&2
  printf '%s\n' "${OUT}" >&2
  exit 1
fi
echo "${OUT}" | grep -qi 'postgres' || {
  echo "[FAIL] expected postgres dependency error" >&2
  printf '%s\n' "${OUT}" >&2
  exit 1
}
echo "[PASS] pgadmin requires postgres"

env "${BASE_ENV[@]}" ./plume.sh services install pgadmin --mode=native >/dev/null
env "${BASE_ENV[@]}" ./plume.sh services up pgadmin --mode=native >/dev/null

URL="$(env "${BASE_ENV[@]}" ./plume.sh services url pgadmin --mode=native)"
echo "${URL}" | grep -q 'url=http://127.0.0.1:5050' || {
  echo "[FAIL] pgadmin url" >&2
  printf '%s\n' "${URL}" >&2
  exit 1
}
echo "[PASS] pgadmin url"

CREDS="$(env "${BASE_ENV[@]}" ./plume.sh services credentials pgadmin --mode=native)"
echo "${CREDS}" | grep -q 'email=' || {
  echo "[FAIL] pgadmin credentials email" >&2
  printf '%s\n' "${CREDS}" >&2
  exit 1
}
echo "${CREDS}" | grep -q 'http_port=5050' || {
  echo "[FAIL] pgadmin credentials http_port" >&2
  printf '%s\n' "${CREDS}" >&2
  exit 1
}
echo "[PASS] pgadmin credentials"

env "${BASE_ENV[@]}" ./plume.sh services down pgadmin --mode=native >/dev/null
echo "[PASS] pgadmin down"

echo "phase18-native-pgadmin-smoke:ok"
