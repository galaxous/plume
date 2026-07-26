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

SITE_ID="$(env "${BASE_ENV[@]}" ./plume.sh site add --mode=native --path="${PROJECT_DIR}" --domain="strict-nodouble.test" --server=nginx | tail -n 1)"
[[ -n "${SITE_ID}" ]] || {
  echo "[FAIL] site add should return id" >&2
  exit 1
}

env "${BASE_ENV[@]}" ./plume.sh site publish --mode=native "${SITE_ID}" --reload >/tmp/plume-phase11-nginx-nodouble.out

reload_count="$(grep -c -- "^-s reload$" "${LOG_FILE}" || true)"
if [[ "${reload_count}" != "1" ]]; then
  echo "[FAIL] strict publish --reload should trigger exactly one nginx reload, got ${reload_count}" >&2
  cat "${LOG_FILE}" >&2 || true
  exit 1
fi

grep -q "site reload skipped: already reloaded in strict publish pipeline" /tmp/plume-phase11-nginx-nodouble.out || {
  echo "[FAIL] expected skip message for second reload" >&2
  cat /tmp/plume-phase11-nginx-nodouble.out >&2 || true
  exit 1
}

echo "phase11-site-nginx-strict-no-double-reload-smoke:ok"
