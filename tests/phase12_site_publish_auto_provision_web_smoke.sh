#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

TMP_ROOT="$(mktemp -d)"
HOME_DIR="${TMP_ROOT}/home"
STATE_DIR="${TMP_ROOT}/state"
SITE_REGISTRY="${TMP_ROOT}/sites"
MOCK_BIN="${TMP_ROOT}/bin"
MOCK_LOG="${TMP_ROOT}/brew.log"
NGINX_ROOT="${MOCK_BIN}/nginx"
NGINX_SERVERS="${TMP_ROOT}/nginx/servers"
# Keep Homebrew/nginx off PATH so ensure-web uses mock brew (not host nginx).
SMOKE_PATH="${MOCK_BIN}:/usr/bin:/bin:/usr/sbin:/sbin"
mkdir -p "${HOME_DIR}" "${STATE_DIR}" "${SITE_REGISTRY}" "${MOCK_BIN}" "${NGINX_SERVERS}"

cat > "${MOCK_BIN}/brew" <<EOF
#!/usr/bin/env bash
echo "brew \$*" >> "${MOCK_LOG}"
case "\$1" in
  list) exit 1 ;;
  --prefix)
    if [[ "\${2:-}" == "nginx" && -x "${NGINX_ROOT}/bin/nginx" ]]; then
      echo "${NGINX_ROOT}"
      exit 0
    fi
    exit 1
    ;;
  install)
    if [[ "\${2:-}" == "nginx" ]]; then
      mkdir -p "${NGINX_ROOT}/bin"
      cat > "${NGINX_ROOT}/bin/nginx" <<'NGX'
#!/usr/bin/env bash
case "\$1" in -t|-s) exit 0;; esac; exit 0
NGX
      chmod +x "${NGINX_ROOT}/bin/nginx"
    fi
    exit 0
    ;;
  services) exit 0 ;;
  *) exit 0 ;;
esac
EOF
chmod +x "${MOCK_BIN}/brew"

cleanup() {
  rm -rf "${TMP_ROOT}"
}
trap cleanup EXIT

PROJECT="${TMP_ROOT}/project/public"
mkdir -p "${PROJECT}"
echo ok > "${PROJECT}/index.html"

BASE_ENV=(
  "HOME=${HOME_DIR}"
  "PLUME_STATE_DIR=${STATE_DIR}"
  "PLUME_SITE_REGISTRY_DIR=${SITE_REGISTRY}"
  "PATH=${SMOKE_PATH}"
  "PLUME_NGINX_INCLUDE_DIR=${NGINX_SERVERS}"
  "PLUME_SITE_AUTO_PROVISION_WEB=true"
  "PLUME_ALLOW_NON_ROOT_INSTALL=true"
  "PLUME_SITE_RELOAD_VALIDATE=false"
  "PLUME_NONINTERACTIVE=1"
  "PLUME_NATIVE_NGINX_ENSURE_ON_PUBLISH=false"
  "PLUME_NATIVE_NGINX_FORCE_UNPRIVILEGED_RELOAD=true"
)

env "${BASE_ENV[@]}" ./plume.sh mode use native --force --yes >/dev/null
site_id="$(env "${BASE_ENV[@]}" ./plume.sh site add --path="${TMP_ROOT}/project" --domain=auto.test --server=nginx --publish 2>/dev/null | tail -n 1)"

if [[ -z "${site_id}" ]]; then
  echo "[FAIL] site add did not return id" >&2
  exit 1
fi

if ! env "${BASE_ENV[@]}" ./plume.sh site publish "${site_id}" --reload >/dev/null 2>&1; then
  echo "[FAIL] site publish --reload should succeed after auto-provision" >&2
  cat "${MOCK_LOG}" >&2
  exit 1
fi

if ! grep -q 'brew install nginx' "${MOCK_LOG}"; then
  echo "[FAIL] expected mock brew install nginx during reload ensure" >&2
  cat "${MOCK_LOG}" >&2
  exit 1
fi

echo "phase12-site-publish-auto-provision-web-smoke:ok"
