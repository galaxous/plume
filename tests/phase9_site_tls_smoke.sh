#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

if ! command -v openssl >/dev/null 2>&1; then
  echo "phase9-site-tls-smoke:skip (openssl not found)"
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

domain="tls-site.test"
cert_id="$(env "${BASE_ENV[@]}" ./plume.sh security cert issue --mode=native --domains="${domain},www.${domain}" --days=7)"

SITE_ID="$(env "${BASE_ENV[@]}" ./plume.sh site add --path="${PROJECT_DIR}" --domain="${domain}" --server=nginx --cert-id="${cert_id}" --https-port=4443 --publish)"
[[ -n "${SITE_ID}" ]] || {
  echo "[FAIL] site add should return id" >&2
  exit 1
}

snippet="${REG_DIR}/nginx/${SITE_ID}.conf"
[[ -f "${snippet}" ]] || {
  echo "[FAIL] expected nginx snippet: ${snippet}" >&2
  exit 1
}

grep -q 'listen 4443 ssl;' "${snippet}" || {
  echo "[FAIL] expected https ssl listen in snippet" >&2
  cat "${snippet}" >&2
  exit 1
}

grep -q 'ssl_certificate ' "${snippet}" || {
  echo "[FAIL] expected ssl_certificate line" >&2
  cat "${snippet}" >&2
  exit 1
}

grep -Fq 'return 301 https://$host:4443$request_uri;' "${snippet}" || {
  echo "[FAIL] expected http->https redirect line" >&2
  cat "${snippet}" >&2
  exit 1
}

check_out="$(env "${BASE_ENV[@]}" ./plume.sh site check "${SITE_ID}")"
printf '%s\n' "${check_out}" | grep -q "^cert_id: ${cert_id}$" || {
  echo "[FAIL] site check should include cert_id" >&2
  printf '%s\n' "${check_out}" >&2
  exit 1
}
printf '%s\n' "${check_out}" | grep -q '^https_port: 4443$' || {
  echo "[FAIL] site check should include https_port" >&2
  printf '%s\n' "${check_out}" >&2
  exit 1
}

echo "phase9-site-tls-smoke:ok"
