#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

TMP_ROOT="$(mktemp -d)"
BIN_DIR="${TMP_ROOT}/bin"
STATE_DIR="${TMP_ROOT}/state"
HOME_DIR="${TMP_ROOT}/home"
DOCKER_STATE="${TMP_ROOT}/docker-state.env"
DOCKER_LOG="${TMP_ROOT}/docker.log"
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
  mariadb: { image: mariadb:11 }
  mysql: { image: mysql:8 }
  phpmyadmin: { image: phpmyadmin/phpmyadmin:latest }
  php-fpm: { image: php:8.3-fpm }
  redis: { image: redis:7 }
  laravel-horizon: { image: laradock/laravel-horizon:latest }
  php-worker: { image: php:8.3-cli }
  workspace: { image: laradock/workspace:latest }
YAML

cat > "${LB_PATH}/.env" <<'EOF_ENV'
APP_CODE_PATH_HOST=../apps
APP_CODE_PATH_CONTAINER=/var/www
COMPOSE_PROJECT_NAME=laradock
EOF_ENV

cat > "${BIN_DIR}/docker" <<'EOF_DOCKER'
#!/usr/bin/env bash
set -euo pipefail

STATE_FILE="${PLUME_TEST_DOCKER_STATE}"
LOG_FILE="${PLUME_TEST_DOCKER_LOG}"

touch "${STATE_FILE}" "${LOG_FILE}"

record() {
  printf '%s\n' "$*" >> "${LOG_FILE}"
}

set_running() {
  local svc="$1"
  grep -v "^${svc}=running$" "${STATE_FILE}" > "${STATE_FILE}.tmp" 2>/dev/null || true
  mv "${STATE_FILE}.tmp" "${STATE_FILE}"
  printf '%s=running\n' "${svc}" >> "${STATE_FILE}"
}

clear_running() {
  local svc="$1"
  grep -v "^${svc}=running$" "${STATE_FILE}" > "${STATE_FILE}.tmp" 2>/dev/null || true
  mv "${STATE_FILE}.tmp" "${STATE_FILE}"
}

is_running() {
  local svc="$1"
  grep -q "^${svc}=running$" "${STATE_FILE}" 2>/dev/null
}

if [[ "${1:-}" == "compose" ]]; then
  shift
  if [[ "${1:-}" == "-f" ]]; then
    shift 2
  fi
  case "${1:-}" in
    version)
      record "compose version"
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
      set_running "${svc}"
      exit 0
      ;;
    stop)
      shift
      svc="${1:-}"
      record "compose stop ${svc}"
      clear_running "${svc}"
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
      record "compose ps ${*}"
      echo "NAME STATUS"
      exit 0
      ;;
    logs)
      shift
      if [[ "${1:-}" == "--tail" ]]; then
        tail_count="${2:-}"
        shift 2
      fi
      svc="${1:-}"
      record "compose logs ${svc}"
      echo "${svc}: simulated log line"
      exit 0
      ;;
    pull)
      shift
      svc="${1:-}"
      record "compose pull ${svc}"
      exit 0
      ;;
  esac
fi

if [[ "${1:-}" == "inspect" ]]; then
  if [[ "${2:-}" == "-f" ]]; then
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
            phpmyadmin) ports='{"80/tcp":[{"HostIp":"0.0.0.0","HostPort":"8081"}]}' ;;
            mariadb) ports='{"3306/tcp":[{"HostIp":"0.0.0.0","HostPort":"3306"}]}' ;;
            mysql) ports='{"3306/tcp":[{"HostIp":"0.0.0.0","HostPort":"3307"}]}' ;;
            redis) ports='{"6379/tcp":[{"HostIp":"0.0.0.0","HostPort":"6379"}]}' ;;
            workspace) ports='{"22/tcp":[{"HostIp":"0.0.0.0","HostPort":"2222"}],"3000/tcp":[{"HostIp":"0.0.0.0","HostPort":"3000"}]}' ;;
          esac
          if is_running "${svc}"; then
            echo "${cid}|${svc}|true|healthy|${ports}"
          else
            echo "${cid}|${svc}|false||${ports}"
          fi
          ;;
        *".State.Health"*)
          if is_running "${svc}"; then
            echo "healthy"
          else
            echo ""
          fi
          ;;
        *".State.Running"*)
          if is_running "${svc}"; then
            echo "true"
          else
            echo "false"
          fi
          ;;
      esac
    done
    exit 0
  fi
fi

if [[ "${1:-}" == "port" ]]; then
  cid="${2:-}"
  port_proto="${3:-}"
  svc="${cid#fake-}"
  svc="${svc%-id}"
  case "${svc}:${port_proto}" in
    nginx:80/tcp) echo "0.0.0.0:80" ;;
    phpmyadmin:80/tcp) echo "0.0.0.0:8081" ;;
    mariadb:3306/tcp) echo "0.0.0.0:3306" ;;
    mysql:3306/tcp) echo "0.0.0.0:3307" ;;
    redis:6379/tcp) echo "0.0.0.0:6379" ;;
    workspace:22/tcp) echo "0.0.0.0:2222" ;;
    workspace:3000/tcp) echo "0.0.0.0:3000" ;;
  esac
  exit 0
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

env "${BASE_ENV[@]}" ./plume.sh services up php --mode=laradock-bridge >/dev/null
env "${BASE_ENV[@]}" ./plume.sh services up composer --mode=laradock-bridge >/dev/null

grep -q "compose up php-fpm" "${DOCKER_LOG}" || {
  echo "[FAIL] laradock up php did not run compose up php-fpm" >&2
  cat "${DOCKER_LOG}" >&2 || true
  exit 1
}

grep -q "compose up workspace" "${DOCKER_LOG}" || {
  echo "[FAIL] laradock up composer did not run compose up workspace" >&2
  cat "${DOCKER_LOG}" >&2 || true
  exit 1
}

STATUS_OUT="$(env "${BASE_ENV[@]}" ./plume.sh services status --mode=laradock-bridge)"
printf '%s\n' "${STATUS_OUT}" | grep -Eq '^php-fpm[[:space:]]+true[[:space:]]+true[[:space:]]+healthy' || {
  echo "[FAIL] laradock status did not report php-fpm healthy/running" >&2
  printf '%s\n' "${STATUS_OUT}" >&2
  exit 1
}

printf '%s\n' "${STATUS_OUT}" | grep -Eq '^workspace[[:space:]]+true[[:space:]]+true[[:space:]]+healthy[[:space:]]+2222,3000' || {
  echo "[FAIL] laradock status did not show workspace exposed ports" >&2
  printf '%s\n' "${STATUS_OUT}" >&2
  exit 1
}

RUNNING_OUT="$(env "${BASE_ENV[@]}" ./plume.sh services status --mode=laradock-bridge --running)"
printf '%s\n' "${RUNNING_OUT}" | grep -Eq '^php-fpm[[:space:]]+true[[:space:]]+true[[:space:]]+healthy' || {
  echo "[FAIL] running-only status did not include running php-fpm" >&2
  printf '%s\n' "${RUNNING_OUT}" >&2
  exit 1
}

printf '%s\n' "${RUNNING_OUT}" | grep -Eq '^workspace[[:space:]]+true[[:space:]]+true[[:space:]]+healthy' || {
  echo "[FAIL] running-only status did not include running workspace" >&2
  printf '%s\n' "${RUNNING_OUT}" >&2
  exit 1
}

if printf '%s\n' "${RUNNING_OUT}" | grep -Eq '^nginx[[:space:]]'; then
  echo "[FAIL] running-only status unexpectedly included stopped nginx" >&2
  printf '%s\n' "${RUNNING_OUT}" >&2
  exit 1
fi

HEALTH_OUT="$(env "${BASE_ENV[@]}" ./plume.sh services health php --mode=laradock-bridge)"
printf '%s\n' "${HEALTH_OUT}" | grep -q "healthy" || {
  echo "[FAIL] laradock health did not report php healthy" >&2
  printf '%s\n' "${HEALTH_OUT}" >&2
  exit 1
}

HEALTH_RUNNING_OUT="$(env "${BASE_ENV[@]}" ./plume.sh services health --mode=laradock-bridge --running)"
printf '%s\n' "${HEALTH_RUNNING_OUT}" | grep -Eq '^php-fpm[[:space:]]+healthy' || {
  echo "[FAIL] running-only health did not include running php-fpm" >&2
  printf '%s\n' "${HEALTH_RUNNING_OUT}" >&2
  exit 1
}

printf '%s\n' "${HEALTH_RUNNING_OUT}" | grep -Eq '^workspace[[:space:]]+healthy' || {
  echo "[FAIL] running-only health did not include running workspace" >&2
  printf '%s\n' "${HEALTH_RUNNING_OUT}" >&2
  exit 1
}

if printf '%s\n' "${HEALTH_RUNNING_OUT}" | grep -Eq '^nginx[[:space:]]'; then
  echo "[FAIL] running-only health unexpectedly included stopped nginx" >&2
  printf '%s\n' "${HEALTH_RUNNING_OUT}" >&2
  exit 1
fi

LOGS_OUT="$(env "${BASE_ENV[@]}" ./plume.sh services logs php --mode=laradock-bridge --tail=10)"
printf '%s\n' "${LOGS_OUT}" | grep -q "simulated log line" || {
  echo "[FAIL] laradock logs did not stream compose logs" >&2
  printf '%s\n' "${LOGS_OUT}" >&2
  exit 1
}

env "${BASE_ENV[@]}" ./plume.sh services down php --mode=laradock-bridge >/dev/null
env "${BASE_ENV[@]}" ./plume.sh services down composer --mode=laradock-bridge >/dev/null

grep -q "compose stop php-fpm" "${DOCKER_LOG}" || {
  echo "[FAIL] laradock down php did not run compose stop php-fpm" >&2
  cat "${DOCKER_LOG}" >&2 || true
  exit 1
}

grep -q "compose stop workspace" "${DOCKER_LOG}" || {
  echo "[FAIL] laradock down composer did not run compose stop workspace" >&2
  cat "${DOCKER_LOG}" >&2 || true
  exit 1
}

STATUS_AFTER="$(env "${BASE_ENV[@]}" ./plume.sh services status --mode=laradock-bridge)"
printf '%s\n' "${STATUS_AFTER}" | grep -Eq '^php-fpm[[:space:]]+true[[:space:]]+false[[:space:]]+stopped' || {
  echo "[FAIL] laradock status after down did not report php-fpm stopped" >&2
  printf '%s\n' "${STATUS_AFTER}" >&2
  exit 1
}

echo "phase8-laradock-runtime-smoke:ok"
