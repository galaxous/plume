#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

TMP_ROOT="$(mktemp -d)"
HOME_DIR="${TMP_ROOT}/home"
NGINX_ETC="${TMP_ROOT}/nginx"
FAKE_BIN="${TMP_ROOT}/fake-bin"
mkdir -p "${HOME_DIR}/.config/plume" "${NGINX_ETC}/servers" "${FAKE_BIN}"
: > "${HOME_DIR}/.config/plume/.env"

cleanup() {
  rm -rf "${TMP_ROOT}"
}
trap cleanup EXIT

cat > "${NGINX_ETC}/nginx.conf" <<'EOF'
worker_processes 1;
events { worker_connections 1024; }
http {
  server {
    listen 8080;
    server_name localhost;
  }
  include servers/*;
}
EOF

cat > "${FAKE_BIN}/nginx" <<'EOF'
#!/usr/bin/env bash
if [[ "${1:-}" == "-t" ]]; then
  exit 0
fi
exit 0
EOF
chmod +x "${FAKE_BIN}/nginx"

BASE_ENV=(
  "HOME=${HOME_DIR}"
  "PLUME_SKIP_ON_FIRST_RUN_PROVISION=true"
  "PLUME_NATIVE_NGINX_MAIN_CONF=${NGINX_ETC}/nginx.conf"
  "PLUME_NATIVE_NGINX_MANAGE_MAIN_CONFIG=true"
  "PLUME_NATIVE_NGINX_HTTP_PORT=80"
  "PLUME_WEB_SERVER_DRIVER=nginx"
  "PATH=${FAKE_BIN}:${PATH}"
)

set +e
env \
  -u PLUME_SERVICES_MANIFEST_FILE \
  "HOME=${HOME_DIR}" \
  "PLUME_SKIP_ON_FIRST_RUN_PROVISION=true" \
  "PLUME_NATIVE_NGINX_MAIN_CONF=${NGINX_ETC}/nginx.conf" \
  "PLUME_NATIVE_NGINX_MANAGE_MAIN_CONFIG=false" \
  "PLUME_WEB_SERVER_DRIVER=nginx" \
  "PATH=${FAKE_BIN}:${PATH}" \
  ./plume.sh services web sync-config >/dev/null 2>&1
rc_blocked=$?
set -e
if [[ "${rc_blocked}" -eq 0 ]]; then
  echo "[FAIL] sync-config should fail when PLUME_NATIVE_NGINX_MANAGE_MAIN_CONFIG=false" >&2
  exit 1
fi

DRY_OUT="$(env "${BASE_ENV[@]}" ./plume.sh services web sync-config --dry-run 2>&1)" || true
echo "${DRY_OUT}" | grep -q '^target_listen: 80$' || {
  echo "[FAIL] dry-run should show target 80" >&2
  echo "${DRY_OUT}" >&2
  exit 1
}

DOCTOR_DRY="$(env "${BASE_ENV[@]}" ./plume.sh doctor web fix-ports --dry-run 2>&1)" || true
echo "${DOCTOR_DRY}" | grep -q '^target_listen: 80$' || {
  echo "[FAIL] doctor web fix-ports dry-run before patch" >&2
  echo "${DOCTOR_DRY}" >&2
  exit 1
}

env "${BASE_ENV[@]}" ./plume.sh services web sync-config || {
  echo "[FAIL] sync-config should patch listen 8080 -> 80" >&2
  exit 1
}

grep -q 'listen 80;' "${NGINX_ETC}/nginx.conf" || {
  echo "[FAIL] nginx.conf should contain listen 80" >&2
  cat "${NGINX_ETC}/nginx.conf" >&2
  exit 1
}

grep -q 'listen 8080;' "${NGINX_ETC}/nginx.conf" && {
  echo "[FAIL] nginx.conf should not contain listen 8080" >&2
  exit 1
}

shopt -s nullglob
backups=("${NGINX_ETC}"/nginx.conf.plume-backup-*)
shopt -u nullglob
if [[ ${#backups[@]} -eq 0 ]]; then
  echo "[FAIL] expected plume backup file" >&2
  exit 1
fi

echo "phase11-services-web-sync-config-smoke:ok"
