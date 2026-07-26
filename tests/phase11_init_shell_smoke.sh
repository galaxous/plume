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
  "PLUME_PHP_INSTALLED_VERSIONS=8.3,8.4"
  "PLUME_PHP_DEFAULT_VERSION=8.3"
)

RC_FILE="${HOME_DIR}/.zshrc"

env "${BASE_ENV[@]}" ./plume.sh init shell --shell=zsh >/dev/null

[[ -f "${RC_FILE}" ]] || {
  echo "[FAIL] rc file not created: ${RC_FILE}" >&2
  exit 1
}

grep -q '^# >>> plume php shim >>>$' "${RC_FILE}" || {
  echo "[FAIL] begin marker missing in rc file" >&2
  exit 1
}

grep -Eq '^eval \"\$\(.+ php shim env\)\"$' "${RC_FILE}" || {
  echo "[FAIL] shim eval line missing in rc file" >&2
  exit 1
}

grep -q '^# <<< plume php shim <<<$' "${RC_FILE}" || {
  echo "[FAIL] end marker missing in rc file" >&2
  exit 1
}

env "${BASE_ENV[@]}" ./plume.sh init shell --shell=zsh >/dev/null

COUNT="$(grep -c '^# >>> plume php shim >>>$' "${RC_FILE}")"
if [[ "${COUNT}" -ne 1 ]]; then
  echo "[FAIL] init shell duplicated marker block (${COUNT})" >&2
  exit 1
fi

SHIM_DIR="${HOME_DIR}/.config/plume/shims"
[[ -x "${SHIM_DIR}/php8.4" ]] || {
  echo "[FAIL] expected php shim file not found: ${SHIM_DIR}/php8.4" >&2
  exit 1
}

echo "phase11-init-shell-smoke:ok"
