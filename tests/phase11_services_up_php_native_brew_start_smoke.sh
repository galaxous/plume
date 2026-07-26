#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

TMP_ROOT="$(mktemp -d)"
HOME_DIR="${TMP_ROOT}/home"
STATE_DIR="${TMP_ROOT}/state"
MOCK_BIN="${TMP_ROOT}/bin"
MOCK_LOG="${TMP_ROOT}/brew.log"
FAKE_BIN="${TMP_ROOT}/fake-php-bin"
mkdir -p "${HOME_DIR}" "${STATE_DIR}" "${MOCK_BIN}" "${FAKE_BIN}"

cleanup() {
  rm -rf "${TMP_ROOT}"
}
trap cleanup EXIT

cat > "${MOCK_BIN}/brew" <<EOF
#!/usr/bin/env bash
echo "brew \$*" >> "${MOCK_LOG}"
case "\$1" in
  list)
    if [[ "\$2" == "--formula" ]]; then
      case "\${3:-}" in
        php@8.2|php@8.3|php) exit 0 ;;
      esac
    fi
    exit 1
    ;;
  services) exit 0 ;;
  *) exit 0 ;;
esac
EOF
chmod +x "${MOCK_BIN}/brew"

cat > "${FAKE_BIN}/php8.2" <<'EOF'
#!/usr/bin/env bash
echo "PHP 8.2.99-cli"
EOF
chmod +x "${FAKE_BIN}/php8.2"

cat > "${FAKE_BIN}/php-fpm-8.2" <<'EOF'
#!/usr/bin/env bash
echo "PHP 8.2.99-fpm"
EOF
chmod +x "${FAKE_BIN}/php-fpm-8.2"

BASE_ENV=(
  "HOME=${HOME_DIR}"
  "PLUME_STATE_DIR=${STATE_DIR}"
  "PATH=${MOCK_BIN}:/usr/bin:/bin"
  "PLUME_ALLOW_NON_ROOT_INSTALL=true"
  "PLUME_PHP_NATIVE_INSTALL_DRIVER=brew"
  "PLUME_PHP_FPM_VERIFY_AFTER_START=false"
  "PLUME_PHP_SHIM_SEARCH_PATH=${FAKE_BIN}"
  "PLUME_PHP_INSTALLED_VERSIONS=8.2,8.3"
  "PLUME_PHP_DEFAULT_VERSION=8.3"
  "PLUME_PHP_AUTOPROVISION_ALL_ON_UP=false"
)

OUT_FILE="${TMP_ROOT}/up.out"
env "${BASE_ENV[@]}" ./plume.sh services up php82 --mode=native > "${OUT_FILE}" 2>&1

grep -q 'native php fpm: starting php@8.2 (brew services)' "${OUT_FILE}" || {
  echo "[FAIL] expected brew start log for php@8.2" >&2
  cat "${OUT_FILE}" >&2 || true
  exit 1
}

grep -q 'brew services start php@8.2' "${MOCK_LOG}" || {
  echo "[FAIL] mock brew should run: brew services start php@8.2" >&2
  cat "${MOCK_LOG}" >&2 || true
  exit 1
}

grep -q 'start hook: php (native) \[version=8.2\]' "${OUT_FILE}" || {
  echo "[FAIL] expected start hook version=8.2" >&2
  cat "${OUT_FILE}" >&2 || true
  exit 1
}

echo "phase11-services-up-php-native-brew-start-smoke:ok"
