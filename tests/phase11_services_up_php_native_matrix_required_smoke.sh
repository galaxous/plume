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

cat > "${FAKE_BIN}/php8.3" <<'EOF'
#!/usr/bin/env bash
echo "PHP 8.3.99-cli"
EOF
chmod +x "${FAKE_BIN}/php8.3"

cat > "${FAKE_BIN}/php-fpm-8.3" <<'EOF'
#!/usr/bin/env bash
echo "PHP 8.3.99-fpm"
EOF
chmod +x "${FAKE_BIN}/php-fpm-8.3"

set +e
OUT="$(
  env \
    HOME="${HOME_DIR}" \
    PLUME_STATE_DIR="${STATE_DIR}" \
    PLUME_ALLOW_NON_ROOT_INSTALL=true \
    PLUME_PHP_NATIVE_INSTALL_DRIVER=mock \
    PLUME_PHP_SHIM_SEARCH_PATH="${FAKE_BIN}" \
    PLUME_PHP_INSTALLED_VERSIONS="8.3,9.9" \
    PLUME_PHP_DEFAULT_VERSION="8.3" \
    ./plume.sh services up php --mode=native 2>&1
)"
RC=$?
set -e

if [[ "${RC}" -ne 2 ]]; then
  echo "[FAIL] services up php should fail when matrix has missing binary (expected rc=2, got ${RC})" >&2
  printf '%s\n' "${OUT}" >&2
  exit 1
fi

printf '%s\n' "${OUT}" | grep -q 'native php matrix ensure:' || {
  echo "[FAIL] expected matrix ensure log in output" >&2
  printf '%s\n' "${OUT}" >&2
  exit 1
}

printf '%s\n' "${OUT}" | grep -q 'php 9.9 install incomplete' || {
  echo "[FAIL] expected missing binary error for 9.9" >&2
  printf '%s\n' "${OUT}" >&2
  exit 1
}

echo "phase11-services-up-php-native-matrix-required-smoke:ok"
