#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

TMP_ROOT="$(mktemp -d)"
HOME_DIR="${TMP_ROOT}/home"
SITE_REGISTRY="${TMP_ROOT}/registry"
INCLUDE_DIR="${TMP_ROOT}/nginx-include"
PROJECT_DIR="${TMP_ROOT}/project"
mkdir -p "${HOME_DIR}" "${SITE_REGISTRY}" "${INCLUDE_DIR}" "${PROJECT_DIR}/public"

cleanup() {
  rm -rf "${TMP_ROOT}"
}
trap cleanup EXIT

BASE_ENV=(
  "HOME=${HOME_DIR}"
  "PLUME_SITE_REGISTRY_DIR=${SITE_REGISTRY}"
  "PLUME_SITE_HOSTS_SYNC=false"
  "PLUME_SITE_NGINX_STRICT=true"
  "PLUME_NGINX_INCLUDE_DIR=${INCLUDE_DIR}"
)

SITE_ID="$(env "${BASE_ENV[@]}" ./plume.sh site add --mode=native --path="${PROJECT_DIR}" --domain="check-strict.test" --server=nginx | tail -n 1)"
[[ -n "${SITE_ID}" ]] || {
  echo "[FAIL] site add should return id" >&2
  exit 1
}

CHECK_OUT="$(env "${BASE_ENV[@]}" ./plume.sh site check "${SITE_ID}")"

printf '%s\n' "${CHECK_OUT}" | grep -q '^mode: native$' || {
  echo "[FAIL] expected mode in site check output" >&2
  printf '%s\n' "${CHECK_OUT}" >&2
  exit 1
}

printf '%s\n' "${CHECK_OUT}" | grep -q '^strict_enabled: true$' || {
  echo "[FAIL] expected strict_enabled true in site check output" >&2
  printf '%s\n' "${CHECK_OUT}" >&2
  exit 1
}

printf '%s\n' "${CHECK_OUT}" | grep -q "^strict_include_dir: ${INCLUDE_DIR}$" || {
  echo "[FAIL] expected strict include dir in site check output" >&2
  printf '%s\n' "${CHECK_OUT}" >&2
  exit 1
}

printf '%s\n' "${CHECK_OUT}" | grep -q "^strict_include_target: ${INCLUDE_DIR}/${SITE_ID}.conf$" || {
  echo "[FAIL] expected strict include target in site check output" >&2
  printf '%s\n' "${CHECK_OUT}" >&2
  exit 1
}

echo "phase11-site-check-strict-visibility-smoke:ok"
