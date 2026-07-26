#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

if ! command -v openssl >/dev/null 2>&1; then
  echo "phase9-security-cert-smoke:skip (openssl not found)"
  exit 0
fi
if ! command -v sqlite3 >/dev/null 2>&1; then
  echo "phase9-security-cert-smoke:skip (sqlite3 not found)"
  exit 0
fi

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

cert_id="$(env "${BASE_ENV[@]}" ./plume.sh security cert issue --mode=native --domains=app.test,www.app.test --days=7)"
[[ -n "${cert_id}" ]] || {
  echo "[FAIL] cert issue should return id" >&2
  exit 1
}

list_out="$(env "${BASE_ENV[@]}" ./plume.sh security cert list --mode=native)"
printf '%s\n' "${list_out}" | grep -q "${cert_id}" || {
  echo "[FAIL] cert list should include issued cert" >&2
  printf '%s\n' "${list_out}" >&2
  exit 1
}

show_out="$(env "${BASE_ENV[@]}" ./plume.sh security cert show "${cert_id}" --mode=native)"
printf '%s\n' "${show_out}" | grep -q '^DOMAINS=app.test,www.app.test$' || {
  echo "[FAIL] cert show should include domain list" >&2
  printf '%s\n' "${show_out}" >&2
  exit 1
}

env "${BASE_ENV[@]}" ./plume.sh security cert renew "${cert_id}" --mode=native --days=5 >/dev/null

crt_file="${STATE_DIR}/certs/${cert_id}/cert.crt"
[[ -f "${crt_file}" ]] || {
  echo "[FAIL] renewed cert file missing" >&2
  exit 1
}

subject_alt="$(openssl x509 -noout -text -in "${crt_file}" | grep -A1 'Subject Alternative Name' | tr -d '\n')"
printf '%s\n' "${subject_alt}" | grep -q 'DNS:app.test' || {
  echo "[FAIL] cert SAN should include app.test" >&2
  exit 1
}

DB_FILE="${STATE_DIR}/plume-state.db"
for event in \
  security.cert.issue.ok \
  security.cert.list \
  security.cert.show \
  security.cert.renew.ok; do
  count="$(sqlite3 "${DB_FILE}" "SELECT COUNT(*) FROM runtime_events WHERE event='${event}';")"
  if [[ "${count}" -lt 1 ]]; then
    echo "[FAIL] missing cert audit event: ${event}" >&2
    sqlite3 "${DB_FILE}" "SELECT ts,event,details FROM runtime_events ORDER BY id DESC LIMIT 30;" >&2 || true
    exit 1
  fi
done

echo "phase9-security-cert-smoke:ok"
