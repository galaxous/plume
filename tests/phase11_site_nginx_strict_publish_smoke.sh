#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

TMP_ROOT="$(mktemp -d)"
HOME_DIR="${TMP_ROOT}/home"
SITE_REGISTRY="${TMP_ROOT}/registry"
INCLUDE_DIR="${TMP_ROOT}/nginx-include"
FAKE_BIN="${TMP_ROOT}/fake-bin"
PROJECT_DIR="${TMP_ROOT}/project"
LOG_FILE="${TMP_ROOT}/nginx.log"
mkdir -p "${HOME_DIR}" "${SITE_REGISTRY}" "${INCLUDE_DIR}" "${FAKE_BIN}" "${PROJECT_DIR}/public"

cleanup() {
  rm -rf "${TMP_ROOT}"
}
trap cleanup EXIT

cat > "${FAKE_BIN}/nginx" <<EOF
#!/usr/bin/env bash
echo "\$*" >> "${LOG_FILE}"
if [[ "\${1:-}" == "-t" ]]; then
  exit 0
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
  "PLUME_SITE_NGINX_STRICT=true"
  "PLUME_NGINX_INCLUDE_DIR=${INCLUDE_DIR}"
  "PATH=${FAKE_BIN}:${PATH}"
)

SITE_ID="$(env "${BASE_ENV[@]}" ./plume.sh site add --mode=native --path="${PROJECT_DIR}" --domain="strict-publish.test" --server=nginx --publish | tail -n 1)"
[[ -n "${SITE_ID}" ]] || {
  echo "[FAIL] site add should return id" >&2
  exit 1
}

TARGET_CONF="${INCLUDE_DIR}/${SITE_ID}.conf"
[[ -f "${TARGET_CONF}" ]] || {
  echo "[FAIL] expected strict target include file: ${TARGET_CONF}" >&2
  ls -la "${INCLUDE_DIR}" >&2 || true
  exit 1
}

grep -q -- "-t" "${LOG_FILE}" || {
  echo "[FAIL] expected nginx -t in strict publish flow" >&2
  cat "${LOG_FILE}" >&2 || true
  exit 1
}

grep -q -- "-s reload" "${LOG_FILE}" || {
  echo "[FAIL] expected nginx reload in strict publish flow" >&2
  cat "${LOG_FILE}" >&2 || true
  exit 1
}

env "${BASE_ENV[@]}" ./plume.sh site remove --mode=native "${SITE_ID}" >/dev/null
[[ ! -f "${TARGET_CONF}" ]] || {
  echo "[FAIL] strict remove should delete target include file" >&2
  exit 1
}

echo "phase11-site-nginx-strict-publish-smoke:ok"
