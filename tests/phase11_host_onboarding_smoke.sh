#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

TMP_ROOT="$(mktemp -d)"
cleanup() {
  rm -rf "${TMP_ROOT}"
}
trap cleanup EXIT

HOME_DIR="${TMP_ROOT}/home"
STATE_DIR="${TMP_ROOT}/state"
HOST_ENV="${HOME_DIR}/.config/plume/host.env"
mkdir -p "${HOME_DIR}" "${STATE_DIR}"

RUN=(env "HOME=${HOME_DIR}" "PLUME_STATE_DIR=${STATE_DIR}" "PLUME_AUTO_HOST_BOOTSTRAP=false")

"${RUN[@]}" ./plume.sh init host >/dev/null

[[ -f "${HOST_ENV}" ]] || {
  echo "[FAIL] init host should write host.env" >&2
  exit 1
}

grep -q '^os=' "${HOST_ENV}" || {
  echo "[FAIL] host.env missing os=" >&2
  exit 1
}

grep -q '^detected_at=' "${HOST_ENV}" || {
  echo "[FAIL] host.env missing detected_at=" >&2
  exit 1
}

"${RUN[@]}" ./plume.sh init host >/dev/null
count="$(grep -c '^detected_at=' "${HOST_ENV}" || true)"
[[ "${count}" -eq 1 ]] || {
  echo "[FAIL] init host should be idempotent (single detected_at)" >&2
  exit 1
}

"${RUN[@]}" ./plume.sh init onboarding >/dev/null

"${RUN[@]}" ./plume.sh doctor onboarding >/dev/null

out="$("${RUN[@]}" ./plume.sh init onboarding --fix 2>&1)"
echo "${out}" | grep -q 'opening Full Disk Access' && {
  echo "[FAIL] init onboarding --fix must not open System Settings" >&2
  exit 1
}
if [[ "$(uname -s)" == "Darwin" ]]; then
  echo "${out}" | grep -q 'NOT add plume.sh' || {
    echo "[FAIL] macOS onboarding should warn not to add plume.sh" >&2
    exit 1
  }
fi

echo "phase11_host_onboarding_smoke:ok"
