#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

TMP_ROOT="$(mktemp -d)"
HOME_DIR="${TMP_ROOT}/home"
SITE_REGISTRY="${TMP_ROOT}/sites"
PROJECT_DIR="${TMP_ROOT}/project"
FAKE_BIN="${TMP_ROOT}/fake-bin"
LOG_FILE="${TMP_ROOT}/nginx.log"
mkdir -p "${HOME_DIR}" "${SITE_REGISTRY}" "${PROJECT_DIR}/public" "${FAKE_BIN}"

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
  "PATH=${FAKE_BIN}:${PATH}"
)

SITE_ID="$(env "${BASE_ENV[@]}" ./plume.sh site add --mode=laradock-bridge --path="${PROJECT_DIR}" --domain="mode-update.test" --server=nginx | tail -n 1)"
[[ -n "${SITE_ID}" ]] || {
  echo "[FAIL] site add should return id" >&2
  exit 1
}

OLD_CACHE_FILE="${HOME_DIR}/.config/plume/laradock-bridge/sites/nginx/${SITE_ID}.conf"
mkdir -p "$(dirname "${OLD_CACHE_FILE}")"
cat > "${OLD_CACHE_FILE}" <<'EOF'
# stale bridge cache
EOF

env "${BASE_ENV[@]}" ./plume.sh site update "${SITE_ID}" --mode=native >/dev/null

CHECK_OUT="$(env "${BASE_ENV[@]}" ./plume.sh site check "${SITE_ID}")"
printf '%s\n' "${CHECK_OUT}" | grep -q '^mode: native$' || {
  echo "[FAIL] expected site mode to change to native" >&2
  printf '%s\n' "${CHECK_OUT}" >&2
  exit 1
}

MODES_OUT="$(env "${BASE_ENV[@]}" ./plume.sh site modes)"
printf '%s\n' "${MODES_OUT}" | awk -v expected="${SITE_ID}" 'NR > 2 && $1 == expected && $2 == "native" { found=1 } END { exit !found }' || {
  echo "[FAIL] site modes should show native mode" >&2
  printf '%s\n' "${MODES_OUT}" >&2
  exit 1
}

[[ ! -f "${OLD_CACHE_FILE}" ]] || {
  echo "[FAIL] old bridge cache conf should be removed after mode update" >&2
  exit 1
}

env "${BASE_ENV[@]}" ./plume.sh site publish "${SITE_ID}" --reload >/dev/null

NEW_CACHE_FILE="${SITE_REGISTRY}/nginx/${SITE_ID}.conf"
[[ -f "${NEW_CACHE_FILE}" ]] || {
  echo "[FAIL] expected native cache conf after publish: ${NEW_CACHE_FILE}" >&2
  exit 1
}

grep -qx -- '-t' "${LOG_FILE}" || {
  echo "[FAIL] expected nginx -t after native publish" >&2
  cat "${LOG_FILE}" >&2 || true
  exit 1
}

grep -qx -- '-s reload' "${LOG_FILE}" || {
  echo "[FAIL] expected nginx reload after native publish" >&2
  cat "${LOG_FILE}" >&2 || true
  exit 1
}

echo "phase11-site-mode-update-smoke:ok"
