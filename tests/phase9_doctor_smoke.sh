#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

TMP_ROOT="$(mktemp -d)"
HOME_DIR="${TMP_ROOT}/home"
STATE_DIR="${TMP_ROOT}/state"
mkdir -p "${HOME_DIR}" "${STATE_DIR}"

cleanup() {
  rm -rf "${TMP_ROOT}"
}
trap cleanup EXIT

BASE_ENV=(
  "HOME=${HOME_DIR}"
  "PLUME_STATE_DIR=${STATE_DIR}"
)

check_out="$(env "${BASE_ENV[@]}" ./plume.sh doctor check --mode=native)"
printf '%s\n' "${check_out}" | grep -q '^OVERALL            OK$' || {
  echo "[FAIL] doctor check native should be overall OK" >&2
  printf '%s\n' "${check_out}" >&2
  exit 1
}

services_out="$(env "${BASE_ENV[@]}" ./plume.sh doctor services --mode=native)"
printf '%s\n' "${services_out}" | grep -q '^SERVICE' || {
  echo "[FAIL] doctor services should print service table header" >&2
  printf '%s\n' "${services_out}" >&2
  exit 1
}

ports_out="$(env "${BASE_ENV[@]}" ./plume.sh doctor ports --mode=native)"
printf '%s\n' "${ports_out}" | grep -q '^MODE              native$' || {
  echo "[FAIL] doctor ports should print mode header" >&2
  printf '%s\n' "${ports_out}" >&2
  exit 1
}
printf '%s\n' "${ports_out}" | grep -q '^SERVICE           RUNNING PORTS$' || {
  echo "[FAIL] doctor ports should print table header" >&2
  printf '%s\n' "${ports_out}" >&2
  exit 1
}

set +e
err_file="${TMP_ROOT}/doctor-laradock.err"
env "${BASE_ENV[@]}" ./plume.sh doctor check --mode=laradock-bridge >"${err_file}" 2>&1
rc=$?
set -e
if [[ "${rc}" -ne 2 ]]; then
  echo "[FAIL] doctor check laradock-bridge without context should fail with code 2" >&2
  cat "${err_file}" >&2 || true
  exit 1
fi

echo "phase9-doctor-smoke:ok"
