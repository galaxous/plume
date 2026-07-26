#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

if ! command -v openssl >/dev/null 2>&1; then
  echo "phase11-site-clear-cert-smoke:skip (openssl not found)"
  exit 0
fi

TMP_ROOT="$(mktemp -d)"
HOME_DIR="${TMP_ROOT}/home"
STATE_DIR="${TMP_ROOT}/state"
REG_DIR="${TMP_ROOT}/registry"
PROJECT_DIR="${TMP_ROOT}/project"
mkdir -p "${HOME_DIR}" "${STATE_DIR}" "${REG_DIR}" "${PROJECT_DIR}/public"

cleanup() {
  if [[ -n "${SITE_ID:-}" ]]; then
    PLUME_SITE_REGISTRY_DIR="${REG_DIR}" HOME="${HOME_DIR}" PLUME_STATE_DIR="${STATE_DIR}" ./plume.sh site remove "${SITE_ID}" >/dev/null 2>&1 || true
  fi
  rm -rf "${TMP_ROOT}"
}
trap cleanup EXIT

BASE_ENV=(
  "HOME=${HOME_DIR}"
  "PLUME_STATE_DIR=${STATE_DIR}"
  "PLUME_SITE_REGISTRY_DIR=${REG_DIR}"
)

domain="clear-tls.test"
cert_id="$(env "${BASE_ENV[@]}" ./plume.sh security cert issue --mode=native --domains="${domain}" --days=7)"

SITE_ID="$(env "${BASE_ENV[@]}" ./plume.sh site add --path="${PROJECT_DIR}" --domain="${domain}" --server=nginx --cert-id="${cert_id}" --https-port=4443 --publish)"
snippet="${REG_DIR}/nginx/${SITE_ID}.conf"
grep -q 'return 301 https://' "${snippet}" || {
  echo "[FAIL] expected redirect before clear-cert" >&2
  exit 1
}

env "${BASE_ENV[@]}" ./plume.sh site update "${SITE_ID}" --clear-cert --publish >/dev/null

snippet="${REG_DIR}/nginx/${SITE_ID}.conf"
grep -q 'return 301 https://' "${snippet}" && {
  echo "[FAIL] redirect should be removed after --clear-cert" >&2
  cat "${snippet}" >&2
  exit 1
}
grep -q 'ssl_certificate ' "${snippet}" && {
  echo "[FAIL] ssl_certificate should be removed after --clear-cert" >&2
  cat "${snippet}" >&2
  exit 1
}

record="${REG_DIR}/${SITE_ID}.yml"
grep -q '^cert_id:' "${record}" && {
  echo "[FAIL] cert_id should be removed from site record" >&2
  cat "${record}" >&2
  exit 1
}

check_out="$(env "${BASE_ENV[@]}" ./plume.sh site check "${SITE_ID}")"
if printf '%s\n' "${check_out}" | grep -qE '^cert_id: cert-'; then
  echo "[FAIL] site check should show empty cert_id after clear" >&2
  printf '%s\n' "${check_out}" >&2
  exit 1
fi

echo "phase11-site-clear-cert-smoke:ok"
