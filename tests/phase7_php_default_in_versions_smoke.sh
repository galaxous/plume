#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

TMP_ROOT="$(mktemp -d)"
TARGET="${TMP_ROOT}/project"
mkdir -p "${TARGET}"

cleanup() {
  rm -rf "${TMP_ROOT}"
}
trap cleanup EXIT

PLUME_PHP_DEFAULT_VERSION=8.4 \
PLUME_PHP_VERSION=8.4 \
PLUME_PHP_INSTALLED_VERSIONS=8.1,8.2,8.3 \
./plume.sh services workspace init --mode=docker-lite --path="${TARGET}" --force >/dev/null

if ! grep -q '^PLUME_PHP_INSTALLED_VERSIONS=.*8.4' "${TARGET}/.env.docker-lite"; then
  echo "[FAIL] default php version was not auto-added into PLUME_PHP_INSTALLED_VERSIONS" >&2
  cat "${TARGET}/.env.docker-lite" >&2 || true
  exit 1
fi

echo "phase7-php-default-in-versions-smoke:ok"
