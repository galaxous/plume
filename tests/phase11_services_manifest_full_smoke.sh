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
CONFIG_DIR="${HOME_DIR}/.config/plume"
MANIFEST="${CONFIG_DIR}/services.yml"
mkdir -p "${CONFIG_DIR}" "${STATE_DIR}"

cat > "${MANIFEST}" <<'EOF'
version: 1
services:
  web:
    engine: nginx
    enabled: true
  php:
    enabled: true
    default_version: "8.3"
    versions:
      - "8.3"
  database:
    engine: mariadb
    version: "11.0"
  redis:
    enabled: false
  composer: { enabled: false }
  mailpit:
    enabled: true
  postgres:
    enabled: false
    version: "16"
  meilisearch: { enabled: false, version: "1.8" }
EOF

RUN=(
  env
  "HOME=${HOME_DIR}"
  "PLUME_STATE_DIR=${STATE_DIR}"
  "PLUME_AUTO_HOST_BOOTSTRAP=false"
  "PLUME_SERVICES_MANIFEST_FILE=${MANIFEST}"
)

OUT="$("${RUN[@]}" ./plume.sh services manifest show 2>/dev/null)"

echo "${OUT}" | grep -q 'effective_mailpit_enabled=true' || {
  echo "[FAIL] expected mailpit enabled from yaml block" >&2
  exit 1
}

echo "${OUT}" | grep -q 'effective_postgres_enabled=false' || {
  echo "[FAIL] expected postgres disabled" >&2
  exit 1
}

echo "${OUT}" | grep -q 'effective_postgres_version=16' || {
  echo "[FAIL] expected postgres version from yaml" >&2
  exit 1
}

echo "${OUT}" | grep -q 'effective_composer_enabled=false' || {
  echo "[FAIL] expected inline composer disabled" >&2
  exit 1
}

echo "${OUT}" | grep -q 'effective_redis_enabled=false' || {
  echo "[FAIL] expected redis disabled" >&2
  exit 1
}

echo "${OUT}" | grep -q 'effective_meilisearch_version=1.8' || {
  echo "[FAIL] expected meilisearch version from inline map" >&2
  exit 1
}

echo "phase11_services_manifest_full_smoke:ok"
