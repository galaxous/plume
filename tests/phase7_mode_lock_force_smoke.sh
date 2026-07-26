#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

TMP_ROOT="$(mktemp -d)"
STATE_DIR="${TMP_ROOT}/state"
OLD_PATH="${TMP_ROOT}/old"
NEW_PATH="${TMP_ROOT}/new"
mkdir -p "${STATE_DIR}" "${OLD_PATH}" "${NEW_PATH}"

cleanup() {
  rm -rf "${TMP_ROOT}"
}
trap cleanup EXIT

cat > "${OLD_PATH}/docker-compose.yml" <<'YAML'
services:
  nginx:
    image: nginx:stable
YAML

cat > "${NEW_PATH}/docker-compose.yml" <<'YAML'
services:
  nginx:
    image: nginx:stable
YAML

assert_fail_code() {
  local expected="$1"
  shift
  set +e
  "$@" >/tmp/plume-phase7-lock-force.out 2>&1
  local got=$?
  set -e
  [[ "${got}" -eq "${expected}" ]]
}

BASE_ENV=("PLUME_STATE_DIR=${STATE_DIR}")

env "${BASE_ENV[@]}" ./plume.sh mode use docker-lite >/dev/null
env "${BASE_ENV[@]}" ./plume.sh mode path set "${OLD_PATH}" >/dev/null

assert_fail_code 2 env "${BASE_ENV[@]}" ./plume.sh mode path set "${NEW_PATH}" || {
  echo "[FAIL] path switch without --force should fail" >&2
  cat /tmp/plume-phase7-lock-force.out >&2 || true
  exit 1
}

env "${BASE_ENV[@]}" ./plume.sh mode path set "${NEW_PATH}" --force >/dev/null

env "${BASE_ENV[@]}" ./plume.sh services up php --mode=native >/dev/null
[[ -f "${STATE_DIR}/context.lock" ]] || {
  echo "[FAIL] context lock should be created after services up" >&2
  exit 1
}

assert_fail_code 2 env "${BASE_ENV[@]}" ./plume.sh mode use native || {
  echo "[FAIL] mode change should fail while locked without --force" >&2
  cat /tmp/plume-phase7-lock-force.out >&2 || true
  exit 1
}

env "${BASE_ENV[@]}" ./plume.sh mode use native --force >/dev/null

echo "phase7-mode-lock-force-smoke:ok"
