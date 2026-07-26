#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

TMP_ROOT="$(mktemp -d)"
SITE_REGISTRY_DIR="${TMP_ROOT}/plume-sites"
export PLUME_SITE_REGISTRY_DIR="${SITE_REGISTRY_DIR}"
export PLUME_SITE_HOSTS_SYNC="false"

cleanup() {
  rm -rf "${TMP_ROOT}"
}
trap cleanup EXIT

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

assert_fail_code() {
  local expected="$1"
  local name="$2"
  shift 2
  set +e
  "$@"
  local got=$?
  set -e
  if [[ "${got}" -eq "${expected}" ]]; then
    echo "[PASS] ${name}"
  else
    echo "[FAIL] ${name} (expected ${expected}, got ${got})" >&2
    return 1
  fi
}

project_a="${TMP_ROOT}/project-a"
project_b="${TMP_ROOT}/project-b"
mkdir -p "${project_a}/public" "${project_b}/public"

cat > "${project_a}/plume.yml" <<EOF
project:
  mode: docker-lite
EOF

domain_a="mode-a-${RANDOM}.test"
SITE_A="$(./plume.sh site add --path="${project_a}" --domain="${domain_a}" --server=nginx --publish)"
echo "[PASS] site add with manifest mode: ${SITE_A}"

assert_ok "site_a uses manifest mode" bash -lc "[[ -f \"\${HOME}/.config/plume/docker-lite/sites/nginx/${SITE_A}.conf\" ]]"
assert_ok "site_a record has mode" bash -lc "grep -q 'mode: docker-lite' \"${PLUME_SITE_REGISTRY_DIR}/${SITE_A}.yml\""

assert_ok "site_a publish uses recorded mode" bash -lc "./plume.sh site publish ${SITE_A} >/dev/null"
./plume.sh site remove ${SITE_A}
assert_ok "site_a removed" bash -lc "[[ ! -f \"\${HOME}/.config/plume/docker-lite/sites/nginx/${SITE_A}.conf\" ]]"

domain_b="mode-b-${RANDOM}.test"
SITE_B="$(PLUME_MODE=laradock-bridge ./plume.sh site add --path="${project_b}" --domain="${domain_b}" --server=nginx --publish)"
echo "[PASS] site add with env mode: ${SITE_B}"

assert_ok "site_b uses env mode" bash -lc "[[ -f \"\${HOME}/.config/plume/laradock-bridge/sites/nginx/${SITE_B}.conf\" ]]"

./plume.sh site remove --mode=laradock-bridge "${SITE_B}"
assert_ok "site_b removed" bash -lc "[[ ! -f \"\${HOME}/.config/plume/laradock-bridge/sites/nginx/${SITE_B}.conf\" ]]"

cat > "${project_b}/plume.yml" <<EOF
mode: invalid-mode
EOF
assert_fail_code 2 "invalid manifest mode fails" ./plume.sh site add --path="${project_b}" --domain="invalid-${RANDOM}.test" --server=nginx --publish

echo "site-mode-resolution-smoke:ok"
