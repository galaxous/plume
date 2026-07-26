#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

TMP_ROOT="$(mktemp -d)"
HOME_DIR="${TMP_ROOT}/home"
SITE_REGISTRY="${TMP_ROOT}/registry"
PROJECT_DIR="${TMP_ROOT}/project"
mkdir -p "${HOME_DIR}" "${SITE_REGISTRY}" "${PROJECT_DIR}/public"

cleanup() {
  rm -rf "${TMP_ROOT}"
}
trap cleanup EXIT

BASE_ENV=(
  "HOME=${HOME_DIR}"
  "PLUME_SITE_REGISTRY_DIR=${SITE_REGISTRY}"
  "PLUME_SITE_HOSTS_SYNC=false"
  "PLUME_NATIVE_HOMEBREW_HTTP_PORT=8080"
)

SITE_ID="$(env "${BASE_ENV[@]}" ./plume.sh site add --mode=native --path="${PROJECT_DIR}" --domain="url-hints.test" --server=nginx | tail -n 1)"
[[ -n "${SITE_ID}" ]] || {
  echo "[FAIL] site add should return id" >&2
  exit 1
}

CHECK_OUT="$(env "${BASE_ENV[@]}" ./plume.sh site check "${SITE_ID}")"

printf '%s\n' "${CHECK_OUT}" | grep -q '^effective_http_port: 8080$' || {
  echo "[FAIL] expected effective_http_port 8080" >&2
  printf '%s\n' "${CHECK_OUT}" >&2
  exit 1
}

printf '%s\n' "${CHECK_OUT}" | grep -q '^url_http: http://url-hints.test:8080$' || {
  echo "[FAIL] expected url_http with :8080" >&2
  printf '%s\n' "${CHECK_OUT}" >&2
  exit 1
}

printf '%s\n' "${CHECK_OUT}" | grep -q '^access_hint:' || {
  echo "[FAIL] expected access_hint line" >&2
  printf '%s\n' "${CHECK_OUT}" >&2
  exit 1
}

echo "phase11-site-check-url-hints-smoke:ok"
