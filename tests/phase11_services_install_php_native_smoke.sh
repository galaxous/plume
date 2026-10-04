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

env "${BASE_ENV[@]}" ./plume.sh services install php --mode=native --version=8.4 >/tmp/plume-phase11-install-php.out 2>&1

grep -q 'install hook: php (native) \[version=8.4\]' /tmp/plume-phase11-install-php.out || {
  echo "[FAIL] services install php should run native install hook with version=8.4" >&2
  cat /tmp/plume-phase11-install-php.out >&2 || true
  exit 1
}

PHP_STATE_FILE="${STATE_DIR}/php.env"
[[ -f "${PHP_STATE_FILE}" ]] || {
  echo "[FAIL] expected php state file: ${PHP_STATE_FILE}" >&2
  exit 1
}

grep -q '^PLUME_PHP_INSTALLED_VERSIONS=8.3,8.4$' "${PHP_STATE_FILE}" || {
  echo "[FAIL] expected php 8.4 added to installed versions" >&2
  cat "${PHP_STATE_FILE}" >&2
  exit 1
}

echo "phase11-services-install-php-native-smoke:ok"
