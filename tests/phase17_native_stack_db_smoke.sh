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

cleanup() { rm -rf "${TMP_ROOT}"; }
trap cleanup EXIT

cat > "${MOCK_BIN}/brew" <<EOF
#!/usr/bin/env bash
echo "brew \$*" >> "${MOCK_LOG}"
case "\$1" in
  list) exit 1 ;;
  tap) exit 0 ;;
  install|services) exit 0 ;;
  *) exit 0 ;;
esac
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
  "PLUME_POSTGRES_ENABLED=true"
  "PLUME_PHPMYADMIN_ENABLED=true"
  "PMA_DB_ENGINE=mariadb"
  "PLUME_MARIADB_ENABLED=true"
)

env "${BASE_ENV[@]}" ./plume.sh mode use native --force --yes >/dev/null

OUT="$(env "${BASE_ENV[@]}" ./plume.sh services install postgres --mode=native 2>&1)"
echo "${OUT}" | grep -q 'mock install: postgres' || {
  echo "[FAIL] expected mock postgres install" >&2
  printf '%s\n' "${OUT}" >&2
  exit 1
}
echo "[PASS] postgres mock install"

CREDS="$(env "${BASE_ENV[@]}" ./plume.sh services credentials postgres --mode=native)"
echo "${CREDS}" | grep -q 'host=127.0.0.1' || {
  echo "[FAIL] postgres credentials" >&2
  printf '%s\n' "${CREDS}" >&2
  exit 1
}
echo "[PASS] postgres credentials"

env "${BASE_ENV[@]}" ./plume.sh services install phpmyadmin --mode=native >/dev/null
echo "[PASS] phpmyadmin mock install"

echo "phase17-native-stack-db-smoke:ok"
