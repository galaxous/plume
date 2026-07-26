#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

TMP_ROOT="$(mktemp -d)"
HOME_DIR="${TMP_ROOT}/home"
SITE_REGISTRY="${TMP_ROOT}/registry"
FAKE_BIN="${TMP_ROOT}/fake-bin"
APACHE_PROJECT_DIR="${TMP_ROOT}/project-apache"
CADDY_PROJECT_DIR="${TMP_ROOT}/project-caddy"
mkdir -p "${HOME_DIR}" "${SITE_REGISTRY}" "${FAKE_BIN}" "${APACHE_PROJECT_DIR}/public" "${CADDY_PROJECT_DIR}/public"

cleanup() {
  rm -rf "${TMP_ROOT}"
}
trap cleanup EXIT

APACHE_LOG="${TMP_ROOT}/apachectl.log"
CADDY_LOG="${TMP_ROOT}/caddy.log"

cat > "${FAKE_BIN}/apachectl" <<EOF
#!/usr/bin/env bash
echo "\$*" >> "${APACHE_LOG}"
if [[ "\${1:-}" == "-t" ]]; then
  exit 0
fi
if [[ "\${1:-}" == "-k" && "\${2:-}" == "graceful" ]]; then
  exit 0
fi
exit 0
EOF
chmod +x "${FAKE_BIN}/apachectl"

cat > "${FAKE_BIN}/caddy" <<EOF
#!/usr/bin/env bash
echo "\$*" >> "${CADDY_LOG}"
if [[ "\${1:-}" == "validate" ]]; then
  exit 0
fi
if [[ "\${1:-}" == "reload" ]]; then
  exit 0
fi
exit 0
EOF
chmod +x "${FAKE_BIN}/caddy"

BASE_ENV=(
  "HOME=${HOME_DIR}"
  "PLUME_SITE_REGISTRY_DIR=${SITE_REGISTRY}"
  "PLUME_SITE_HOSTS_SYNC=false"
  "PATH=${FAKE_BIN}:${PATH}"
)

APACHE_INCLUDE_DIR="${TMP_ROOT}/apache-include"
CADDY_INCLUDE_DIR="${TMP_ROOT}/caddy-include"
mkdir -p "${APACHE_INCLUDE_DIR}" "${CADDY_INCLUDE_DIR}"

APACHE_SITE_ID="$(env "${BASE_ENV[@]}" \
  PLUME_SITE_APACHE2_STRICT=true \
  PLUME_APACHE2_INCLUDE_DIR="${APACHE_INCLUDE_DIR}" \
  ./plume.sh site add --mode=native --path="${APACHE_PROJECT_DIR}" --domain="strict-apache.test" --server=apache2 | tail -n 1)"
[[ -n "${APACHE_SITE_ID}" ]] || {
  echo "[FAIL] apache2 strict site add should return id" >&2
  exit 1
}
env "${BASE_ENV[@]}" \
  PLUME_SITE_APACHE2_STRICT=true \
  PLUME_APACHE2_INCLUDE_DIR="${APACHE_INCLUDE_DIR}" \
  ./plume.sh site publish --mode=native "${APACHE_SITE_ID}" --reload >/tmp/plume-phase11-apache-strict.out

[[ -f "${APACHE_INCLUDE_DIR}/${APACHE_SITE_ID}.conf" ]] || {
  echo "[FAIL] apache2 strict should write target include file" >&2
  exit 1
}
grep -q -- "^-t$" "${APACHE_LOG}" || {
  echo "[FAIL] apache2 strict should run apachectl -t" >&2
  cat "${APACHE_LOG}" >&2 || true
  exit 1
}
apache_reload_count="$(grep -c -- "^-k graceful$" "${APACHE_LOG}" || true)"
if [[ "${apache_reload_count}" != "1" ]]; then
  echo "[FAIL] apache2 strict publish --reload should run one graceful reload, got ${apache_reload_count}" >&2
  cat "${APACHE_LOG}" >&2 || true
  exit 1
fi

CADDY_SITE_ID="$(env "${BASE_ENV[@]}" \
  PLUME_SITE_CADDY_STRICT=true \
  PLUME_CADDY_INCLUDE_DIR="${CADDY_INCLUDE_DIR}" \
  ./plume.sh site add --mode=native --path="${CADDY_PROJECT_DIR}" --domain="strict-caddy.test" --server=caddy | tail -n 1)"
[[ -n "${CADDY_SITE_ID}" ]] || {
  echo "[FAIL] caddy strict site add should return id" >&2
  exit 1
}
env "${BASE_ENV[@]}" \
  PLUME_SITE_CADDY_STRICT=true \
  PLUME_CADDY_INCLUDE_DIR="${CADDY_INCLUDE_DIR}" \
  ./plume.sh site publish --mode=native "${CADDY_SITE_ID}" --reload >/tmp/plume-phase11-caddy-strict.out

[[ -f "${CADDY_INCLUDE_DIR}/${CADDY_SITE_ID}.conf" ]] || {
  echo "[FAIL] caddy strict should write target include file" >&2
  exit 1
}
grep -q -- "^validate$" "${CADDY_LOG}" || {
  echo "[FAIL] caddy strict should run caddy validate" >&2
  cat "${CADDY_LOG}" >&2 || true
  exit 1
}
caddy_reload_count="$(grep -c -- "^reload$" "${CADDY_LOG}" || true)"
if [[ "${caddy_reload_count}" != "1" ]]; then
  echo "[FAIL] caddy strict publish --reload should run one reload, got ${caddy_reload_count}" >&2
  cat "${CADDY_LOG}" >&2 || true
  exit 1
fi

echo "phase11-site-apache2-caddy-strict-publish-smoke:ok"
