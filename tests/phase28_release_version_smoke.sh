#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

TMP_ROOT="$(mktemp -d)"
HOME_DIR="${TMP_ROOT}/home"
STATE_DIR="${TMP_ROOT}/state"
mkdir -p "${HOME_DIR}/.config/plume" "${STATE_DIR}"
: > "${HOME_DIR}/.config/plume/.env"

cleanup() { rm -rf "${TMP_ROOT}"; }
trap cleanup EXIT

BASE_ENV=(
  "HOME=${HOME_DIR}"
  "PLUME_STATE_DIR=${STATE_DIR}"
  "PATH=/usr/bin:/bin"
  "PLUME_SKIP_ON_FIRST_RUN_PROVISION=true"
  "PLUME_ALLOW_NON_ROOT_INSTALL=true"
  "PLUME_GLOBAL_ENV_FILE=${HOME_DIR}/.config/plume/.env"
  "PLUME_ENV_FILE=${HOME_DIR}/.config/plume/.env"
)

EXPECTED="$(tr -d '[:space:]' < "${ROOT_DIR}/VERSION")"
[[ -n "${EXPECTED}" ]] || {
  echo "[FAIL] VERSION file empty" >&2
  exit 1
}

OUT="$(env "${BASE_ENV[@]}" ./plume.sh version 2>&1)" || {
  echo "[FAIL] version failed" >&2
  printf '%s\n' "${OUT}" >&2
  exit 1
}
echo "${OUT}" | grep -Fq "plumectl ${EXPECTED}" || {
  echo "[FAIL] version output should match VERSION (${EXPECTED})" >&2
  printf '%s\n' "${OUT}" >&2
  exit 1
}
echo "[PASS] version text"

JSON_OUT="$(env "${BASE_ENV[@]}" ./plume.sh --json version 2>&1)" || {
  echo "[FAIL] --json version failed" >&2
  printf '%s\n' "${JSON_OUT}" >&2
  exit 1
}
echo "${JSON_OUT}" | grep -Fq "\"version\":\"${EXPECTED}\"" || {
  echo "[FAIL] json version mismatch" >&2
  printf '%s\n' "${JSON_OUT}" >&2
  exit 1
}
echo "[PASS] version --json"

[[ -f "${ROOT_DIR}/docs/operations/release.md" ]] || {
  echo "[FAIL] missing docs/operations/release.md" >&2
  exit 1
}
echo "[PASS] release.md present"

[[ -f "${ROOT_DIR}/docs/operations/install.md" ]] || {
  echo "[FAIL] missing docs/operations/install.md" >&2
  exit 1
}
echo "[PASS] install.md present"

[[ -f "${ROOT_DIR}/packaging/homebrew/plumectl.rb" && -f "${ROOT_DIR}/Formula/plumectl.rb" ]] || {
  echo "[FAIL] missing Homebrew formula files" >&2
  exit 1
}
grep -q 'class Plumectl' "${ROOT_DIR}/packaging/homebrew/plumectl.rb" || {
  echo "[FAIL] formula class missing" >&2
  exit 1
}
echo "[PASS] Homebrew formula present"

[[ -f "${ROOT_DIR}/composer.json" ]] || {
  echo "[FAIL] missing composer.json" >&2
  exit 1
}
grep -q 'galaxous/laravel-plume' "${ROOT_DIR}/composer.json" || {
  echo "[FAIL] composer package name" >&2
  exit 1
}
grep -q 'bin/plumectl' "${ROOT_DIR}/composer.json" || {
  echo "[FAIL] composer bin entry" >&2
  exit 1
}
if command -v composer >/dev/null 2>&1; then
  (cd "${ROOT_DIR}" && composer validate --no-check-publish --no-check-lock 2>&1) || {
    echo "[FAIL] composer validate" >&2
    exit 1
  }
  echo "[PASS] composer.json validate"
else
  echo "[PASS] composer.json present (composer CLI skipped)"
fi

[[ -f "${ROOT_DIR}/LICENSE" ]] || {
  echo "[FAIL] missing LICENSE" >&2
  exit 1
}
echo "[PASS] LICENSE present"

[[ -x "${ROOT_DIR}/packaging/linux/install.sh" ]] || {
  echo "[FAIL] packaging/linux/install.sh missing or not executable" >&2
  exit 1
}
grep -q 'LIBEXEC=' "${ROOT_DIR}/packaging/linux/install.sh" || {
  echo "[FAIL] linux install.sh incomplete" >&2
  exit 1
}
echo "[PASS] linux install.sh present"

grep -q 'Debian / Ubuntu' "${ROOT_DIR}/docs/operations/install.md" \
  && grep -q 'RHEL / Fedora' "${ROOT_DIR}/docs/operations/install.md" || {
  echo "[FAIL] install.md should document Debian and RHEL/Fedora stages" >&2
  exit 1
}
echo "[PASS] install.md covers Homebrew + Linux distros"

echo "phase28-release-version-smoke:ok"
