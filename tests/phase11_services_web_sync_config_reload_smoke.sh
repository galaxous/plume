#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

# Regression: reload must call plume_sites_reload_native (bootstrap loads sites.sh before native_web_nginx_config.sh).
if ! grep -q 'plume_sites_reload_native nginx' "${ROOT_DIR}/lib/services/native_web_nginx_config.sh"; then
  echo "[FAIL] native_web_nginx_config must invoke plume_sites_reload_native nginx" >&2
  exit 1
fi
if grep -q 'plume_sites_reload_native_server' "${ROOT_DIR}/lib/services/native_web_nginx_config.sh"; then
  echo "[FAIL] stale plume_sites_reload_native_server reference" >&2
  exit 1
fi

TMP_ROOT="$(mktemp -d)"
NGINX_ETC="${TMP_ROOT}/nginx"
FAKE_BIN="${TMP_ROOT}/fake-bin"
mkdir -p "${NGINX_ETC}/servers" "${FAKE_BIN}"

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
if [[ "${1:-}" == "-s" && "${2:-}" == "reload" ]]; then
  exit 0
fi
exit 0
EOF
chmod +x "${FAKE_BIN}/nginx"

# Prevent real brew/systemctl from running during reload in this smoke.
cat > "${FAKE_BIN}/brew" <<'EOF'
#!/usr/bin/env bash
exit 1
EOF
chmod +x "${FAKE_BIN}/brew"

BASE_ENV=(
  "PLUME_NATIVE_NGINX_MAIN_CONF=${NGINX_ETC}/nginx.conf"
  "PLUME_NATIVE_NGINX_MANAGE_MAIN_CONFIG=true"
  "PLUME_NATIVE_NGINX_HTTP_PORT=8080"
  "PLUME_WEB_SERVER_DRIVER=nginx"
  "PATH=${FAKE_BIN}:${PATH}"
  "PLUME_SITE_RELOAD_VALIDATE=false"
)

set +e
env "${BASE_ENV[@]}" ./plume.sh services web sync-config --port=8080 --reload >/tmp/plume-reload-smoke.out 2>&1
rc=$?
set -e

if [[ "${rc}" -ne 0 ]]; then
  echo "[FAIL] sync-config --reload on matching port should succeed (rc=${rc})" >&2
  cat /tmp/plume-reload-smoke.out >&2
  exit 1
fi
if grep -q 'nginx reload helper unavailable' /tmp/plume-reload-smoke.out; then
  echo "[FAIL] must not emit stale reload helper error" >&2
  cat /tmp/plume-reload-smoke.out >&2
  exit 1
fi

echo "phase11-services-web-sync-config-reload-smoke:ok"
