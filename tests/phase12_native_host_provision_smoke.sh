#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

TMP_ROOT="$(mktemp -d)"
HOME_DIR="${TMP_ROOT}/home"
STATE_DIR="${TMP_ROOT}/state"
MOCK_BIN="${TMP_ROOT}/bin"
MOCK_LOG="${TMP_ROOT}/pkg.log"
mkdir -p "${HOME_DIR}" "${STATE_DIR}" "${MOCK_BIN}"

cleanup() {
  rm -rf "${TMP_ROOT}"
}
trap cleanup EXIT

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

BASE_ENV=(
  "HOME=${HOME_DIR}"
  "PLUME_STATE_DIR=${STATE_DIR}"
  "PATH=${MOCK_BIN}:${PATH}"
  "PLUME_NATIVE_HOST_PROVISION=true"
  "PLUME_ALLOW_NON_ROOT_INSTALL=true"
  "PLUME_WEB_SERVER_ENABLED=false"
  "PLUME_PHP_ENABLED=false"
  "PLUME_MARIADB_ENABLED=false"
  "PLUME_COMPOSER_ENABLED=false"
)

env "${BASE_ENV[@]}" ./plume.sh mode use native --force --yes >/dev/null

if ! env "${BASE_ENV[@]}" ./plume.sh services install web --mode=native >/dev/null; then
  echo "[FAIL] services install nginx with host provision" >&2
  exit 1
fi

if [[ "$(uname -s)" == "Darwin" ]]; then
  if ! grep -q 'brew install nginx' "${MOCK_LOG}"; then
    echo "[FAIL] expected mock brew install nginx" >&2
    cat "${MOCK_LOG}" >&2
    exit 1
  fi
  echo "[PASS] native host provision install nginx (mock brew)"
else
  if ! grep -q 'apt-get' "${MOCK_LOG}"; then
    echo "[FAIL] expected mock apt-get install" >&2
    cat "${MOCK_LOG}" >&2
    exit 1
  fi
  echo "[PASS] native host provision install nginx (mock apt)"
fi

if [[ "${PLUME_RUN_INTEGRATION:-0}" == "1" ]]; then
  echo "[RUN] integration: run locally with real brew/apt and PLUME_NATIVE_HOST_PROVISION=true"
fi

echo "phase12-native-host-provision-smoke:ok"
