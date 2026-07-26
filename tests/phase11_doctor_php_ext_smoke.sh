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

out_non_strict="$(
  env \
    HOME="${HOME_DIR}" \
    PLUME_STATE_DIR="${STATE_DIR}" \
    PLUME_PHP_INSTALLED_VERSIONS="8.4" \
    PLUME_PHP_DEFAULT_VERSION="8.4" \
    PLUME_PHP_SHIM_SEARCH_PATH="${FAKE_BIN}" \
    PLUME_PHP_EXTENSIONS_GLOBAL="redis,imagick" \
    ./plume.sh doctor php-ext
)"

printf '%s\n' "${out_non_strict}" | grep -q '^PHP      EXTENSION  STATUS$' || {
  echo "[FAIL] doctor php-ext table header missing" >&2
  printf '%s\n' "${out_non_strict}" >&2
  exit 1
}

printf '%s\n' "${out_non_strict}" | grep -q '^8.4      imagick    missing$' || {
  echo "[FAIL] doctor php-ext should mark imagick missing" >&2
  printf '%s\n' "${out_non_strict}" >&2
  exit 1
}

set +e
env \
  HOME="${HOME_DIR}" \
  PLUME_STATE_DIR="${STATE_DIR}" \
  PLUME_PHP_INSTALLED_VERSIONS="8.4" \
  PLUME_PHP_DEFAULT_VERSION="8.4" \
  PLUME_PHP_SHIM_SEARCH_PATH="${FAKE_BIN}" \
  PLUME_PHP_EXTENSIONS_GLOBAL="redis,imagick" \
  ./plume.sh doctor php-ext --strict >/dev/null 2>&1
rc=$?
set -e
if [[ "${rc}" -ne 2 ]]; then
  echo "[FAIL] doctor php-ext --strict should fail when extension missing" >&2
  exit 1
fi

echo "phase11-doctor-php-ext-smoke:ok"
