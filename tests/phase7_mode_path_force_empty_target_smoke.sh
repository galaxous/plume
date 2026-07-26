#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

TMP_ROOT="$(mktemp -d)"
STATE_DIR="${TMP_ROOT}/state"
OLD_PATH="${TMP_ROOT}/old"
NEW_PATH="${TMP_ROOT}/new-empty"
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

BASE_ENV=("PLUME_STATE_DIR=${STATE_DIR}")

env "${BASE_ENV[@]}" ./plume.sh mode use docker-lite >/dev/null
env "${BASE_ENV[@]}" ./plume.sh mode path set "${OLD_PATH}" >/dev/null

env "${BASE_ENV[@]}" ./plume.sh mode path set "${NEW_PATH}" --force >/tmp/plume-phase7-mode-empty-target.out 2>&1

env "${BASE_ENV[@]}" ./plume.sh mode path get | grep -q "${NEW_PATH}" || {
  echo "[FAIL] expected path switch to empty target with --force" >&2
  cat /tmp/plume-phase7-mode-empty-target.out >&2 || true
  exit 1
}

grep -q "docker-lite compose not found under" /tmp/plume-phase7-mode-empty-target.out || {
  echo "[FAIL] expected compose-missing warning for empty target path" >&2
  cat /tmp/plume-phase7-mode-empty-target.out >&2 || true
  exit 1
}

echo "phase7-mode-path-force-empty-target-smoke:ok"
