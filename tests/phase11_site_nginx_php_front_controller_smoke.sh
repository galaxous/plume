#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

TMP_ROOT="$(mktemp -d)"
HOME_DIR="${TMP_ROOT}/home"
SITE_REGISTRY="${TMP_ROOT}/registry"
PROJECT_DIR="${TMP_ROOT}/project"
mkdir -p "${HOME_DIR}" "${SITE_REGISTRY}" "${PROJECT_DIR}/public"

printf '%s\n' '<?php echo "ok";' >"${PROJECT_DIR}/public/index.php"

cleanup() {
  rm -rf "${TMP_ROOT}"
}
trap cleanup EXIT

BASE_ENV=(
  "HOME=${HOME_DIR}"
  "PLUME_SITE_REGISTRY_DIR=${SITE_REGISTRY}"
  "PLUME_SITE_HOSTS_SYNC=false"
)

SITE_ID="$(env "${BASE_ENV[@]}" ./plume.sh site add --mode=native --path="${PROJECT_DIR}" --domain="front-controller.test" --server=nginx --publish | tail -n 1)"
[[ -n "${SITE_ID}" ]] || {
  echo "[FAIL] site add should return id" >&2
  exit 1
}

CONF_FILE="${SITE_REGISTRY}/nginx/${SITE_ID}.conf"
[[ -f "${CONF_FILE}" ]] || {
  echo "[FAIL] expected nginx conf file: ${CONF_FILE}" >&2
  exit 1
}

grep -q 'try_files $uri $uri/ /index.php?$query_string;' "${CONF_FILE}" || {
  echo "[FAIL] expected front-controller try_files in location /" >&2
  cat "${CONF_FILE}" >&2 || true
  exit 1
}

grep -q 'try_files $uri =404;' "${CONF_FILE}" || {
  echo "[FAIL] expected try_files \$uri =404 in php location" >&2
  cat "${CONF_FILE}" >&2 || true
  exit 1
}

grep -Fq 'fastcgi_split_path_info ^(.+\.php)(/.+)$;' "${CONF_FILE}" || {
  echo "[FAIL] expected fastcgi_split_path_info in php location" >&2
  cat "${CONF_FILE}" >&2 || true
  exit 1
}

grep -q 'fastcgi_param SCRIPT_FILENAME $realpath_root$fastcgi_script_name;' "${CONF_FILE}" || {
  echo "[FAIL] expected SCRIPT_FILENAME with realpath_root" >&2
  cat "${CONF_FILE}" >&2 || true
  exit 1
}

# include fastcgi_params must precede SCRIPT_FILENAME override (Laravel/nginx convention)
if ! awk '
  /include fastcgi_params;/ { inc=1 }
  /fastcgi_param SCRIPT_FILENAME/ { scr=1 }
  END { exit !(inc && scr) }
' "${CONF_FILE}"; then
  echo "[FAIL] expected include fastcgi_params and SCRIPT_FILENAME in php location" >&2
  cat "${CONF_FILE}" >&2 || true
  exit 1
fi

if ! awk '
/location ~ \\.php\$/,/^[[:space:]]*\}/ {
  if (/fastcgi_param SCRIPT_FILENAME/ && !inc) bad=1
  if (/include fastcgi_params;/) inc=1
}
END { exit bad+0 }
' "${CONF_FILE}"; then
  echo "[FAIL] include fastcgi_params should appear before SCRIPT_FILENAME override" >&2
  cat "${CONF_FILE}" >&2 || true
  exit 1
fi

echo "phase11-site-nginx-php-front-controller-smoke:ok"
