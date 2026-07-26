#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

TMP_ROOT="$(mktemp -d)"
STATE_DIR="${TMP_ROOT}/state"
DL_PATH="${TMP_ROOT}/dl"
mkdir -p "${DL_PATH}"

cleanup() {
  rm -rf "${TMP_ROOT}"
}
trap cleanup EXIT

BASE_ENV=("PLUME_STATE_DIR=${STATE_DIR}")

env "${BASE_ENV[@]}" ./plume.sh mode use docker-lite >/tmp/plume-phase7-mode-active.out 2>&1
env "${BASE_ENV[@]}" ./plume.sh mode path set "${DL_PATH}" >/tmp/plume-phase7-mode-active.out 2>&1

env "${BASE_ENV[@]}" ./plume.sh mode path get | grep -q "${DL_PATH}" || {
  echo "[FAIL] mode path get (implicit active mode) should return docker-lite path" >&2
  cat /tmp/plume-phase7-mode-active.out >&2 || true
  exit 1
}

env "${BASE_ENV[@]}" ./plume.sh mode path list | awk -v p="${DL_PATH}" '$1=="active" && $2=="docker-lite" && $3==p {ok=1} END{exit !ok}' || {
  echo "[FAIL] mode path list should include active mode and path" >&2
  env "${BASE_ENV[@]}" ./plume.sh mode path list >&2 || true
  exit 1
}

echo "phase7-mode-path-active-context-smoke:ok"
