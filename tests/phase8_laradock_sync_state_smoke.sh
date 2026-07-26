#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

if ! command -v sqlite3 >/dev/null 2>&1; then
  echo "phase8-laradock-sync-state-smoke:skip (sqlite3 not found)"
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
  nginx: { image: nginx:stable }
  php-fpm: { image: php:8.3-fpm }
  mariadb: { image: mariadb:11 }
  workspace: { image: laradock/workspace:latest }
  phpmyadmin: { image: phpmyadmin/phpmyadmin:latest }
  redis: { image: redis:7 }
  laravel-horizon: { image: laradock/laravel-horizon:latest }
  php-worker: { image: php:8.3-cli }
  apache2: { image: httpd:2.4 }
  caddy: { image: caddy:2 }
  mysql: { image: mysql:8 }
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
          mariadb) ports='{"3306/tcp":[{"HostIp":"0.0.0.0","HostPort":"3306"}]}' ;;
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

if [[ "${1:-}" == "port" ]]; then
  cid="${2:-}"
  port_proto="${3:-}"
  svc="${cid#fake-}"
  svc="${svc%-id}"
  case "${svc}:${port_proto}" in
    nginx:80/tcp) echo "0.0.0.0:80" ;;
    mariadb:3306/tcp) echo "0.0.0.0:3306" ;;
  esac
  exit 0
fi

exit 0
EOF_DOCKER
chmod +x "${BIN_DIR}/docker"

printf '%s\n' "nginx=running" "php-fpm=running" "mariadb=running" > "${DOCKER_STATE}"

BASE_ENV=(
  "HOME=${HOME_DIR}"
  "PATH=${BIN_DIR}:${PATH}"
  "PLUME_STATE_DIR=${STATE_DIR}"
  "PLUME_TEST_DOCKER_STATE=${DOCKER_STATE}"
  "PLUME_TEST_DOCKER_LOG=${DOCKER_LOG}"
)

env "${BASE_ENV[@]}" ./plume.sh mode use laradock-bridge --force --yes >/dev/null
env "${BASE_ENV[@]}" ./plume.sh mode path set laradock-bridge "${LB_PATH}" --force --yes >/dev/null
env "${BASE_ENV[@]}" ./plume.sh sync state --mode=laradock-bridge >/dev/null

RUNTIME_FILE="${STATE_DIR}/services_runtime_laradock-bridge.env"
PORTS_FILE="${STATE_DIR}/services_ports_laradock-bridge.env"

grep -q '^php-fpm.running=true$' "${RUNTIME_FILE}" || {
  echo "[FAIL] expected php-fpm.running=true after laradock sync state" >&2
  cat "${RUNTIME_FILE}" >&2 || true
  exit 1
}

grep -q '^mariadb.running=true$' "${RUNTIME_FILE}" || {
  echo "[FAIL] expected mariadb.running=true after laradock sync state" >&2
  cat "${RUNTIME_FILE}" >&2 || true
  exit 1
}

grep -q '^nginx=80$' "${PORTS_FILE}" || {
  echo "[FAIL] expected nginx=80 after laradock sync state" >&2
  cat "${PORTS_FILE}" >&2 || true
  exit 1
}

grep -q '^mariadb=3306$' "${PORTS_FILE}" || {
  echo "[FAIL] expected mariadb=3306 after laradock sync state" >&2
  cat "${PORTS_FILE}" >&2 || true
  exit 1
}

SERVICE_ROW="$(sqlite3 "${DB_FILE}" "SELECT service||':'||running FROM services WHERE mode='laradock-bridge' AND service='php-fpm' LIMIT 1;")"
[[ "${SERVICE_ROW}" == "php-fpm:true" ]] || {
  echo "[FAIL] expected sqlite services row for laradock php-fpm, got: ${SERVICE_ROW}" >&2
  exit 1
}

EVENT_ROW="$(sqlite3 "${DB_FILE}" "SELECT COUNT(*) FROM runtime_events WHERE mode='laradock-bridge' AND event='sync.state';")"
[[ "${EVENT_ROW}" =~ ^[0-9]+$ ]] || {
  echo "[FAIL] invalid runtime event count: ${EVENT_ROW}" >&2
  exit 1
}
if [[ "${EVENT_ROW}" -lt 1 ]]; then
  echo "[FAIL] expected at least one laradock sync.state event" >&2
  exit 1
fi

echo "phase8-laradock-sync-state-smoke:ok"
