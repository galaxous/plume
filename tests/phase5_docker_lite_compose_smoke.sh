#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

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
  "$@" >/tmp/plume-phase5-dl-compose.out 2>&1
  local got=$?
  set -e
  if [[ "${got}" -eq "${expected}" ]]; then
    echo "[PASS] ${name}"
  else
    echo "[FAIL] ${name} (expected ${expected}, got ${got})" >&2
    cat /tmp/plume-phase5-dl-compose.out >&2
    return 1
  fi
}

cleanup() {
  rm -rf "${TMP_ROOT}"
  rm -f /tmp/plume-phase5-dl-compose.out
}

trap cleanup EXIT

TMP_ROOT="$(mktemp -d)"
MODE_HOME="${TMP_ROOT}/home"
SITE_ROOT="${TMP_ROOT}/project/public"
SITE_REGISTRY="${MODE_HOME}/.config/plume/sites"
MISSING_COMPOSE="${TMP_ROOT}/missing-compose.yml"
VALID_COMPOSE="${TMP_ROOT}/docker-compose.yml"
mkdir -p "${SITE_ROOT}" "${MODE_HOME}"

cat > "${VALID_COMPOSE}" <<'YAML'
services:
  nginx:
    image: nginx:stable
YAML

assert_fail_code 2 "docker-lite requires compose file when enabled" \
  env HOME="${MODE_HOME}" \
      PLUME_SITE_REGISTRY_DIR="${SITE_REGISTRY}" \
      PLUME_DOCKER_LITE_COMPOSE_REQUIRED=true \
      PLUME_DOCKER_LITE_COMPOSE_FILE="${MISSING_COMPOSE}" \
      ./plume.sh site add --mode=docker-lite --path="${SITE_ROOT}" --domain="dl-compose-missing.test" --server=nginx --publish

SITE_ID="$(HOME="${MODE_HOME}" \
  PLUME_SITE_REGISTRY_DIR="${SITE_REGISTRY}" \
  PLUME_DOCKER_LITE_COMPOSE_REQUIRED=true \
  PLUME_DOCKER_LITE_COMPOSE_FILE="${VALID_COMPOSE}" \
  ./plume.sh site add --mode=docker-lite --path="${SITE_ROOT}" --domain="dl-compose-valid.test" --server=nginx --publish)"

assert_ok "docker-lite publish succeeds with compose file" test -n "${SITE_ID}"

HOME="${MODE_HOME}" PLUME_SITE_REGISTRY_DIR="${SITE_REGISTRY}" ./plume.sh site remove --mode=docker-lite "${SITE_ID}" >/dev/null

echo "phase5-docker-lite-compose-smoke:ok"
