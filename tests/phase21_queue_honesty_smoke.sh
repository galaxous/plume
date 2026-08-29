#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

TMP_ROOT="$(mktemp -d)"
HOME_DIR="${TMP_ROOT}/home"
STATE_DIR="${TMP_ROOT}/state"
MOCK_BIN="${TMP_ROOT}/bin"
mkdir -p "${HOME_DIR}/.config/plume" "${STATE_DIR}" "${MOCK_BIN}"
: > "${HOME_DIR}/.config/plume/.env"

cleanup() { rm -rf "${TMP_ROOT}"; }
trap cleanup EXIT

cat > "${MOCK_BIN}/brew" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "${MOCK_BIN}/brew"

BASE_ENV=(
  "HOME=${HOME_DIR}"
  "PLUME_STATE_DIR=${STATE_DIR}"
  "PATH=${MOCK_BIN}:/usr/bin:/bin"
  "PLUME_NATIVE_HOST_INSTALL_DRIVER=mock"
  "PLUME_ALLOW_NON_ROOT_INSTALL=true"
  "PLUME_SKIP_ON_FIRST_RUN_PROVISION=true"
  "PLUME_PHP_EXTENSIONS_AUTO_SYNC=false"
  "PLUME_GLOBAL_ENV_FILE=${HOME_DIR}/.config/plume/.env"
  "PLUME_ENV_FILE=${HOME_DIR}/.config/plume/.env"
)

env "${BASE_ENV[@]}" ./plume.sh mode use native --force --yes >/dev/null

HORIZON_OUT="$(env "${BASE_ENV[@]}" \
  PLUME_SUPERVISOR_ENABLED=true \
  PLUME_HORIZON_ENABLED=true \
  ./plume.sh services up horizon --mode=native 2>&1)" || {
  echo "[FAIL] horizon up should succeed" >&2
  printf '%s\n' "${HORIZON_OUT}" >&2
  exit 1
}
echo "${HORIZON_OUT}" | grep -qi 'registry-only' && {
  echo "[FAIL] horizon must not warn registry-only after D-147" >&2
  printf '%s\n' "${HORIZON_OUT}" >&2
  exit 1
}
STATUS="$(env "${BASE_ENV[@]}" PLUME_HORIZON_ENABLED=true PLUME_SUPERVISOR_ENABLED=true \
  ./plume.sh services status horizon --mode=native 2>/dev/null | grep '^horizon' || true)"
echo "${STATUS}" | grep -q 'healthy' || {
  echo "[FAIL] mock horizon health should be healthy" >&2
  printf '%s\n' "${STATUS}" >&2
  exit 1
}
echo "[PASS] horizon native mock driver (not registry-only)"

MEILI_OUT="$(env "${BASE_ENV[@]}" PLUME_MEILISEARCH_ENABLED=true \
  ./plume.sh services up meilisearch --mode=native 2>&1)" || {
  echo "[FAIL] meilisearch up should succeed as toggle-only" >&2
  printf '%s\n' "${MEILI_OUT}" >&2
  exit 1
}
echo "${MEILI_OUT}" | grep -qi 'toggle-only' || {
  echo "[FAIL] expected toggle-only warn for meilisearch" >&2
  printf '%s\n' "${MEILI_OUT}" >&2
  exit 1
}
MEILI_ST="$(env "${BASE_ENV[@]}" PLUME_MEILISEARCH_ENABLED=true \
  ./plume.sh services status meilisearch --mode=native 2>/dev/null | grep '^meilisearch' || true)"
echo "${MEILI_ST}" | grep -q 'registry' || {
  echo "[FAIL] meilisearch health should be registry" >&2
  printf '%s\n' "${MEILI_ST}" >&2
  exit 1
}
echo "[PASS] meilisearch toggle-only honesty"

MINIO_OUT="$(env "${BASE_ENV[@]}" PLUME_MINIO_ENABLED=true \
  ./plume.sh services up minio --mode=native 2>&1)" || {
  echo "[FAIL] minio up should succeed as toggle-only" >&2
  printf '%s\n' "${MINIO_OUT}" >&2
  exit 1
}
echo "${MINIO_OUT}" | grep -qi 'toggle-only' || {
  echo "[FAIL] expected toggle-only warn for minio" >&2
  printf '%s\n' "${MINIO_OUT}" >&2
  exit 1
}
echo "[PASS] minio toggle-only honesty"

echo "phase21-queue-honesty-smoke:ok"
