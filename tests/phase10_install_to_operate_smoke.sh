#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

TMP_ROOT="$(mktemp -d)"
HOME_DIR="${TMP_ROOT}/home"
STATE_DIR="${TMP_ROOT}/state"
SITE_REGISTRY="${TMP_ROOT}/sites"
PROJECT_DIR="${TMP_ROOT}/myapp"
mkdir -p "${HOME_DIR}" "${STATE_DIR}" "${SITE_REGISTRY}" "${PROJECT_DIR}/public"

cleanup() {
  rm -rf "${TMP_ROOT}"
}
trap cleanup EXIT

BASE_ENV=(
  "HOME=${HOME_DIR}"
  "PLUME_STATE_DIR=${STATE_DIR}"
  "PLUME_SITE_REGISTRY_DIR=${SITE_REGISTRY}"
  "PLUME_SITE_HOSTS_SYNC=false"
)

env "${BASE_ENV[@]}" ./plume.sh mode use native --force --yes >/dev/null

env "${BASE_ENV[@]}" ./plume.sh project init --path="${PROJECT_DIR}" --dry-run >/dev/null

SITE_ID="$(env "${BASE_ENV[@]}" ./plume.sh site add --path="${PROJECT_DIR}" --domain="journey.test" --server=nginx --publish | tail -n 1)"
[[ -n "${SITE_ID}" ]] || {
  echo "[FAIL] site add should return id" >&2
  exit 1
}

env "${BASE_ENV[@]}" ./plume.sh site check "${SITE_ID}" >/dev/null || {
  echo "[FAIL] site check should be readable" >&2
  exit 1
}

env "${BASE_ENV[@]}" ./plume.sh status --mode=native >/dev/null
env "${BASE_ENV[@]}" ./plume.sh health --mode=native >/dev/null

BACKUP_ID="$(env "${BASE_ENV[@]}" ./plume.sh backup create --mode=native --scope=config --name=journey | tail -n 1)"
[[ -n "${BACKUP_ID}" ]] || {
  echo "[FAIL] backup create should return id" >&2
  exit 1
}

env "${BASE_ENV[@]}" ./plume.sh deploy rollback latest --mode=native --dry-run >/dev/null

env "${BASE_ENV[@]}" ./plume.sh site remove "${SITE_ID}" >/dev/null

echo "phase10-install-to-operate-smoke:ok"
