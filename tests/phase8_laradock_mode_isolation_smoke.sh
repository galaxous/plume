#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

TMP_ROOT="$(mktemp -d)"
BIN_DIR="${TMP_ROOT}/bin"
STATE_DIR="${TMP_ROOT}/state"
HOME_DIR="${TMP_ROOT}/home"
DOCKER_STATE="${TMP_ROOT}/docker-state.env"
LB_PATH="${TMP_ROOT}/laradock"
mkdir -p "${BIN_DIR}" "${STATE_DIR}" "${HOME_DIR}" "${LB_PATH}"

cleanup() {
  rm -rf "${TMP_ROOT}"
}
trap cleanup EXIT

cat > "${LB_PATH}/docker-compose.yml" <<'YAML'
services:
  nginx: { image: nginx:stable }
  apache2: { image: httpd:2.4 }
  caddy: { image: caddy:2 }
  php-fpm: { image: php:8.3-fpm }
  mariadb: { image: mariadb:11 }
  workspace: { image: laradock/workspace:latest }
  phpmyadmin: { image: phpmyadmin/phpmyadmin:latest }
  redis: { image: redis:7 }
  laravel-horizon: { image: laradock/laravel-horizon:latest }
  php-worker: { image: php:8.3-cli }
  mysql: { image: mysql:8 }
  docker-in-docker: { image: docker:stable-dind }
YAML

cat > "${LB_PATH}/.env" <<'EOF_ENV'
APP_CODE_PATH_HOST=../apps
APP_CODE_PATH_CONTAINER=/var/www
EOF_ENV

cat > "${BIN_DIR}/docker" <<'EOF_DOCKER'
#!/usr/bin/env bash
set -euo pipefail

STATE_FILE="${PLUME_TEST_DOCKER_STATE}"
touch "${STATE_FILE}"

is_running() {
  local svc="$1"
  grep -q "^${svc}=running$" "${STATE_FILE}" 2>/dev/null
}

set_running() {
  local svc="$1"
  grep -v "^${svc}=running$" "${STATE_FILE}" > "${STATE_FILE}.tmp" 2>/dev/null || true
  mv "${STATE_FILE}.tmp" "${STATE_FILE}"
  printf '%s=running\n' "${svc}" >> "${STATE_FILE}"
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
      set_running "${svc}"
      exit 0
      ;;
    ps)
      shift
      if [[ "${1:-}" == "-q" ]]; then
        shift
        svc="${1:-}"
        if [[ -n "${svc}" ]]; then
          if is_running "${svc}"; then
            echo "fake-${svc}-id"
          fi
        else
          while IFS='=' read -r running_svc state; do
            [[ "${state}" == "running" ]] || continue
            echo "fake-${running_svc}-id"
          done < "${STATE_FILE}"
        fi
        exit 0
      fi
      echo "NAME STATUS"
      exit 0
      ;;
  esac
fi

if [[ "${1:-}" == "inspect" && "${2:-}" == "-f" ]]; then
  format="${3:-}"
  shift 3
  for cid in "$@"; do
    svc="${cid#fake-}"
    svc="${svc%-id}"
    case "${format}" in
      *".Id"*".NetworkSettings.Ports"*)
        ports="null"
        case "${svc}" in
          nginx) ports='{"80/tcp":[{"HostIp":"0.0.0.0","HostPort":"80"}]}' ;;
        esac
        if is_running "${svc}"; then
          echo "${cid}|${svc}|true|healthy|${ports}"
        else
          echo "${cid}|${svc}|false||${ports}"
        fi
        ;;
      *".State.Running"*)
        if is_running "${svc}"; then
          echo "true"
        else
          echo "false"
        fi
        ;;
      *".State.Health"*)
        if is_running "${svc}"; then
          echo "healthy"
        else
          echo ""
        fi
        ;;
    esac
  done
  exit 0
fi

exit 0
EOF_DOCKER
chmod +x "${BIN_DIR}/docker"

printf '%s\n' "nginx=running" "php-fpm=running" > "${DOCKER_STATE}"

BASE_ENV=(
  "HOME=${HOME_DIR}"
  "PATH=${BIN_DIR}:${PATH}"
  "PLUME_STATE_DIR=${STATE_DIR}"
  "PLUME_TEST_DOCKER_STATE=${DOCKER_STATE}"
  "PLUME_WEB_SERVER_ENABLED=false"
  "PLUME_PHP_ENABLED=false"
  "PLUME_MARIADB_ENABLED=false"
)

env "${BASE_ENV[@]}" ./plume.sh mode use laradock-bridge --force --yes >/dev/null
env "${BASE_ENV[@]}" ./plume.sh mode path set laradock-bridge "${LB_PATH}" --force --yes >/dev/null

STATUS_OUT="$(env "${BASE_ENV[@]}" ./plume.sh services status --mode=laradock-bridge)"

printf '%s\n' "${STATUS_OUT}" | grep -q '^MODE              laradock-bridge$' || {
  echo "[FAIL] expected mode header in laradock status" >&2
  printf '%s\n' "${STATUS_OUT}" >&2
  exit 1
}

printf '%s\n' "${STATUS_OUT}" | grep -Eq '^nginx[[:space:]]+true[[:space:]]+true[[:space:]]+healthy' || {
  echo "[FAIL] expected nginx enabled/running from laradock compose, independent of env toggle" >&2
  printf '%s\n' "${STATUS_OUT}" >&2
  exit 1
}

printf '%s\n' "${STATUS_OUT}" | grep -Eq '^php-fpm[[:space:]]+true[[:space:]]+true[[:space:]]+healthy' || {
  echo "[FAIL] expected php-fpm enabled/running from laradock compose, independent of env toggle" >&2
  printf '%s\n' "${STATUS_OUT}" >&2
  exit 1
}

printf '%s\n' "${STATUS_OUT}" | grep -Eq '^apache2[[:space:]]+true[[:space:]]+false[[:space:]]+stopped' || {
  echo "[FAIL] expected apache2 to be enabled when present in laradock compose" >&2
  printf '%s\n' "${STATUS_OUT}" >&2
  exit 1
}

printf '%s\n' "${STATUS_OUT}" | grep -Eq '^docker-in-docker[[:space:]]+true[[:space:]]+false[[:space:]]+stopped' || {
  echo "[FAIL] expected docker-in-docker to be listed from laradock compose" >&2
  printf '%s\n' "${STATUS_OUT}" >&2
  exit 1
}

env "${BASE_ENV[@]}" ./plume.sh services up docker-in-docker --mode=laradock-bridge >/dev/null

STATUS_OUT_2="$(env "${BASE_ENV[@]}" ./plume.sh services status --mode=laradock-bridge)"
printf '%s\n' "${STATUS_OUT_2}" | grep -Eq '^docker-in-docker[[:space:]]+true[[:space:]]+true[[:space:]]+healthy' || {
  echo "[FAIL] expected docker-in-docker to be manageable as raw laradock compose service" >&2
  printf '%s\n' "${STATUS_OUT_2}" >&2
  exit 1
}

echo "phase8-laradock-mode-isolation-smoke:ok"
