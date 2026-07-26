#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

TMP_ROOT="$(mktemp -d)"
WWW_CONF="${TMP_ROOT}/php-fpm.d/www.conf"
CANONICAL="${TMP_ROOT}/run/php@8.2-fpm.sock"

cleanup() {
  rm -rf "${TMP_ROOT}"
}
trap cleanup EXIT

mkdir -p "$(dirname "${WWW_CONF}")"
cat > "${WWW_CONF}" <<'EOF'
[www]
user = _www
group = _www
listen = 127.0.0.1:9000
listen.owner = oguzhan
listen.group = admin
EOF

# shellcheck source=lib/bootstrap.sh
source "${ROOT_DIR}/lib/bootstrap.sh"

export PLUME_PHP_NATIVE_INSTALL_DRIVER=brew
export PLUME_PHP_FPM_WWW_CONF="${WWW_CONF}"
export PLUME_PHP_FPM_ENSURE_LISTEN_SOCKET="${CANONICAL}"

plume_native_php_ensure_fpm_listen "8.2" || {
  echo "[FAIL] ensure_fpm_listen should succeed" >&2
  exit 1
}

grep -q "listen = ${CANONICAL}" "${WWW_CONF}" || {
  echo "[FAIL] www.conf listen not updated to canonical socket" >&2
  cat "${WWW_CONF}" >&2
  exit 1
}

[[ -f "${WWW_CONF}.plume-bak" ]] || {
  echo "[FAIL] expected www.conf.plume-bak backup" >&2
  exit 1
}

plume_native_php_ensure_fpm_listen "8.2" || {
  echo "[FAIL] second ensure should no-op" >&2
  exit 1
}

echo "phase11-native-php-ensure-fpm-listen-smoke:ok"
