#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

if [[ "$(id -u)" -eq 0 ]]; then
  echo "[SKIP] running as root; non-root runtime checks skipped"
  echo "phase5-non-root-runtime-smoke:ok"
  exit 0
fi

assert_ok() {
  local name="$1"
  shift
  if "$@"; then
    echo "[PASS] ${name}"
  else
    echo "[FAIL] ${name}" >&2
    return 1
  fi
}

cleanup() {
  rm -rf "${TMP_ROOT}"
}
trap cleanup EXIT

TMP_ROOT="$(mktemp -d)"

for mode in native docker-lite laradock-bridge; do
  MODE_HOME="${TMP_ROOT}/${mode}-home"
  SITE_ROOT="${TMP_ROOT}/${mode}-project/public"
  SITE_REGISTRY="${MODE_HOME}/.config/plume/sites"
  mkdir -p "${MODE_HOME}" "${SITE_ROOT}"

  assert_ok "services up non-root (${mode})" bash -lc "HOME=${MODE_HOME} ./plume.sh services up --mode=${mode} php"
  assert_ok "services down non-root (${mode})" bash -lc "HOME=${MODE_HOME} ./plume.sh services down --mode=${mode} php"

  SITE_ID="$(HOME="${MODE_HOME}" PLUME_SITE_REGISTRY_DIR="${SITE_REGISTRY}" PLUME_SITE_HOSTS_SYNC=false ./plume.sh site add --mode="${mode}" --path="${SITE_ROOT}" --domain="nonroot-${mode}.test" --server=nginx --publish)"
  assert_ok "site add non-root (${mode})" test -n "${SITE_ID}"

  assert_ok "site publish dry-run non-root (${mode})" bash -lc "HOME=${MODE_HOME} PLUME_SITE_REGISTRY_DIR=${SITE_REGISTRY} ./plume.sh site publish --mode=${mode} ${SITE_ID} --dry-run"
  HOME="${MODE_HOME}" PLUME_SITE_REGISTRY_DIR="${SITE_REGISTRY}" ./plume.sh site remove --mode="${mode}" "${SITE_ID}" >/dev/null
  assert_ok "site remove non-root (${mode})" true

done

echo "phase5-non-root-runtime-smoke:ok"
