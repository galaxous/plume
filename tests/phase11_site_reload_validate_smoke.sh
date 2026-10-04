#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

TMP_ROOT="$(mktemp -d)"
HOME_DIR="${TMP_ROOT}/home"
SITE_REGISTRY="${TMP_ROOT}/registry"
FAKE_BIN="${TMP_ROOT}/fake-bin"
PROJECT_DIR="${TMP_ROOT}/project"
LOG_FILE="${TMP_ROOT}/nginx.log"
mkdir -p "${HOME_DIR}" "${SITE_REGISTRY}" "${FAKE_BIN}" "${PROJECT_DIR}/public"
mkdir -p "${HOME_DIR}/.config/plume"
: > "${HOME_DIR}/.config/plume/.env"

cleanup() {
  rm -rf "${TMP_ROOT}"
}
trap cleanup EXIT

cat > "${FAKE_BIN}/nginx" <<EOF
#!/usr/bin/env bash
echo "\$*" >> "${LOG_FILE}"
if [[ "\${1:-}" == "-t" ]]; then
  exit 1
fi
if [[ "\${1:-}" == "-s" && "\${2:-}" == "reload" ]]; then
  exit 0
fi
exit 0
EOF
chmod +x "${FAKE_BIN}/nginx"

BASE_ENV=(
  "HOME=${HOME_DIR}"
  "PLUME_SITE_REGISTRY_DIR=${SITE_REGISTRY}"
  "PLUME_SITE_HOSTS_SYNC=false"
  "PLUME_SITE_NGINX_STRICT=false"
  "PLUME_SITE_NGINX_STRICT_ON_RELOAD=false"
  # Hermetic: do not touch host brew nginx / sudo (D-151 ensure) — D-157.
  "PLUME_NATIVE_NGINX_ENSURE_ON_PUBLISH=false"
  "PLUME_NATIVE_NGINX_MANAGE_MAIN_CONFIG=false"
  "PLUME_SITE_AUTO_PROVISION_WEB=false"
  "PLUME_SITE_RELOAD_REQUIRED=true"
  "PLUME_SITE_RELOAD_VALIDATE=true"
  "PLUME_NONINTERACTIVE=1"
  "PLUME_NATIVE_NGINX_FORCE_UNPRIVILEGED_RELOAD=true"
  # Prefer fake nginx only; do not prepend real Homebrew PATH (phase12).
  "PATH=${FAKE_BIN}:/usr/bin:/bin"
)

SITE_ID="$(env "${BASE_ENV[@]}" ./plume.sh site add --mode=native --path="${PROJECT_DIR}" --domain="reload-validate.test" --server=nginx --publish | tail -n 1)"
[[ -n "${SITE_ID}" ]] || {
  echo "[FAIL] site add should return id" >&2
  exit 1
}

# Only assert nginx invocations from the --reload publish under test.
: > "${LOG_FILE}"

set +e
env "${BASE_ENV[@]}" ./plume.sh site publish --mode=native "${SITE_ID}" --reload >/tmp/plume-phase11-site-reload-validate.out 2>&1
rc=$?
set -e

if [[ ${rc} -ne 2 ]]; then
  echo "[FAIL] expected publish reload to fail with exit 2 when config test fails, got ${rc}" >&2
  cat /tmp/plume-phase11-site-reload-validate.out >&2 || true
  exit 1
fi

grep -q "nginx config test failed; reload skipped" /tmp/plume-phase11-site-reload-validate.out || {
  echo "[FAIL] expected config test failure warning in output" >&2
  cat /tmp/plume-phase11-site-reload-validate.out >&2 || true
  exit 1
}

grep -qx -- "-t" "${LOG_FILE}" || {
  echo "[FAIL] expected nginx -t to be called" >&2
  cat "${LOG_FILE}" >&2 || true
  exit 1
}

if grep -q -- "-s reload" "${LOG_FILE}"; then
  echo "[FAIL] nginx reload should not run when config test fails" >&2
  cat "${LOG_FILE}" >&2 || true
  exit 1
fi

echo "phase11-site-reload-validate-smoke:ok"
