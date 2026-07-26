#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

TMP_ROOT="$(mktemp -d)"
HOME_DIR="${TMP_ROOT}/home"
SITE_REGISTRY="${TMP_ROOT}/registry"
FAKE_BIN="${TMP_ROOT}/fake-bin"
PROJECT_DIR="${TMP_ROOT}/project"
mkdir -p "${HOME_DIR}" "${SITE_REGISTRY}" "${FAKE_BIN}" "${PROJECT_DIR}/public"

cleanup() {
  rm -rf "${TMP_ROOT}"
}
trap cleanup EXIT

cat > "${FAKE_BIN}/nginx" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "${FAKE_BIN}/nginx"

set +e
env \
  HOME="${HOME_DIR}" \
  PLUME_SITE_REGISTRY_DIR="${SITE_REGISTRY}" \
  PLUME_SITE_HOSTS_SYNC=false \
  PLUME_SITE_NGINX_STRICT=true \
  PLUME_NGINX_INCLUDE_DIR="${TMP_ROOT}/does-not-exist" \
  PATH="${FAKE_BIN}:${PATH}" \
  ./plume.sh site add --mode=native --path="${PROJECT_DIR}" --domain="strict-missing.test" --server=nginx --publish >/tmp/plume-phase11-nginx-strict-missing.out 2>&1
rc=$?
set -e

if [[ ${rc} -ne 2 ]]; then
  echo "[FAIL] expected strict publish to fail with exit 2 on missing include dir, got ${rc}" >&2
  cat /tmp/plume-phase11-nginx-strict-missing.out >&2 || true
  exit 1
fi

grep -q "nginx strict mode: include directory not found" /tmp/plume-phase11-nginx-strict-missing.out || {
  echo "[FAIL] expected strict include dir error message" >&2
  cat /tmp/plume-phase11-nginx-strict-missing.out >&2 || true
  exit 1
}

echo "phase11-site-nginx-strict-missing-include-smoke:ok"
