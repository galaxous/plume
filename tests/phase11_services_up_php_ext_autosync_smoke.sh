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
if [[ "${1:-}" == "-m" ]]; then
  echo "redis"
  echo "imagick"
  exit 0
fi
echo "PHP 8.4.99-cli"
EOF
chmod +x "${FAKE_BIN}/php8.4"

cat > "${FAKE_BIN}/php-fpm-8.4" <<'EOF'
#!/usr/bin/env bash
echo "PHP 8.4.99-fpm"
EOF
chmod +x "${FAKE_BIN}/php-fpm-8.4"

env \
  HOME="${HOME_DIR}" \
  PLUME_STATE_DIR="${STATE_DIR}" \
  PLUME_ALLOW_NON_ROOT_INSTALL=true \
  PLUME_PHP_NATIVE_INSTALL_DRIVER="mock" \
  PLUME_PHP_SHIM_SEARCH_PATH="${FAKE_BIN}" \
  PLUME_PHP_INSTALLED_VERSIONS="8.4" \
  PLUME_PHP_DEFAULT_VERSION="8.4" \
  PLUME_PHP_EXTENSIONS_GLOBAL="redis" \
  PLUME_PHP_EXTENSIONS_84="imagick" \
  PLUME_PHP_EXT_INSTALL_DRIVER="mock" \
  PLUME_PHP_EXTENSIONS_AUTO_SYNC="true" \
  ./plume.sh services up php --mode=native --version=8.4 >/tmp/plume-phase11-up-php-ext-autosync.out 2>&1

grep -q 'php extension ready: php=8.4 ext=redis' /tmp/plume-phase11-up-php-ext-autosync.out || {
  echo "[FAIL] services up php should auto-sync redis extension" >&2
  cat /tmp/plume-phase11-up-php-ext-autosync.out >&2 || true
  exit 1
}

grep -q 'php extension ready: php=8.4 ext=imagick' /tmp/plume-phase11-up-php-ext-autosync.out || {
  echo "[FAIL] services up php should auto-sync imagick extension" >&2
  cat /tmp/plume-phase11-up-php-ext-autosync.out >&2 || true
  exit 1
}

echo "phase11-services-up-php-ext-autosync-smoke:ok"
