#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

TMP_ROOT="$(mktemp -d)"
BIN_DIR="${TMP_ROOT}/bin"
STATE_DIR="${TMP_ROOT}/state"
DL_PATH="${TMP_ROOT}/docker-lite"
DOCKER_LOG="${TMP_ROOT}/docker.log"
RUN_MARKER="${TMP_ROOT}/running.marker"
mkdir -p "${BIN_DIR}" "${STATE_DIR}" "${DL_PATH}"

cleanup() {
  rm -rf "${TMP_ROOT}"
}
trap cleanup EXIT

cat > "${DL_PATH}/docker-compose.yml" <<'YAML'
services:
  workspace:
    image: composer:2
  php-fpm:
    image: php:8.4-fpm
  php81-fpm:
    image: php:8.1-fpm
  php82-fpm:
    image: php:8.2-fpm
YAML

cat > "${DL_PATH}/.env.docker-lite" <<'EOF_ENV'
PLUME_PHP_DEFAULT_VERSION=8.4
PLUME_PHP_INSTALLED_VERSIONS=8.1
EOF_ENV

cat > "${BIN_DIR}/docker" <<'EOF_DOCKER'
#!/usr/bin/env bash
set -euo pipefail
echo "$*" >> "${PLUME_TEST_DOCKER_LOG}"
if [[ "${1:-}" == "compose" ]]; then
  shift
  if [[ "${1:-}" == "-f" ]]; then
    shift 2
  fi
  while [[ "${1:-}" == "--profile" ]]; do
    shift 2
  done
  case "${1:-}" in
    version) exit 0 ;;
    config)
      shift
      if [[ "${1:-}" == "--images" ]]; then
        echo "composer:2"
        echo "php:8.4-fpm"
        echo "php:8.1-fpm"
        echo "php:8.2-fpm"
      fi
      exit 0
      ;;
    ps)
      shift
      if [[ "${1:-}" == "-q" && -f "${PLUME_TEST_RUN_MARKER}" ]]; then
        echo "cid-123"
      fi
      exit 0
      ;;
    up)
      touch "${PLUME_TEST_RUN_MARKER}"
      exit 0
      ;;
    rm|pull|down|stop)
      exit 0
      ;;
  esac
fi
if [[ "${1:-}" == "image" && "${2:-}" == "inspect" ]]; then
  exit 0
fi
exit 0
EOF_DOCKER
chmod +x "${BIN_DIR}/docker"

BASE_ENV=(
  "PATH=${BIN_DIR}:${PATH}"
  "PLUME_STATE_DIR=${STATE_DIR}"
  "PLUME_TEST_DOCKER_LOG=${DOCKER_LOG}"
  "PLUME_TEST_RUN_MARKER=${RUN_MARKER}"
  "PLUME_DOCKER_LITE_COMPOSE_REQUIRED=true"
)

env "${BASE_ENV[@]}" ./plume.sh mode use docker-lite >/dev/null
env "${BASE_ENV[@]}" ./plume.sh mode path set "${DL_PATH}" >/dev/null

env "${BASE_ENV[@]}" ./plume.sh services workspace apply --mode=docker-lite >/dev/null

grep -Eq "compose -f ${DL_PATH}/docker-compose.yml up -d php-fpm php81-fpm|compose -f ${DL_PATH}/docker-compose.yml up -d php81-fpm php-fpm" "${DOCKER_LOG}" || {
  echo "[FAIL] expected php matrix up for php-fpm+php81-fpm" >&2
  cat "${DOCKER_LOG}" >&2 || true
  exit 1
}

cat > "${DL_PATH}/.env.docker-lite" <<'EOF_ENV2'
PLUME_PHP_DEFAULT_VERSION=8.4
PLUME_PHP_INSTALLED_VERSIONS=8.2
EOF_ENV2

env "${BASE_ENV[@]}" ./plume.sh services workspace apply --mode=docker-lite >/dev/null

grep -Eq "compose -f ${DL_PATH}/docker-compose.yml up -d --force-recreate --build php-fpm php82-fpm|compose -f ${DL_PATH}/docker-compose.yml up -d --force-recreate --build php82-fpm php-fpm" "${DOCKER_LOG}" || {
  echo "[FAIL] expected php matrix build reconcile for php-fpm+php82-fpm" >&2
  cat "${DOCKER_LOG}" >&2 || true
  exit 1
}

grep -q "compose -f ${DL_PATH}/docker-compose.yml rm -f -s php81-fpm" "${DOCKER_LOG}" || {
  echo "[FAIL] expected obsolete php81-fpm removal" >&2
  cat "${DOCKER_LOG}" >&2 || true
  exit 1
}

echo "phase7-workspace-php-matrix-reconcile-smoke:ok"
