#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

TMP_ROOT="$(mktemp -d)"
HOME_DIR="${TMP_ROOT}/home"
STATE_DIR="${TMP_ROOT}/state"
SITE_REGISTRY="${TMP_ROOT}/sites"
INCLUDE_DIR="${TMP_ROOT}/nginx-servers"
FAKE_BIN="${TMP_ROOT}/fake-bin"
mkdir -p "${HOME_DIR}" "${STATE_DIR}" "${SITE_REGISTRY}/nginx" "${INCLUDE_DIR}" "${FAKE_BIN}"

cleanup() {
  rm -rf "${TMP_ROOT}"
}
trap cleanup EXIT

SITE_ID="site-doctor-web-test"
PROJECT_DIR="${TMP_ROOT}/project"
mkdir -p "${PROJECT_DIR}/public"

cat > "${SITE_REGISTRY}/${SITE_ID}.yml" <<EOF
id: ${SITE_ID}
mode: native
path: ${PROJECT_DIR}
server: nginx
port: 80
status: published
domains:
  - myapp.test
EOF
printf '%s\n' "sites:" > "${SITE_REGISTRY}/index.yml"
printf '  - %s\n' "${SITE_ID}" >> "${SITE_REGISTRY}/index.yml"

cat > "${SITE_REGISTRY}/nginx/${SITE_ID}.conf" <<'EOF'
server {
  listen 8080;
  server_name myapp.test;
}
EOF
cp "${SITE_REGISTRY}/nginx/${SITE_ID}.conf" "${INCLUDE_DIR}/${SITE_ID}.conf"

cat > "${FAKE_BIN}/nginx" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "${FAKE_BIN}/nginx"

cat > "${FAKE_BIN}/brew" <<'EOF'
#!/usr/bin/env bash
if [[ "${1:-}" == "services" && "${2:-}" == "list" ]]; then
  echo "nginx started"
  exit 0
fi
exit 0
EOF
chmod +x "${FAKE_BIN}/brew"

cat > "${FAKE_BIN}/lsof" <<'EOF'
#!/usr/bin/env bash
port=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    -iTCP:*)
      port="${1#-iTCP:}"
      port="${port%%(*}"
      ;;
  esac
  shift
done
if [[ "${port}" == "8080" || "${port}" == "443" ]]; then
  echo "COMMAND PID USER FD TYPE DEVICE SIZE/OFF NODE NAME"
  echo "nginx 123 user 6u IPv4 0t0 TCP *:${port} (LISTEN)"
  exit 0
fi
exit 1
EOF
chmod +x "${FAKE_BIN}/lsof"

BASE_ENV=(
  "HOME=${HOME_DIR}"
  "PLUME_STATE_DIR=${STATE_DIR}"
  "PLUME_SITE_REGISTRY_DIR=${SITE_REGISTRY}"
  "PLUME_WEB_SERVER_ENABLED=true"
  "PLUME_WEB_SERVER_DRIVER=nginx"
  "PLUME_NGINX_INCLUDE_DIR=${INCLUDE_DIR}"
  "PLUME_NATIVE_HOMEBREW_HTTP_PORT=8080"
  "PATH=${FAKE_BIN}:${PATH}"
)

out="$(env "${BASE_ENV[@]}" ./plume.sh doctor web --mode=native || true)"
printf '%s\n' "${out}" | grep -q '^DRIVER            nginx$' || {
  echo "[FAIL] doctor web should print driver" >&2
  printf '%s\n' "${out}" >&2
  exit 1
}

printf '%s\n' "${out}" | grep -q '^listener-effective.*PASS.*8080' || {
  echo "[FAIL] doctor web should PASS listener-effective on 8080" >&2
  printf '%s\n' "${out}" >&2
  exit 1
}

printf '%s\n' "${out}" | grep -q '^listener-80.*WARN' || {
  echo "[FAIL] doctor web should WARN when port 80 not listening" >&2
  printf '%s\n' "${out}" >&2
  exit 1
}

printf '%s\n' "${out}" | grep -q '^strict-includes.*PASS' || {
  echo "[FAIL] doctor web should PASS strict-includes when target matches cache" >&2
  printf '%s\n' "${out}" >&2
  exit 1
}

printf '%s\n' "${out}" | grep -q '^OVERALL               OK$' || {
  echo "[FAIL] doctor web should be OK when critical checks pass (non-strict)" >&2
  printf '%s\n' "${out}" >&2
  exit 1
}

rm -f "${INCLUDE_DIR}/${SITE_ID}.conf"
out_fail="$(env "${BASE_ENV[@]}" ./plume.sh doctor web --mode=native --strict || true)"
printf '%s\n' "${out_fail}" | grep -q '^strict-includes.*FAIL' || {
  echo "[FAIL] doctor web --strict should FAIL strict-includes when target missing" >&2
  printf '%s\n' "${out_fail}" >&2
  exit 1
}

set +e
env "${BASE_ENV[@]}" ./plume.sh doctor web --mode=native --strict >/dev/null 2>&1
rc=$?
set -e
if [[ "${rc}" -ne 2 ]]; then
  echo "[FAIL] doctor web --strict should exit 2 on critical failure" >&2
  exit 1
fi

echo "phase11-doctor-web-smoke:ok"
