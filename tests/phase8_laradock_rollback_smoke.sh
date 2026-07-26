#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

if ! command -v sqlite3 >/dev/null 2>&1; then
  echo "phase8-laradock-rollback-smoke:skip (sqlite3 not found)"
  exit 0
fi

TMP_ROOT="$(mktemp -d)"
BIN_DIR="${TMP_ROOT}/bin"
STATE_DIR="${TMP_ROOT}/state"
HOME_DIR="${TMP_ROOT}/home"
DOCKER_LOG="${TMP_ROOT}/docker.log"
LB_PATH="${TMP_ROOT}/laradock"
mkdir -p "${BIN_DIR}" "${STATE_DIR}" "${HOME_DIR}" "${LB_PATH}"

cleanup() {
  rm -rf "${TMP_ROOT}"
}
trap cleanup EXIT

cat > "${LB_PATH}/docker-compose.yml" <<'YAML'
services:
  mariadb: { image: mariadb:11 }
  php-fpm: { image: php:8.3-fpm }
  nginx:
    image: nginx:stable
    depends_on:
      - php-fpm
YAML

cat > "${LB_PATH}/.env" <<'EOF_ENV'
APP_CODE_PATH_HOST=../apps
APP_CODE_PATH_CONTAINER=/var/www
EOF_ENV

cat > "${BIN_DIR}/docker" <<'EOF_DOCKER'
#!/usr/bin/env bash
set -euo pipefail

LOG_FILE="${PLUME_TEST_DOCKER_LOG}"
touch "${LOG_FILE}"

record() {
  printf '%s\n' "$*" >> "${LOG_FILE}"
}

if [[ "${1:-}" == "compose" ]]; then
  shift
  if [[ "${1:-}" == "-f" ]]; then
    shift 2
  fi
  case "${1:-}" in
    version)
      echo "Docker Compose version v2.26.0"
      exit 0
      ;;
    up)
      shift
      if [[ "${1:-}" == "-d" ]]; then
        shift
      fi
      svc="${1:-}"
      record "compose up ${svc}"
      if [[ "${svc}" == "php-fpm" ]]; then
        exit 42
      fi
      exit 0
      ;;
    stop)
      shift
      svc="${1:-}"
      record "compose stop ${svc}"
      exit 0
      ;;
    ps)
      exit 0
      ;;
  esac
fi

exit 0
EOF_DOCKER
chmod +x "${BIN_DIR}/docker"

BASE_ENV=(
  "HOME=${HOME_DIR}"
  "PATH=${BIN_DIR}:${PATH}"
  "PLUME_STATE_DIR=${STATE_DIR}"
  "PLUME_TEST_DOCKER_LOG=${DOCKER_LOG}"
)

env "${BASE_ENV[@]}" ./plume.sh mode use laradock-bridge --force --yes >/dev/null
env "${BASE_ENV[@]}" ./plume.sh mode path set laradock-bridge "${LB_PATH}" --force --yes >/dev/null

env "${BASE_ENV[@]}" ./plume.sh services config add mariadb --mode=laradock-bridge >/dev/null
env "${BASE_ENV[@]}" ./plume.sh services config add nginx --mode=laradock-bridge >/dev/null

set +e
env "${BASE_ENV[@]}" ./plume.sh services up all --mode=laradock-bridge >/dev/null 2>&1
rc=$?
set -e
if [[ "${rc}" -eq 0 ]]; then
  echo "[FAIL] expected services up all to fail for rollback scenario" >&2
  cat "${DOCKER_LOG}" >&2 || true
  exit 1
fi

grep -q 'compose up mariadb' "${DOCKER_LOG}" || {
  echo "[FAIL] expected compose up mariadb before failure" >&2
  cat "${DOCKER_LOG}" >&2 || true
  exit 1
}

grep -q 'compose up php-fpm' "${DOCKER_LOG}" || {
  echo "[FAIL] expected compose up php-fpm to trigger failure" >&2
  cat "${DOCKER_LOG}" >&2 || true
  exit 1
}

grep -q 'compose stop mariadb' "${DOCKER_LOG}" || {
  echo "[FAIL] expected rollback to stop mariadb after php-fpm failure" >&2
  cat "${DOCKER_LOG}" >&2 || true
  exit 1
}

if grep -q 'compose up nginx' "${DOCKER_LOG}"; then
  echo "[FAIL] nginx should not start after php-fpm start failure" >&2
  cat "${DOCKER_LOG}" >&2 || true
  exit 1
fi

echo "phase8-laradock-rollback-smoke:ok"
