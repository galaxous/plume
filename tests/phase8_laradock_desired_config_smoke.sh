#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

if ! command -v sqlite3 >/dev/null 2>&1; then
  echo "phase8-laradock-desired-config-smoke:skip (sqlite3 not found)"
  exit 0
fi

TMP_ROOT="$(mktemp -d)"
BIN_DIR="${TMP_ROOT}/bin"
STATE_DIR="${TMP_ROOT}/state"
HOME_DIR="${TMP_ROOT}/home"
DOCKER_STATE="${TMP_ROOT}/docker-state.env"
DOCKER_LOG="${TMP_ROOT}/docker.log"
LB_PATH="${TMP_ROOT}/laradock"
DB_FILE="${STATE_DIR}/plume-state.db"
mkdir -p "${BIN_DIR}" "${STATE_DIR}" "${HOME_DIR}" "${LB_PATH}"

cleanup() {
  rm -rf "${TMP_ROOT}"
}
trap cleanup EXIT

cat > "${LB_PATH}/docker-compose.yml" <<'YAML'
services:
  workspace: { image: laradock/workspace:latest }
  php-fpm: { image: php:8.3-fpm }
  php-fpm-8.4: { image: php:8.4-fpm }
  php-worker: { image: php:8.3-cli }
  laravel-horizon: { image: laradock/laravel-horizon:latest }
  nginx:
    image: nginx:stable
    depends_on:
      - php-fpm
      - php-fpm-8.4
  mariadb: { image: mariadb:11 }
  redis: { image: redis:7 }
  apache2: { image: httpd:2.4 }
  external-observer: { image: busybox:latest }
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
      for svc in "$@"; do
        [[ -z "${svc}" ]] && continue
        record "compose up ${svc}"
      done
      exit 0
      ;;
    stop)
      shift
      for svc in "$@"; do
        [[ -z "${svc}" ]] && continue
        record "compose stop ${svc}"
      done
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
  "PLUME_TEST_DOCKER_STATE=${DOCKER_STATE}"
  "PLUME_TEST_DOCKER_LOG=${DOCKER_LOG}"
)

env "${BASE_ENV[@]}" ./plume.sh mode use laradock-bridge --force --yes >/dev/null
env "${BASE_ENV[@]}" ./plume.sh mode path set laradock-bridge "${LB_PATH}" --force --yes >/dev/null

env "${BASE_ENV[@]}" ./plume.sh services config add nginx --mode=laradock-bridge >/dev/null
env "${BASE_ENV[@]}" ./plume.sh services config add mariadb --mode=laradock-bridge >/dev/null
env "${BASE_ENV[@]}" ./plume.sh services config add redis --mode=laradock-bridge >/dev/null

# Simulate a non-plume external service already running in laradock project.
echo "compose up external-observer" >> "${DOCKER_LOG}"

CONFIG_OUT="$(env "${BASE_ENV[@]}" ./plume.sh services config show --mode=laradock-bridge)"
printf '%s\n' "${CONFIG_OUT}" | grep -q '^DESIRED_COUNT     ' || {
  echo "[FAIL] expected desired count in config show" >&2
  printf '%s\n' "${CONFIG_OUT}" >&2
  exit 1
}
printf '%s\n' "${CONFIG_OUT}" | grep -Eq '^nginx[[:space:]]+true$' || {
  echo "[FAIL] expected nginx in desired config" >&2
  printf '%s\n' "${CONFIG_OUT}" >&2
  exit 1
}
printf '%s\n' "${CONFIG_OUT}" | grep -Eq '^redis[[:space:]]+true$' || {
  echo "[FAIL] expected redis in desired config" >&2
  printf '%s\n' "${CONFIG_OUT}" >&2
  exit 1
}
printf '%s\n' "${CONFIG_OUT}" | grep -Eq '^php-fpm[[:space:]]+true$' || {
  echo "[FAIL] expected php-fpm in resolved config" >&2
  printf '%s\n' "${CONFIG_OUT}" >&2
  exit 1
}
printf '%s\n' "${CONFIG_OUT}" | grep -Eq '^php-fpm-8.4[[:space:]]+true$' || {
  echo "[FAIL] expected php-fpm-8.4 in resolved config" >&2
  printf '%s\n' "${CONFIG_OUT}" >&2
  exit 1
}

env "${BASE_ENV[@]}" ./plume.sh services up all --mode=laradock-bridge >/dev/null
grep -q 'compose up php-fpm' "${DOCKER_LOG}" || {
  echo "[FAIL] expected php-fpm from resolved config on services up all" >&2
  cat "${DOCKER_LOG}" >&2
  exit 1
}
grep -q 'compose up php-fpm-8.4' "${DOCKER_LOG}" || {
  echo "[FAIL] expected php-fpm-8.4 from resolved config on services up all" >&2
  cat "${DOCKER_LOG}" >&2
  exit 1
}

up_mariadb_line="$(grep -n 'compose up mariadb' "${DOCKER_LOG}" | head -n1 | cut -d: -f1)"
up_php_line="$(grep -n 'compose up php-fpm' "${DOCKER_LOG}" | head -n1 | cut -d: -f1)"
up_nginx_line="$(grep -n 'compose up nginx' "${DOCKER_LOG}" | head -n1 | cut -d: -f1)"
if [[ -n "${up_mariadb_line}" && -n "${up_php_line}" && -n "${up_nginx_line}" ]]; then
  if (( up_mariadb_line >= up_php_line )) || (( up_php_line >= up_nginx_line )); then
    echo "[FAIL] expected safe up ordering (db -> php -> web) for laradock up all" >&2
    cat "${DOCKER_LOG}" >&2
    exit 1
  fi
fi
grep -q 'compose up redis' "${DOCKER_LOG}" || {
  echo "[FAIL] expected redis from desired config on services up all" >&2
  cat "${DOCKER_LOG}" >&2
  exit 1
}
if grep -q 'compose up apache2' "${DOCKER_LOG}"; then
  echo "[FAIL] apache2 should not start when not in desired config" >&2
  cat "${DOCKER_LOG}" >&2
  exit 1
fi

env "${BASE_ENV[@]}" ./plume.sh services config remove redis --mode=laradock-bridge >/dev/null
env "${BASE_ENV[@]}" ./plume.sh services down all --mode=laradock-bridge >/dev/null
if grep -q 'compose stop redis' "${DOCKER_LOG}"; then
  echo "[FAIL] redis should not stop after being removed from desired config" >&2
  cat "${DOCKER_LOG}" >&2
  exit 1
fi
grep -q 'compose stop php-fpm' "${DOCKER_LOG}" || {
  echo "[FAIL] expected php-fpm stop from resolved config on services down all" >&2
  cat "${DOCKER_LOG}" >&2
  exit 1
}
grep -q 'compose stop php-fpm-8.4' "${DOCKER_LOG}" || {
  echo "[FAIL] expected php-fpm-8.4 stop from resolved config on services down all" >&2
  cat "${DOCKER_LOG}" >&2
  exit 1
}
if grep -q 'compose stop external-observer' "${DOCKER_LOG}"; then
  echo "[FAIL] down all should not stop non-desired external service" >&2
  cat "${DOCKER_LOG}" >&2
  exit 1
fi

down_nginx_line="$(grep -n 'compose stop nginx' "${DOCKER_LOG}" | head -n1 | cut -d: -f1)"
down_php_line="$(grep -n 'compose stop php-fpm' "${DOCKER_LOG}" | head -n1 | cut -d: -f1)"
down_mariadb_line="$(grep -n 'compose stop mariadb' "${DOCKER_LOG}" | head -n1 | cut -d: -f1)"
if [[ -n "${down_nginx_line}" && -n "${down_php_line}" && -n "${down_mariadb_line}" ]]; then
  if (( down_nginx_line >= down_php_line )) || (( down_php_line >= down_mariadb_line )); then
    echo "[FAIL] expected safe down ordering (web -> php -> db) for laradock down all" >&2
    cat "${DOCKER_LOG}" >&2
    exit 1
  fi
fi

DB_ROWS="$(sqlite3 "${DB_FILE}" "SELECT COUNT(*) FROM desired_services WHERE mode='laradock-bridge' AND path='${LB_PATH}';")"
[[ "${DB_ROWS}" =~ ^[0-9]+$ ]] || {
  echo "[FAIL] expected desired_services rows in sqlite db" >&2
  sqlite3 "${DB_FILE}" "SELECT * FROM desired_services;" >&2 || true
  exit 1
}

echo "phase8-laradock-desired-config-smoke:ok"
