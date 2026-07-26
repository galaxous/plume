#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

TMP_ROOT="$(mktemp -d)"
HOME_DIR="${TMP_ROOT}/home"
STATE_DIR="${TMP_ROOT}/state"
SRC_EXAMPLE="${TMP_ROOT}/sample.env.example"
mkdir -p "${HOME_DIR}" "${STATE_DIR}"

cleanup() {
  rm -rf "${TMP_ROOT}"
}
trap cleanup EXIT

cat > "${SRC_EXAMPLE}" <<'ENV'
PLUME_WEB_SERVER_ENABLED=true
PLUME_PHP_DEFAULT_VERSION=8.3
ENV

BASE_ENV=(
  "HOME=${HOME_DIR}"
  "PLUME_STATE_DIR=${STATE_DIR}"
)

env "${BASE_ENV[@]}" ./plume.sh env where >/dev/null
env "${BASE_ENV[@]}" ./plume.sh env init --from="${SRC_EXAMPLE}" >/dev/null

GLOBAL_ENV="${HOME_DIR}/.config/plume/.env"
[[ -f "${GLOBAL_ENV}" ]] || {
  echo "[FAIL] expected global env file after env init" >&2
  exit 1
}

grep -q '^PLUME_PHP_DEFAULT_VERSION=8.3$' "${GLOBAL_ENV}" || {
  echo "[FAIL] expected initialized env content from source example" >&2
  exit 1
}

echo "phase11-env-commands-smoke:ok"
