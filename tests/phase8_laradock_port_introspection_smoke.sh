#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

if ! command -v sqlite3 >/dev/null 2>&1; then
  echo "phase8-laradock-port-introspection-smoke:skip (sqlite3 not found)"
  exit 0
fi

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
  workspace: { image: laradock/workspace:latest }
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
          workspace) ports='{"22/tcp":[{"HostIp":"0.0.0.0","HostPort":"2222"}],"3000/tcp":[{"HostIp":"0.0.0.0","HostPort":"3000"}]}' ;;
          nginx) ports='{"80/tcp":[{"HostIp":"0.0.0.0","HostPort":"80"}],"443/tcp":[{"HostIp":"0.0.0.0","HostPort":"443"}]}' ;;
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

printf '%s\n' "workspace=running" "nginx=running" > "${DOCKER_STATE}"

BASE_ENV=(
  "HOME=${HOME_DIR}"
  "PATH=${BIN_DIR}:${PATH}"
  "PLUME_STATE_DIR=${STATE_DIR}"
  "PLUME_TEST_DOCKER_STATE=${DOCKER_STATE}"
)

env "${BASE_ENV[@]}" ./plume.sh mode use laradock-bridge --force --yes >/dev/null
env "${BASE_ENV[@]}" ./plume.sh mode path set laradock-bridge "${LB_PATH}" --force --yes >/dev/null
env "${BASE_ENV[@]}" ./plume.sh sync state --mode=laradock-bridge >/dev/null

PORTS_FILE="${STATE_DIR}/services_ports_laradock-bridge.env"
grep -q '^workspace=2222,3000$' "${PORTS_FILE}" || {
  echo "[FAIL] expected workspace multi-port introspection in sync state" >&2
  cat "${PORTS_FILE}" >&2 || true
  exit 1
}

grep -q '^nginx=80,443$' "${PORTS_FILE}" || {
  echo "[FAIL] expected nginx multi-port introspection in sync state" >&2
  cat "${PORTS_FILE}" >&2 || true
  exit 1
}

grep -q '^web_https=443$' "${PORTS_FILE}" || {
  echo "[FAIL] expected web_https=443 in sync state" >&2
  cat "${PORTS_FILE}" >&2 || true
  exit 1
}

echo "phase8-laradock-port-introspection-smoke:ok"
