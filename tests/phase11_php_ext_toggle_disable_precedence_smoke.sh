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
  # intentionally empty module list for the test
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

OUT_FILE="/tmp/plume-phase11-ext-toggle-disable.out"
env \
  HOME="${HOME_DIR}" \
  PLUME_STATE_DIR="${STATE_DIR}" \
  PLUME_PHP_SHIM_SEARCH_PATH="${FAKE_BIN}" \
  PLUME_PHP_EXT_INSTALL_DRIVER="mock" \
  PLUME_PHP_DEFAULT_VERSION="8.4" \
  PLUME_PHP_INSTALLED_VERSIONS="8.4" \
  PLUME_PHP_EXTENSIONS_GLOBAL="imagick" \
  PLUME_PHP_EXT_DISABLE_84_IMAGICK="true" \
  ./plume.sh php ext sync 8.4 --strict > "${OUT_FILE}" 2>&1

if grep -q 'ext=imagick' "${OUT_FILE}"; then
  echo "[FAIL] imagick should not be processed when disabled by toggle" >&2
  cat "${OUT_FILE}" >&2 || true
  exit 1
fi

echo "phase11-php-ext-toggle-disable-precedence-smoke:ok"
