#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"
SITE_REGISTRY_DIR="${TMPDIR:-/tmp}/plume-test-site-registry-${RANDOM}-${RANDOM}"

export PLUME_SITE_REGISTRY_DIR="${SITE_REGISTRY_DIR}"
# Hermetic: do not touch host nginx / sudo (D-151 ensure) during registry smoke (D-157).
export PLUME_NATIVE_NGINX_ENSURE_ON_PUBLISH=false
export PLUME_SITE_NGINX_STRICT=false
export PLUME_SITE_NGINX_STRICT_ON_RELOAD=false

assert_ok() {
  local name="$1"
  shift

  if output="$($@ 2>&1)"; then
    echo "[PASS] ${name}"
  else
    echo "[FAIL] ${name}" >&2
    printf '%s\n' "${output}" >&2
    return 1
  fi
}

assert_fail_code() {
  local expected="$1"
  local name="$2"
  shift 2
  set +e
  "$@" >/dev/null 2>&1
  local got=$?
  set -e
  if [[ "${got}" -eq "${expected}" ]]; then
    echo "[PASS] ${name}"
  else
    echo "[FAIL] ${name} (expected ${expected}, got ${got})" >&2
    return 1
  fi
}

assert_not_contains_id() {
  local expected="$1"
  local command="$2"
  local output

  output="$(eval "${command}")"

  if printf '%s\n' "${output}" | awk -v expected="${expected}" 'NR > 2 && $1 == expected { exit 1 }'; then
    echo "[PASS] ${expected} not found: ${command}"
  else
    echo "[FAIL] unexpected content contains ${expected}: ${command}" >&2
    printf '%s\n' "${output}" >&2
    return 1
  fi
}

cleanup() {
  local sid="${SITE_ID:-}"
  set +e
  if [[ -n "${sid}" ]]; then
    ./plume.sh site remove "${sid}" >/dev/null 2>&1
  fi
  rm -rf "${tmp_root}" "${PLUME_SITE_REGISTRY_DIR}"
  set -e
}

tmp_root="$(mktemp -d)"
trap cleanup EXIT
project="${tmp_root}/sample-site"
mkdir -p "${project}/public"
custom_conf1="${tmp_root}/custom-site-1.conf"
custom_conf2="${tmp_root}/custom-site-2.conf"
SITE_SNIPPET_CACHE_DIR="${PLUME_SITE_REGISTRY_DIR}"

cat > "${custom_conf1}" <<'EOF'
# plume custom site config v1
server {
    listen 80;
    server_name custom1.test;
    root /custom/path/v1;
}
EOF

cat > "${custom_conf2}" <<'EOF'
# plume custom site config v2
server {
    listen 80;
    server_name custom2.test;
    root /custom/path/v2;
}
EOF

site_domain="plume-site-$(date +%s)-${RANDOM}.test"

if ! SITE_ADD_OUT="$(./plume.sh site add --path="${project}" --domain="${site_domain}" --server=nginx --server-config="${custom_conf1}" --publish)"; then
  echo "[FAIL] site add failed" >&2
  printf '%s\n' "${SITE_ADD_OUT}" >&2
  exit 1
fi
SITE_ID="$(printf '%s\n' "${SITE_ADD_OUT}" | awk '/^site-[0-9]+-[0-9]+$/ { print; exit }')"

if [[ -z "${SITE_ID}" ]]; then
  echo "[FAIL] site add returned empty id" >&2
  printf '%s\n' "${SITE_ADD_OUT}" >&2
  exit 1
fi

echo "[PASS] site add returned id ${SITE_ID}"

sites_output="$(./plume.sh site list)"
printf '%s\n' "${sites_output}" | awk '
  NR == 1 {
    if ($1 != "ID" || $2 != "SERVER" || $3 != "PHP" || $4 != "PORT" || $5 != "HTTPS" || $6 != "CERT" || $7 != "STATUS" || $8 != "DOMAINS" || $9 != "PATH") {
      exit 1
    }
    field_count = NF
    next
  }
  NR == 3 {
    if (NF != field_count) {
      exit 1
    }
    if ($NF != "'"${project}"'") {
      exit 1
    }
  }
  END {
    if (NR < 3) {
      exit 1
    }
  }
' || {
  echo "[FAIL] site list layout/header validation" >&2
  printf '%s\n' "${sites_output}" >&2
  exit 1
}
if printf '%s\n' "${sites_output}" | awk -v expected="${SITE_ID}" 'NR > 2 && $1 == expected { found=1 } END { exit !found }'; then
  echo "[PASS] site list includes id"
else
  echo "[FAIL] site list includes id" >&2
  printf '%s\n' "${sites_output}" >&2
  exit 1
fi

SITE_MODE="$(awk '/^mode:/ {print $2; exit}' "${PLUME_SITE_REGISTRY_DIR}/${SITE_ID}.yml")"
case "${SITE_MODE}" in
  native) SITE_SNIPPET_CACHE_DIR="${PLUME_SITE_REGISTRY_DIR}" ;;
  docker-lite) SITE_SNIPPET_CACHE_DIR="${HOME}/.config/plume/docker-lite/sites" ;;
  laradock-bridge) SITE_SNIPPET_CACHE_DIR="${HOME}/.config/plume/laradock-bridge/sites" ;;
  *) SITE_SNIPPET_CACHE_DIR="${PLUME_SITE_REGISTRY_DIR}" ;;
esac

assert_ok "site check" ./plume.sh site check "${SITE_ID}"
assert_ok "custom nginx config applied on add" grep -Fq -- '# plume custom site config v1' "${SITE_SNIPPET_CACHE_DIR}/nginx/${SITE_ID}.conf"
assert_ok "publish snippet created" test -f "${SITE_SNIPPET_CACHE_DIR}/nginx/${SITE_ID}.conf"

./plume.sh site update "${SITE_ID}" --server-config="${custom_conf2}" --publish
assert_ok "custom nginx config applied on update" grep -Fq -- '# plume custom site config v2' "${SITE_SNIPPET_CACHE_DIR}/nginx/${SITE_ID}.conf"
# No --reload: hermetic registry smoke must not call host brew/sudo nginx (D-157).
./plume.sh site publish "${SITE_ID}"

./plume.sh site remove "${SITE_ID}"
assert_not_contains_id "${SITE_ID}" "./plume.sh site list"

assert_fail_code 2 "site add missing domain fails" bash -lc "./plume.sh site add --path=\"${project}\" < /dev/null"

echo "phase4-site-smoke:ok"
