#!/usr/bin/env bash
# Install plumectl from a git clone or GitHub release tarball (Linux + macOS).
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/galaxous/plume/main/packaging/linux/install.sh | bash
#   PREFIX="$HOME/.local" bash packaging/linux/install.sh
#   PLUME_REF=v0.3.0 bash packaging/linux/install.sh
set -euo pipefail

PREFIX="${PREFIX:-/usr/local}"
PLUME_REPO="${PLUME_REPO:-https://github.com/galaxous/plume}"
PLUME_REF="${PLUME_REF:-}" # empty = clone default branch; or tag like v0.3.0
WORK="${TMPDIR:-/tmp}/plume-install-$$"

cleanup() { rm -rf "${WORK}" 2>/dev/null || true; }
trap cleanup EXIT

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "missing required command: $1" >&2
    exit 1
  }
}

need_cmd git
need_cmd install

mkdir -p "${WORK}"
cd "${WORK}"

if [[ -n "${PLUME_REF}" ]]; then
  echo "Cloning ${PLUME_REPO} @ ${PLUME_REF} ..."
  git clone --depth 1 --branch "${PLUME_REF}" "${PLUME_REPO}" src
else
  echo "Cloning ${PLUME_REPO} (default branch) ..."
  git clone --depth 1 "${PLUME_REPO}" src
fi

ROOT="${WORK}/src"
BIN_SRC="${ROOT}/bin/plumectl"
[[ -f "${BIN_SRC}" ]] || {
  echo "bin/plumectl missing in checkout" >&2
  exit 1
}
chmod +x "${BIN_SRC}" "${ROOT}/plume.sh" 2>/dev/null || true

LIBEXEC="${PREFIX}/libexec/plume"
BIN_DIR="${PREFIX}/bin"

echo "Installing tree → ${LIBEXEC}"
mkdir -p "${LIBEXEC}" "${BIN_DIR}"
# Prefer rsync if present; else cp -a
if command -v rsync >/dev/null 2>&1; then
  rsync -a --delete \
    --exclude .git \
    --exclude node_modules \
    --exclude .cursor \
    "${ROOT}/" "${LIBEXEC}/"
else
  rm -rf "${LIBEXEC:?}/"*
  cp -a "${ROOT}/." "${LIBEXEC}/"
  rm -rf "${LIBEXEC}/.git" 2>/dev/null || true
fi

ln -sfn "${LIBEXEC}/bin/plumectl" "${BIN_DIR}/plumectl"
ln -sfn "${BIN_DIR}/plumectl" "${BIN_DIR}/plume"

echo "Installed:"
echo "  ${BIN_DIR}/plumectl"
echo "  ${BIN_DIR}/plume  (alias)"
echo "Ensure ${BIN_DIR} is on PATH, then: plumectl version"
