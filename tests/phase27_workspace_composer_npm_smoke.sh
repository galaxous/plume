#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

TMP_ROOT="$(mktemp -d)"
HOME_DIR="${TMP_ROOT}/home"
STATE_DIR="${TMP_ROOT}/state"
MOCK_BIN="${TMP_ROOT}/bin"
PROJECT="${TMP_ROOT}/app"
mkdir -p "${HOME_DIR}/.config/plume/sites" "${STATE_DIR}" "${MOCK_BIN}" "${PROJECT}"
: > "${HOME_DIR}/.config/plume/.env"
printf '{"name":"smoke"}\n' > "${PROJECT}/composer.json"
printf '{"name":"smoke"}\n' > "${PROJECT}/package.json"
printf '#!/usr/bin/env php\n<?php\n' > "${PROJECT}/artisan"

cleanup() { rm -rf "${TMP_ROOT}"; }
trap cleanup EXIT

cat > "${MOCK_BIN}/composer" <<'EOF'
#!/usr/bin/env bash
echo "Composer mock $*"
# Prove PHP from PATH is our mock when COMPOSER_PHP or first php is used
if command -v php >/dev/null 2>&1; then
  php -r 'echo "php-ok\n";'
fi
exit 0
EOF
chmod +x "${MOCK_BIN}/composer"

cat > "${MOCK_BIN}/npm" <<'EOF'
#!/usr/bin/env bash
echo "npm mock $*"
exit 0
EOF
chmod +x "${MOCK_BIN}/npm"

cat > "${MOCK_BIN}/node" <<'EOF'
#!/usr/bin/env bash
echo "node mock $*"
exit 0
EOF
chmod +x "${MOCK_BIN}/node"

cat > "${MOCK_BIN}/php" <<'EOF'
#!/usr/bin/env bash
if [[ "${1:-}" == "-r" ]]; then
  echo "php-ok"
  exit 0
fi
exit 0
EOF
chmod +x "${MOCK_BIN}/php"

SITE_ID="site-ws-smoke"
cat > "${HOME_DIR}/.config/plume/sites/index.yml" <<EOF
sites:
  - ${SITE_ID}
EOF
cat > "${HOME_DIR}/.config/plume/sites/${SITE_ID}.yml" <<EOF
id: ${SITE_ID}
mode: native
path: ${PROJECT}
server: nginx
port: 80
document_root: public
php_version: 8.3
horizon: false
status: active
created_at: 1
domains:
  - ${SITE_ID}.test
EOF

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
  "PLUME_PHP_BIN=${MOCK_BIN}/php"
  "PLUME_COMPOSER_BIN=${MOCK_BIN}/composer"
  "PLUME_NPM_BIN=${MOCK_BIN}/npm"
  "PLUME_NODE_BIN=${MOCK_BIN}/node"
)

env "${BASE_ENV[@]}" ./plume.sh mode use native --force --yes >/dev/null

OUT="$(env "${BASE_ENV[@]}" ./plume.sh composer --path="${PROJECT}" install --no-interaction 2>&1)" || {
  echo "[FAIL] composer --path failed" >&2
  printf '%s\n' "${OUT}" >&2
  exit 1
}
echo "${OUT}" | grep -q 'Composer mock install' || {
  echo "[FAIL] composer should invoke mock with install" >&2
  printf '%s\n' "${OUT}" >&2
  exit 1
}
echo "[PASS] composer --path="

OUT="$(env "${BASE_ENV[@]}" ./plume.sh composer --site="${SITE_ID}" -V 2>&1)" || {
  echo "[FAIL] composer --site failed" >&2
  printf '%s\n' "${OUT}" >&2
  exit 1
}
echo "${OUT}" | grep -q 'Composer mock -V' || {
  echo "[FAIL] composer --site should pass -V" >&2
  printf '%s\n' "${OUT}" >&2
  exit 1
}
echo "[PASS] composer --site="

OUT="$(env "${BASE_ENV[@]}" ./plume.sh npm --path="${PROJECT}" run build 2>&1)" || {
  echo "[FAIL] npm failed" >&2
  printf '%s\n' "${OUT}" >&2
  exit 1
}
echo "${OUT}" | grep -q 'npm mock run build' || {
  echo "[FAIL] npm should invoke mock run build" >&2
  printf '%s\n' "${OUT}" >&2
  exit 1
}
echo "[PASS] npm --path="

OUT="$(env "${BASE_ENV[@]}" ./plume.sh node --path="${PROJECT}" -- -p '1+1' 2>&1)" || {
  echo "[FAIL] node failed" >&2
  printf '%s\n' "${OUT}" >&2
  exit 1
}
echo "${OUT}" | grep -q 'node mock -p' || {
  echo "[FAIL] node should invoke mock -p" >&2
  printf '%s\n' "${OUT}" >&2
  exit 1
}
echo "[PASS] node --path="

EMPTY_DIR="${TMP_ROOT}/empty"
mkdir -p "${EMPTY_DIR}"
FAIL_OUT="$(cd "${EMPTY_DIR}" && env "${BASE_ENV[@]}" "${ROOT_DIR}/plume.sh" npm install 2>&1)" && {
  echo "[FAIL] npm in empty cwd should exit non-zero" >&2
  printf '%s\n' "${FAIL_OUT}" >&2
  exit 1
} || true
echo "${FAIL_OUT}" | grep -qi 'could not resolve project path' || {
  echo "[FAIL] npm empty cwd should report resolve error" >&2
  printf '%s\n' "${FAIL_OUT}" >&2
  exit 1
}
echo "[PASS] npm rejects cwd without package.json"

OUT="$(cd "${EMPTY_DIR}" && env "${BASE_ENV[@]}" "${ROOT_DIR}/plume.sh" npm --site="${SITE_ID}" install 2>&1)" || {
  echo "[FAIL] npm --site from empty cwd failed" >&2
  printf '%s\n' "${OUT}" >&2
  exit 1
}
echo "${OUT}" | grep -q "path=${PROJECT}" || {
  echo "[FAIL] npm --site should use site project path" >&2
  printf '%s\n' "${OUT}" >&2
  exit 1
}
echo "[PASS] npm --site= from non-project cwd"

DOC_OUT="$(env "${BASE_ENV[@]}" ./plume.sh doctor workspace 2>&1)" || {
  echo "[FAIL] doctor workspace failed" >&2
  printf '%s\n' "${DOC_OUT}" >&2
  exit 1
}
echo "${DOC_OUT}" | grep -q 'OVERALL.*OK' || {
  echo "[FAIL] doctor workspace overall" >&2
  printf '%s\n' "${DOC_OUT}" >&2
  exit 1
}
echo "${DOC_OUT}" | grep -q 'composer.*PASS' || {
  echo "[FAIL] doctor workspace should PASS composer" >&2
  printf '%s\n' "${DOC_OUT}" >&2
  exit 1
}
echo "[PASS] doctor workspace"

echo "phase27-workspace-composer-npm-smoke:ok"
