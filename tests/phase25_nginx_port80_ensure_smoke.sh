#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

TMP_ROOT="$(mktemp -d)"
HOME_DIR="${TMP_ROOT}/home"
STATE_DIR="${TMP_ROOT}/state"
MOCK_BIN="${TMP_ROOT}/bin"
NGINX_ETC="${TMP_ROOT}/nginx"
mkdir -p "${HOME_DIR}/.config/plume" "${STATE_DIR}" "${MOCK_BIN}" "${NGINX_ETC}/servers"
: > "${HOME_DIR}/.config/plume/.env"

cat > "${NGINX_ETC}/nginx.conf" <<'EOF'
http {
    include servers/*;
    server {
        listen 8080;
        server_name localhost;
        root /tmp;
    }
}
EOF

cleanup() { rm -rf "${TMP_ROOT}"; }
trap cleanup EXIT

cat > "${MOCK_BIN}/nginx" <<'EOF'
#!/usr/bin/env bash
if [[ "${1:-}" == "-t" ]]; then
  echo "nginx: configuration file test is successful"
  exit 0
fi
exit 0
EOF
chmod +x "${MOCK_BIN}/nginx"

cat > "${MOCK_BIN}/brew" <<'EOF'
#!/usr/bin/env bash
case "${1:-}" in
  --prefix) echo "/mock" ;;
  services) exit 0 ;;
esac
exit 0
EOF
chmod +x "${MOCK_BIN}/brew"

BASE_ENV=(
  "HOME=${HOME_DIR}"
  "PLUME_STATE_DIR=${STATE_DIR}"
  "PATH=${MOCK_BIN}:/usr/bin:/bin"
  "PLUME_NATIVE_HOST_INSTALL_DRIVER=mock"
  "PLUME_ALLOW_NON_ROOT_INSTALL=true"
  "PLUME_SKIP_ON_FIRST_RUN_PROVISION=true"
  "PLUME_PHP_EXTENSIONS_AUTO_SYNC=false"
  "PLUME_GLOBAL_ENV_FILE=${HOME_DIR}/.config/plume/.env"
  "PLUME_ENV_FILE=${HOME_DIR}/.config/plume/.env"
  "PLUME_NATIVE_NGINX_MAIN_CONF=${NGINX_ETC}/nginx.conf"
  "PLUME_NATIVE_NGINX_MANAGE_MAIN_CONFIG=true"
  "PLUME_NATIVE_NGINX_HTTP_PORT=80"
  "PLUME_NONINTERACTIVE=1"
)

env "${BASE_ENV[@]}" ./plume.sh mode use native --force --yes >/dev/null

DRY="$(env "${BASE_ENV[@]}" ./plume.sh services web ensure --dry-run 2>&1)"
echo "${DRY}" | grep -q 'target_listen: 80' || {
  echo "[FAIL] ensure dry-run should target 80" >&2
  printf '%s\n' "${DRY}" >&2
  exit 1
}
echo "[PASS] ensure dry-run targets 80"

env "${BASE_ENV[@]}" ./plume.sh services web ensure --no-republish >/dev/null
grep -q 'listen 80;' "${NGINX_ETC}/nginx.conf" || {
  echo "[FAIL] main conf should listen 80 after ensure" >&2
  cat "${NGINX_ETC}/nginx.conf" >&2
  exit 1
}
grep -q 'listen 8080;' "${NGINX_ETC}/nginx.conf" && {
  echo "[FAIL] 8080 should be replaced" >&2
  exit 1
}
echo "[PASS] ensure patches main conf to 80"

echo "phase25-nginx-port80-ensure-smoke:ok"
