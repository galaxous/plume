#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

TMP_ROOT="$(mktemp -d)"
HOME_DIR="${TMP_ROOT}/home"
STATE_DIR="${TMP_ROOT}/state"
FAKE_BIN="${TMP_ROOT}/fake-bin"
mkdir -p "${HOME_DIR}" "${STATE_DIR}" "${FAKE_BIN}"

cleanup() {
  rm -rf "${TMP_ROOT}"
}
trap cleanup EXIT

cat > "${FAKE_BIN}/php8.4" <<'EOF'
#!/usr/bin/env bash
echo "PHP 8.4.99-cli"
EOF
chmod +x "${FAKE_BIN}/php8.4"

cat > "${FAKE_BIN}/php-fpm-8.4" <<'EOF'
#!/usr/bin/env bash
echo "PHP 8.4.99-fpm"
EOF
chmod +x "${FAKE_BIN}/php-fpm-8.4"

BASE_ENV=(
  "HOME=${HOME_DIR}"
  "PLUME_STATE_DIR=${STATE_DIR}"
  "PLUME_ALLOW_NON_ROOT_INSTALL=true"
  "PLUME_PHP_NATIVE_INSTALL_DRIVER=mock"
  "PLUME_PHP_SHIM_SEARCH_PATH=${FAKE_BIN}"
  "PLUME_PHP_INSTALLED_VERSIONS=8.3"
  "PLUME_PHP_DEFAULT_VERSION=8.3"
)

OUT_FILE="/tmp/plume-phase11-up-php-autoprovision.out"
env "${BASE_ENV[@]}" ./plume.sh services up php --mode=native --version=8.4 > "${OUT_FILE}"

grep -q 'native php 8.4 auto-provision: triggered by services up php' "${OUT_FILE}" || {
  echo "[FAIL] services up php should auto-provision missing version" >&2
  cat "${OUT_FILE}" >&2 || true
  exit 1
}

grep -q 'start hook: php (native) \[version=8.4\]' "${OUT_FILE}" || {
  echo "[FAIL] services up php should start with version=8.4" >&2
  cat "${OUT_FILE}" >&2 || true
  exit 1
}

PHP_STATE_FILE="${STATE_DIR}/php.env"
grep -q '^PLUME_PHP_INSTALLED_VERSIONS=8.3,8.4$' "${PHP_STATE_FILE}" || {
  echo "[FAIL] php auto-provision should register 8.4 in php.env" >&2
  cat "${PHP_STATE_FILE}" >&2 || true
  exit 1
}

echo "phase11-services-up-php-native-autoprovision-smoke:ok"
