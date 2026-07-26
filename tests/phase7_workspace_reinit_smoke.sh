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

./plume.sh services workspace init --mode=docker-lite --path="${TARGET}" >/dev/null

echo "custom-change" > "${TARGET}/conf/nginx.conf"
rm -f "${TARGET}/workspace/Dockerfile"
echo "stale" > "${TARGET}/docker-compose.yml"

./plume.sh services workspace reinit --mode=docker-lite --path="${TARGET}" >/dev/null

if grep -q "custom-change" "${TARGET}/conf/nginx.conf"; then
  echo "[FAIL] reinit did not refresh nginx conf" >&2
  exit 1
fi

if ! grep -q "name: plume-docker-lite" "${TARGET}/docker-compose.yml"; then
  echo "[FAIL] reinit did not recreate compose template" >&2
  exit 1
fi

if [[ ! -f "${TARGET}/workspace/Dockerfile" ]]; then
  echo "[FAIL] reinit did not recreate workspace Dockerfile" >&2
  exit 1
fi

echo "phase7-workspace-reinit-smoke:ok"
