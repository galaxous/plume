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
version: '3.5'

services:

### Workspace Utilities ##################################
  workspace:
    build:
      context: ./workspace
      args:
        - PHP_VERSION=8.3
    ports:
      - "3000:3000"

### PHP-FPM ##############################################
  php-fpm:
    build:
      context: ./php-fpm
      args:
        - PHP_VERSION=8.3

  nginx:
    image: nginx:stable
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
        if is_running "${svc}"; then
          echo "fake-${svc}-id"
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
        if is_running "${svc}"; then
          echo "${cid}|${svc}|true|healthy|null"
        else
          echo "${cid}|${svc}|false||null"
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

printf '%s\n' "workspace=running" "php-fpm=running" "nginx=running" > "${DOCKER_STATE}"

BASE_ENV=(
  "HOME=${HOME_DIR}"
  "PATH=${BIN_DIR}:${PATH}"
  "PLUME_STATE_DIR=${STATE_DIR}"
  "PLUME_TEST_DOCKER_STATE=${DOCKER_STATE}"
)

env "${BASE_ENV[@]}" ./plume.sh mode use laradock-bridge --force --yes >/dev/null
env "${BASE_ENV[@]}" ./plume.sh mode path set laradock-bridge "${LB_PATH}" --force --yes >/dev/null

STATUS_OUT="$(env "${BASE_ENV[@]}" ./plume.sh services status --mode=laradock-bridge)"

printf '%s\n' "${STATUS_OUT}" | grep -q '^workspace[[:space:]]' || {
  echo "[FAIL] expected workspace service to be listed" >&2
  printf '%s\n' "${STATUS_OUT}" >&2
  exit 1
}

printf '%s\n' "${STATUS_OUT}" | grep -q '^php-fpm[[:space:]]' || {
  echo "[FAIL] expected php-fpm service to be listed" >&2
  printf '%s\n' "${STATUS_OUT}" >&2
  exit 1
}

printf '%s\n' "${STATUS_OUT}" | grep -q '^nginx[[:space:]]' || {
  echo "[FAIL] expected nginx service to be listed" >&2
  printf '%s\n' "${STATUS_OUT}" >&2
  exit 1
}

for non_service in build context args ports; do
  if printf '%s\n' "${STATUS_OUT}" | grep -q "^${non_service}[[:space:]]"; then
    echo "[FAIL] nested key was incorrectly listed as service: ${non_service}" >&2
    printf '%s\n' "${STATUS_OUT}" >&2
    exit 1
  fi
done

echo "phase8-laradock-compose-depth-smoke:ok"
