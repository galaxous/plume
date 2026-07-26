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
  workspace: { image: laradock/workspace:latest }
  php-fpm: { image: php:8.3-fpm }
  php-worker: { image: php:8.3-cli }
  laravel-horizon: { image: laradock/laravel-horizon:latest }
  nginx: { image: nginx:stable }
  apache2: { image: httpd:2.4 }
  caddy: { image: caddy:2 }
  mariadb: { image: mariadb:11 }
  redis: { image: redis:7 }
YAML

cat > "${LB_PATH}/.env" <<'EOF_ENV'
APP_CODE_PATH_HOST=../apps
APP_CODE_PATH_CONTAINER=/var/www
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
        set_running "${svc}"
      done
      exit 0
      ;;
    stop)
      shift
      for svc in "$@"; do
        [[ -z "${svc}" ]] && continue
        record "compose stop ${svc}"
        clear_running "${svc}"
      done
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
    logs)
      shift
      if [[ "${1:-}" == "-f" ]]; then
        shift
      fi
      if [[ "${1:-}" == "--tail" ]]; then
        shift 2
      fi
      record "compose logs $*"
      for svc in "$@"; do
        echo "${svc}: simulated log"
      done
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
          apache2) ports='{"80/tcp":[{"HostIp":"0.0.0.0","HostPort":"8080"}]}' ;;
          caddy) ports='{"80/tcp":[{"HostIp":"0.0.0.0","HostPort":"8081"}]}' ;;
          mariadb) ports='{"3306/tcp":[{"HostIp":"0.0.0.0","HostPort":"3306"}]}' ;;
          redis) ports='{"6379/tcp":[{"HostIp":"0.0.0.0","HostPort":"6379"}]}' ;;
        esac
        if is_running "${svc}"; then
          echo "${cid}|${svc}|true|healthy|${ports}"
        else
          echo "${cid}|${svc}|false||${ports}"
        fi
        ;;
      *)
        ;;
    esac
  done
  exit 0
fi

exit 0
EOF_DOCKER
chmod +x "${BIN_DIR}/docker"

printf '%s\n' "nginx=running" "redis=running" > "${DOCKER_STATE}"

BASE_ENV=(
  "HOME=${HOME_DIR}"
  "PATH=${BIN_DIR}:${PATH}"
  "PLUME_STATE_DIR=${STATE_DIR}"
  "PLUME_TEST_DOCKER_STATE=${DOCKER_STATE}"
  "PLUME_TEST_DOCKER_LOG=${DOCKER_LOG}"
)

env "${BASE_ENV[@]}" ./plume.sh mode use laradock-bridge --force --yes >/dev/null
env "${BASE_ENV[@]}" ./plume.sh mode path set laradock-bridge "${LB_PATH}" --force --yes >/dev/null

SUPPORTED_OUT="$(env "${BASE_ENV[@]}" ./plume.sh services supported --mode=laradock-bridge)"
printf '%s\n' "${SUPPORTED_OUT}" | grep -Eq '^@core[[:space:]]+' || {
  echo "[FAIL] expected @core group in services supported" >&2
  printf '%s\n' "${SUPPORTED_OUT}" >&2
  exit 1
}
printf '%s\n' "${SUPPORTED_OUT}" | grep -Eq '^@web[[:space:]]+.*nginx.*apache2.*caddy' || {
  echo "[FAIL] expected @web group members in services supported" >&2
  printf '%s\n' "${SUPPORTED_OUT}" >&2
  exit 1
}

HEALTH_OUT="$(env "${BASE_ENV[@]}" ./plume.sh services health @web --mode=laradock-bridge)"
printf '%s\n' "${HEALTH_OUT}" | grep -q '^GROUP             @web$' || {
  echo "[FAIL] expected group header for services health @web" >&2
  printf '%s\n' "${HEALTH_OUT}" >&2
  exit 1
}
printf '%s\n' "${HEALTH_OUT}" | grep -Eq '^nginx[[:space:]]+healthy$' || {
  echo "[FAIL] expected nginx healthy in @web health output" >&2
  printf '%s\n' "${HEALTH_OUT}" >&2
  exit 1
}

STATUS_OUT="$(env "${BASE_ENV[@]}" ./plume.sh services status @web --mode=laradock-bridge)"
printf '%s\n' "${STATUS_OUT}" | grep -q '^GROUP             @web$' || {
  echo "[FAIL] expected group header for services status @web" >&2
  printf '%s\n' "${STATUS_OUT}" >&2
  exit 1
}

LOGS_OUT="$(env "${BASE_ENV[@]}" ./plume.sh services logs @web --mode=laradock-bridge --running --tail=5)"
printf '%s\n' "${LOGS_OUT}" | grep -q 'nginx: simulated log' || {
  echo "[FAIL] expected nginx log in @web running logs output" >&2
  printf '%s\n' "${LOGS_OUT}" >&2
  exit 1
}
if printf '%s\n' "${LOGS_OUT}" | grep -q 'apache2: simulated log'; then
  echo "[FAIL] did not expect apache2 log in @web running logs output" >&2
  printf '%s\n' "${LOGS_OUT}" >&2
  exit 1
fi
grep -q 'compose logs nginx' "${DOCKER_LOG}" || {
  echo "[FAIL] expected compose logs nginx call for @web running logs" >&2
  cat "${DOCKER_LOG}" >&2
  exit 1
}
printf '%s\n' "${STATUS_OUT}" | grep -Eq '^nginx[[:space:]]+true[[:space:]]+true[[:space:]]+healthy[[:space:]]+80' || {
  echo "[FAIL] expected nginx status in @web status output" >&2
  printf '%s\n' "${STATUS_OUT}" >&2
  exit 1
}
printf '%s\n' "${STATUS_OUT}" | grep -Eq '^apache2[[:space:]]+true[[:space:]]+false[[:space:]]+stopped' || {
  echo "[FAIL] expected apache2 status in @web status output" >&2
  printf '%s\n' "${STATUS_OUT}" >&2
  exit 1
}

env "${BASE_ENV[@]}" ./plume.sh services up @queue --mode=laradock-bridge >/dev/null
grep -q 'compose up php-worker' "${DOCKER_LOG}" || {
  echo "[FAIL] expected php-worker to start from @queue group" >&2
  cat "${DOCKER_LOG}" >&2
  exit 1
}
grep -q 'compose up laravel-horizon' "${DOCKER_LOG}" || {
  echo "[FAIL] expected laravel-horizon to start from @queue group" >&2
  cat "${DOCKER_LOG}" >&2
  exit 1
}

env "${BASE_ENV[@]}" ./plume.sh services down @queue --mode=laradock-bridge >/dev/null
grep -q 'compose stop php-worker' "${DOCKER_LOG}" || {
  echo "[FAIL] expected php-worker to stop from @queue group" >&2
  cat "${DOCKER_LOG}" >&2
  exit 1
}
grep -q 'compose stop laravel-horizon' "${DOCKER_LOG}" || {
  echo "[FAIL] expected laravel-horizon to stop from @queue group" >&2
  cat "${DOCKER_LOG}" >&2
  exit 1
}

echo "phase8-laradock-groups-smoke:ok"
