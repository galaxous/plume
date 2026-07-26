#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

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

assert_contains_file() {
  local expected="$1"
  local file="$2"
  if grep -Fq -- "${expected}" "${file}"; then
    echo "[PASS] contains '${expected}' in ${file}"
  else
    echo "[FAIL] missing '${expected}' in ${file}" >&2
    return 1
  fi
}

assert_not_exists() {
  local file="$1"
  if [[ ! -f "${file}" ]]; then
    echo "[PASS] removed ${file}"
  else
    echo "[FAIL] unexpected file still exists: ${file}" >&2
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
  mkdir -p "${SITE_ROOT}" "${MODE_HOME}"

  PLUME_MODE_ENV="${mode}"
  PLUME_SITE_REGISTRY_DIR="${MODE_HOME}/.config/plume/sites"
  PLUME_SITE_HOSTS_SYNC="false"
  PLUME_SITE_HOSTS_REQUIRED="false"

  assert_ok "services supported (${mode})" bash -lc "HOME=${MODE_HOME} ./plume.sh services supported --mode=${mode} --json | grep -q '\"mode\":\"${mode}\"'"
  assert_ok "services status (${mode})" bash -lc "HOME=${MODE_HOME} ./plume.sh --json services status --mode=${mode} | grep -q '\"mode\":\"${mode}\"'"
  assert_ok "services up php (${mode})" bash -lc "HOME=${MODE_HOME} ./plume.sh services up --mode=${mode} php"
  assert_ok "services down php (${mode})" bash -lc "HOME=${MODE_HOME} ./plume.sh services down --mode=${mode} php"

  CONFLICTLESS_DOMAIN="plume-site-${mode}.test"
  SITE_ID="$(HOME="${MODE_HOME}" PLUME_SITE_REGISTRY_DIR="${PLUME_SITE_REGISTRY_DIR}" PLUME_SITE_HOSTS_SYNC="${PLUME_SITE_HOSTS_SYNC}" ./plume.sh site add --mode=${PLUME_MODE_ENV} --path="${SITE_ROOT}" --domain="${CONFLICTLESS_DOMAIN}" --server=nginx --publish)"

  if [[ -z "${SITE_ID}" ]]; then
    echo "[FAIL] site add id empty for ${mode}" >&2
    exit 1
  fi
  echo "[PASS] site add (${mode}) returned id ${SITE_ID}"

  case "${mode}" in
    native) snippet_dir="${PLUME_SITE_REGISTRY_DIR}/nginx" ;;
    docker-lite) snippet_dir="${MODE_HOME}/.config/plume/docker-lite/sites/nginx" ;;
    laradock-bridge) snippet_dir="${MODE_HOME}/.config/plume/laradock-bridge/sites/nginx" ;;
    *) snippet_dir="${PLUME_SITE_REGISTRY_DIR}/nginx" ;;
  esac

  SNIPPET_FILE="${snippet_dir}/${SITE_ID}.conf"
  assert_contains_file "server_name ${CONFLICTLESS_DOMAIN};" "${SNIPPET_FILE}"

  CUSTOM_CONF_1="${TMP_ROOT}/${mode}-custom-1.conf"
  CUSTOM_CONF_2="${TMP_ROOT}/${mode}-custom-2.conf"
  cat > "${CUSTOM_CONF_1}" <<EOF
# plume mode ${mode} v1
server {
    listen 80;
    server_name ${CONFLICTLESS_DOMAIN};
    root /tmp/${mode}/public;
}
EOF
  cat > "${CUSTOM_CONF_2}" <<EOF
# plume mode ${mode} v2
server {
    listen 80;
    server_name ${CONFLICTLESS_DOMAIN};
    root /tmp/${mode}/public;
}
EOF

  assert_ok "site update custom server config (${mode})" bash -lc "HOME=${MODE_HOME} PLUME_SITE_REGISTRY_DIR=${PLUME_SITE_REGISTRY_DIR} ./plume.sh site update --mode=${PLUME_MODE_ENV} ${SITE_ID} --server-config=${CUSTOM_CONF_1}"
  assert_ok "site publish updated config (${mode})" bash -lc "HOME=${MODE_HOME} PLUME_SITE_REGISTRY_DIR=${PLUME_SITE_REGISTRY_DIR} ./plume.sh site publish --mode=${PLUME_MODE_ENV} ${SITE_ID}"
  assert_contains_file "# plume mode ${mode} v1" "${SNIPPET_FILE}"
  assert_ok "site republish with config v2 (${mode})" bash -lc "HOME=${MODE_HOME} PLUME_SITE_REGISTRY_DIR=${PLUME_SITE_REGISTRY_DIR} ./plume.sh site update --mode=${PLUME_MODE_ENV} ${SITE_ID} --server-config=${CUSTOM_CONF_2} --publish"
  assert_contains_file "# plume mode ${mode} v2" "${SNIPPET_FILE}"

  HOME="${MODE_HOME}" PLUME_SITE_REGISTRY_DIR="${PLUME_SITE_REGISTRY_DIR}" ./plume.sh site remove --mode=${PLUME_MODE_ENV} "${SITE_ID}" >/dev/null
  assert_not_exists "${SNIPPET_FILE}"
done

echo "phase5-mode-parity-smoke:ok"
