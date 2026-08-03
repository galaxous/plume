#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

TMP_ROOT="$(mktemp -d)"
HOME_DIR="${TMP_ROOT}/home"
STATE_DIR="${TMP_ROOT}/state"
REG_DIR="${TMP_ROOT}/registry"
PROJECT_DIR="${TMP_ROOT}/project"
mkdir -p "${HOME_DIR}" "${STATE_DIR}" "${REG_DIR}" "${PROJECT_DIR}/public"

cleanup() {
  if [[ -n "${SITE_ID:-}" ]]; then
    env "${BASE_ENV[@]}" ./plume.sh site remove "${SITE_ID}" >/dev/null 2>&1 || true
  fi
  rm -rf "${TMP_ROOT}"
}
trap cleanup EXIT

BASE_ENV=(
  "HOME=${HOME_DIR}"
  "PLUME_STATE_DIR=${STATE_DIR}"
  "PLUME_SITE_REGISTRY_DIR=${REG_DIR}"
  "PLUME_SITE_HOSTS_SYNC=false"
  "PLUME_SKIP_ON_FIRST_RUN_PROVISION=true"
  "PLUME_PHP_INSTALLED_VERSIONS=8.2,8.3"
  "PLUME_PHP_DEFAULT_VERSION=8.3"
)

assert_ok() {
  local name="$1"
  shift
  if "$@"; then
    echo "[PASS] ${name}"
  else
    echo "[FAIL] ${name}" >&2
    return 1
  fi
}

cat > "${PROJECT_DIR}/plume.yml" <<'EOF'
version: 2
project:
  mode: docker-lite
  php_version: "8.2"
  type: laravel
EOF

OUT="$(env "${BASE_ENV[@]}" ./plume.sh project config show --path="${PROJECT_DIR}")"
echo "${OUT}" | grep -qF "manifest=${PROJECT_DIR}/plume.yml" || {
  echo "[FAIL] project config show manifest path" >&2
  printf '%s\n' "${OUT}" >&2
  exit 1
}
echo "${OUT}" | grep -qF 'mode=docker-lite' || {
  echo "[FAIL] project config show mode" >&2
  printf '%s\n' "${OUT}" >&2
  exit 1
}
echo "${OUT}" | grep -qF 'php_version=8.2' || {
  echo "[FAIL] project config show php_version" >&2
  printf '%s\n' "${OUT}" >&2
  exit 1
}
echo "${OUT}" | grep -qF 'project_type=laravel' || {
  echo "[FAIL] project config show project_type" >&2
  printf '%s\n' "${OUT}" >&2
  exit 1
}
echo "[PASS] project config show reads v2 fields"

PRECEDENCE_DIR="${TMP_ROOT}/precedence"
mkdir -p "${PRECEDENCE_DIR}/public"
cat > "${PRECEDENCE_DIR}/plume.yml" <<'EOF'
mode: native
project:
  mode: docker-lite
EOF
PREC_OUT="$(env "${BASE_ENV[@]}" ./plume.sh project config show --path="${PRECEDENCE_DIR}")"
echo "${PREC_OUT}" | grep -qF 'mode=docker-lite' || {
  echo "[FAIL] project.mode should win over root mode" >&2
  printf '%s\n' "${PREC_OUT}" >&2
  exit 1
}
echo "[PASS] project.mode precedence over legacy root mode"

domain="phase16-${RANDOM}.test"
PLAN="$(env "${BASE_ENV[@]}" ./plume.sh site add --path="${PROJECT_DIR}" --domain="${domain}" --server=nginx --dry-run 2>&1)"
echo "${PLAN}" | grep -q 'php_version=8.2' || echo "${PLAN}" | grep -q '8.2' || {
  echo "[FAIL] site add dry-run should reflect manifest php_version 8.2" >&2
  printf '%s\n' "${PLAN}" >&2
  exit 1
}
echo "[PASS] site add uses manifest php_version hint"

domain_live="phase16-live-${RANDOM}.test"
SITE_ID="$(env "${BASE_ENV[@]}" ./plume.sh site add --path="${PROJECT_DIR}" --domain="${domain_live}" --server=nginx --publish)"
assert_ok "registry records manifest mode" bash -lc "grep -q 'mode: docker-lite' '${REG_DIR}/${SITE_ID}.yml'"
assert_ok "registry records manifest php" bash -lc "grep -q 'php_version: 8.2' '${REG_DIR}/${SITE_ID}.yml'"
assert_ok "docker-lite snippet path under hermetic HOME" bash -lc "[[ -f '${HOME_DIR}/.config/plume/docker-lite/sites/nginx/${SITE_ID}.conf' ]]"

echo "phase16-plume-yml-v2-smoke:ok"
