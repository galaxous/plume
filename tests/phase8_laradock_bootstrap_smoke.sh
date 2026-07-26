#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

TMP_ROOT="$(mktemp -d)"
BIN_DIR="${TMP_ROOT}/bin"
STATE_DIR="${TMP_ROOT}/state"
HOME_DIR="${TMP_ROOT}/home"
SITE_REGISTRY="${TMP_ROOT}/sites"
SRC_DIR="${TMP_ROOT}/laradock-src"
TARGET_DIR="${TMP_ROOT}/laradock-target"
mkdir -p "${BIN_DIR}" "${STATE_DIR}" "${HOME_DIR}" "${SITE_REGISTRY}" "${SRC_DIR}" "${TMP_ROOT}/apps"

cleanup() {
  rm -rf "${TMP_ROOT}"
}
trap cleanup EXIT

cat > "${SRC_DIR}/docker-compose.yml" <<'YAML'
services:
  nginx: { image: nginx:stable }
  apache2: { image: httpd:2.4 }
  caddy: { image: caddy:2 }
  mariadb: { image: mariadb:11 }
  mysql: { image: mysql:8 }
  phpmyadmin: { image: phpmyadmin/phpmyadmin:latest }
  php-fpm: { image: php:8.3-fpm }
  redis: { image: redis:7 }
  laravel-horizon: { image: laradock/laravel-horizon:latest }
  php-worker: { image: php:8.3-cli }
  workspace: { image: laradock/workspace:latest }
YAML

cat > "${SRC_DIR}/.env.example" <<'EOF_ENV'
APP_CODE_PATH_HOST=../apps
APP_CODE_PATH_CONTAINER=/var/www
APP_CODE_CONTAINER_FLAG=:cached
DATA_PATH_HOST=~/.laradock/data
COMPOSE_PROJECT_NAME=laradock
EOF_ENV

cat > "${BIN_DIR}/git" <<'EOF_GIT'
#!/usr/bin/env bash
set -euo pipefail
if [[ "${1:-}" == "clone" ]]; then
  path="${@: -1}"
  mkdir -p "${path}"
  cp -R "${PLUME_TEST_LARADOCK_SOURCE}/." "${path}/"
  mkdir -p "${path}/.git"
  exit 0
fi
if [[ "${1:-}" == "-C" ]]; then
  repo_path="${2:-}"
  shift 2
  case "${1:-}" in
    rev-parse)
      echo "master"
      exit 0
      ;;
    remote|fetch|checkout|pull)
      exit 0
      ;;
  esac
fi
exit 0
EOF_GIT
chmod +x "${BIN_DIR}/git"

BASE_ENV=(
  "PATH=${BIN_DIR}:${PATH}"
  "HOME=${HOME_DIR}"
  "PLUME_STATE_DIR=${STATE_DIR}"
  "PLUME_SITE_REGISTRY_DIR=${SITE_REGISTRY}"
  "PLUME_TEST_LARADOCK_SOURCE=${SRC_DIR}"
)

env "${BASE_ENV[@]}" ./plume.sh mode use laradock-bridge --force --yes >/dev/null
env "${BASE_ENV[@]}" ./plume.sh services laradock init --mode=laradock-bridge --path="${TARGET_DIR}" >/dev/null

env "${BASE_ENV[@]}" ./plume.sh mode path get laradock-bridge | grep -q "${TARGET_DIR}" || {
  echo "[FAIL] laradock mode path not set" >&2
  exit 1
}

[[ -f "${TARGET_DIR}/.env" ]] || {
  echo "[FAIL] .env should be created from .env.example" >&2
  exit 1
}

PROJECT_PATH="${TMP_ROOT}/apps/demo"
mkdir -p "${PROJECT_PATH}/public"
SITE_ID="$(env "${BASE_ENV[@]}" PLUME_SITE_HOSTS_SYNC=false ./plume.sh site add --mode=laradock-bridge --path="${PROJECT_PATH}" --domain="bridge-demo.test" --server=nginx --port=18081)"
[[ -n "${SITE_ID}" ]] || {
  echo "[FAIL] could not create laradock-bridge site record" >&2
  exit 1
}

env "${BASE_ENV[@]}" ./plume.sh services laradock check --mode=laradock-bridge --path="${TARGET_DIR}" >/dev/null || {
  echo "[FAIL] laradock check should pass" >&2
  exit 1
}

env "${BASE_ENV[@]}" ./plume.sh services laradock sync --mode=laradock-bridge --path="${TARGET_DIR}" >/dev/null || {
  echo "[FAIL] laradock sync should pass" >&2
  exit 1
}

echo "phase8-laradock-bootstrap-smoke:ok"
