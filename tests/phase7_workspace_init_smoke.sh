#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

TMP_ROOT="$(mktemp -d)"
TARGET="${TMP_ROOT}/project"
mkdir -p "${TARGET}"

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
  "$@" >/tmp/plume-phase7-workspace-init.out 2>&1
  local got=$?
  set -e
  if [[ "${got}" -eq "${expected}" ]]; then
    echo "[PASS] ${name}"
  else
    echo "[FAIL] ${name} (expected ${expected}, got ${got})" >&2
    cat /tmp/plume-phase7-workspace-init.out >&2
    return 1
  fi
}

assert_ok "workspace init creates stub files" ./plume.sh services workspace init --mode=docker-lite --path="${TARGET}"
assert_ok "compose exists" test -f "${TARGET}/docker-compose.yml"
assert_ok "nginx conf exists" test -f "${TARGET}/conf/nginx.conf"
assert_ok "apache conf exists" test -f "${TARGET}/conf/apache2.conf"
assert_ok "caddyfile exists" test -f "${TARGET}/conf/Caddyfile"
assert_ok "php-fpm context exists" test -f "${TARGET}/php-fpm/Dockerfile"
assert_ok "nginx context exists" test -f "${TARGET}/nginx/Dockerfile"
assert_ok "env stub exists" test -f "${TARGET}/.env.docker-lite"
assert_ok "env stub has default php service" grep -q "PLUME_DOCKER_LITE_PHP_SERVICE=php-fpm" "${TARGET}/.env.docker-lite"

assert_fail_code 2 "workspace init refuses overwrite without force" ./plume.sh services workspace init --mode=docker-lite --path="${TARGET}"
assert_ok "workspace init overwrite with force" ./plume.sh services workspace init --mode=docker-lite --path="${TARGET}" --force

echo "phase7-workspace-init-smoke:ok"
