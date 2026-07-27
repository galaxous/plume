#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

TMP_ROOT="$(mktemp -d)"
HOME_DIR="${TMP_ROOT}/home"
STATE_DIR="${TMP_ROOT}/state"
MOCK_BIN="${TMP_ROOT}/bin"
MOCK_LOG="${TMP_ROOT}/pkg.log"
MANIFEST="${TMP_ROOT}/services.yml"
mkdir -p "${HOME_DIR}" "${STATE_DIR}" "${MOCK_BIN}"

cleanup() {
  rm -rf "${TMP_ROOT}"
}
trap cleanup EXIT

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "[SKIP] mailpit native host provision smoke (macOS Homebrew only)"
  echo "phase12-native-host-provision-mailpit-smoke:ok"
  exit 0
fi

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

cat > "${MANIFEST}" <<'EOF'
version: 1
services:
  web:
    enabled: false
  php:
    enabled: false
  database:
    engine: mariadb
  mailpit:
    enabled: true
  provision:
    interactive: false
EOF

BASE_ENV=(
  "HOME=${HOME_DIR}"
  "PLUME_STATE_DIR=${STATE_DIR}"
  "PLUME_SERVICES_MANIFEST_FILE=${MANIFEST}"
  "PATH=${MOCK_BIN}:/usr/bin:/bin"
  "PLUME_NATIVE_HOST_PROVISION=true"
  "PLUME_ALLOW_NON_ROOT_INSTALL=true"
  "PLUME_SKIP_ON_FIRST_RUN_PROVISION=true"
  "PLUME_NONINTERACTIVE=1"
)

env "${BASE_ENV[@]}" ./plume.sh mode use native --force --yes >/dev/null

if ! env "${BASE_ENV[@]}" ./plume.sh services install mailpit --mode=native >/dev/null; then
  echo "[FAIL] services install mailpit with host provision" >&2
  exit 1
fi

if ! grep -q 'brew install mailpit' "${MOCK_LOG}"; then
  echo "[FAIL] expected mock brew install mailpit" >&2
  cat "${MOCK_LOG}" >&2
  exit 1
fi

if ! env "${BASE_ENV[@]}" ./plume.sh services up mailpit --mode=native >/dev/null; then
  echo "[FAIL] services up mailpit" >&2
  exit 1
fi

if ! grep -q 'brew services start mailpit' "${MOCK_LOG}"; then
  echo "[FAIL] expected mock brew services start mailpit" >&2
  cat "${MOCK_LOG}" >&2
  exit 1
fi

echo "[PASS] native host provision mailpit (mock brew)"
echo "phase12-native-host-provision-mailpit-smoke:ok"
