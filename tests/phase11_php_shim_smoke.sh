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
  "PLUME_PHP_INSTALLED_VERSIONS=8.4"
  "PLUME_PHP_DEFAULT_VERSION=8.4"
  "PLUME_PHP_SHIM_SEARCH_PATH=${FAKE_BIN}"
)

assert_ok() {
  local name="$1"
  shift
  if "$@" >/dev/null 2>&1; then
    echo "[PASS] ${name}"
  else
    echo "[FAIL] ${name}" >&2
    return 1
  fi
}

assert_ok "php shim install" env "${BASE_ENV[@]}" ./plume.sh php shim install

SHIM_DIR="${HOME_DIR}/.config/plume/shims"
assert_ok "php8.4 shim exists" test -x "${SHIM_DIR}/php8.4"
assert_ok "php-fpm-8.4 shim exists" test -x "${SHIM_DIR}/php-fpm-8.4"

assert_ok "php8.4 shim executes targeted cli binary" \
  bash -lc "env HOME='${HOME_DIR}' PLUME_STATE_DIR='${STATE_DIR}' PLUME_PHP_SHIM_SEARCH_PATH='${FAKE_BIN}' PATH='${SHIM_DIR}:'\"\$PATH\" php8.4 -v | grep -q 'PHP 8.4.99-cli'"

assert_ok "php-fpm-8.4 shim executes targeted fpm binary" \
  bash -lc "env HOME='${HOME_DIR}' PLUME_STATE_DIR='${STATE_DIR}' PLUME_PHP_SHIM_SEARCH_PATH='${FAKE_BIN}' PATH='${SHIM_DIR}:'\"\$PATH\" php-fpm-8.4 -v | grep -q 'PHP 8.4.99-fpm'"

echo "phase11-php-shim-smoke:ok"
