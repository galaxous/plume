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
  PLUME_PHP_AUTOPROVISION_ALL_ON_UP="false" \
  PLUME_PHP_INSTALLED_VERSIONS="8.3,8.4" \
  PLUME_PHP_DEFAULT_VERSION="8.3" \
  PLUME_PHP_EXTENSIONS_GLOBAL="redis" \
  PLUME_PHP_EXTENSIONS_AUTO_SYNC="true" \
  PLUME_PHP_EXTENSIONS_AUTO_SYNC_PROFILE="target" \
  PLUME_PHP_EXT_INSTALL_DRIVER="mock" \
  ./plume.sh services up php --mode=native --version=8.4 >/tmp/plume-phase11-up-php-ext-profile-target.out

grep -q 'native php extension auto-sync profile=target version=8.4' /tmp/plume-phase11-up-php-ext-profile-target.out || {
  echo "[FAIL] expected target profile log line" >&2
  cat /tmp/plume-phase11-up-php-ext-profile-target.out >&2 || true
  exit 1
}

grep -q 'php extension ready: php=8.4 ext=redis' /tmp/plume-phase11-up-php-ext-profile-target.out || {
  echo "[FAIL] target profile should sync target php version extensions" >&2
  cat /tmp/plume-phase11-up-php-ext-profile-target.out >&2 || true
  exit 1
}

if grep -q 'php=8.3 ext=' /tmp/plume-phase11-up-php-ext-profile-target.out; then
  echo "[FAIL] target profile must not sync non-target versions" >&2
  cat /tmp/plume-phase11-up-php-ext-profile-target.out >&2 || true
  exit 1
fi

echo "phase11-services-up-php-ext-autosync-profile-target-smoke:ok"
