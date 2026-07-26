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
      exit 0
      ;;
    logs)
      echo "simulated log"
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
    esac
  done
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
  "PLUME_HORIZON_REQUIRE_SUPERVISOR=false"
)

# Native side: aliases should map to canonical contract.
env "${BASE_ENV[@]}" ./plume.sh mode use native --force --yes >/dev/null
env "${BASE_ENV[@]}" ./plume.sh services up php-fpm --mode=native >/dev/null
env "${BASE_ENV[@]}" ./plume.sh services up workspace --mode=native >/dev/null
NATIVE_STATUS="$(env "${BASE_ENV[@]}" ./plume.sh services status --mode=native)"
printf '%s\n' "${NATIVE_STATUS}" | grep -Eq '^php[[:space:]]+true[[:space:]]+true[[:space:]]+healthy' || {
  echo "[FAIL] native contract did not map php-fpm -> php" >&2
  printf '%s\n' "${NATIVE_STATUS}" >&2
  exit 1
}
printf '%s\n' "${NATIVE_STATUS}" | grep -Eq '^composer[[:space:]]+true[[:space:]]+true[[:space:]]+healthy' || {
  echo "[FAIL] native contract did not map workspace -> composer" >&2
  printf '%s\n' "${NATIVE_STATUS}" >&2
  exit 1
}

# Laradock side: same user-facing aliases should map to compose services.
env "${BASE_ENV[@]}" ./plume.sh mode use laradock-bridge --force --yes >/dev/null
env "${BASE_ENV[@]}" ./plume.sh mode path set laradock-bridge "${LB_PATH}" --force --yes >/dev/null
env "${BASE_ENV[@]}" ./plume.sh services up php-fpm --mode=laradock-bridge >/dev/null
env "${BASE_ENV[@]}" ./plume.sh services up workspace --mode=laradock-bridge >/dev/null
env "${BASE_ENV[@]}" ./plume.sh services up php-worker --mode=laradock-bridge >/dev/null
env "${BASE_ENV[@]}" ./plume.sh services up laravel-horizon --mode=laradock-bridge >/dev/null

grep -q 'compose up php-fpm' "${DOCKER_LOG}" || {
  echo "[FAIL] laradock contract did not map php-fpm alias" >&2
  cat "${DOCKER_LOG}" >&2 || true
  exit 1
}
grep -q 'compose up workspace' "${DOCKER_LOG}" || {
  echo "[FAIL] laradock contract did not map workspace alias" >&2
  cat "${DOCKER_LOG}" >&2 || true
  exit 1
}
grep -q 'compose up php-worker' "${DOCKER_LOG}" || {
  echo "[FAIL] laradock contract did not map php-worker alias" >&2
  cat "${DOCKER_LOG}" >&2 || true
  exit 1
}
grep -q 'compose up laravel-horizon' "${DOCKER_LOG}" || {
  echo "[FAIL] laradock contract did not map laravel-horizon alias" >&2
  cat "${DOCKER_LOG}" >&2 || true
  exit 1
}

echo "phase8-native-laradock-command-equivalence-smoke:ok"
