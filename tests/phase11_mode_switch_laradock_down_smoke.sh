#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

TMP_ROOT="$(mktemp -d)"
BIN_DIR="${TMP_ROOT}/bin"
STATE_DIR="${TMP_ROOT}/state"
HOME_DIR="${TMP_ROOT}/home"
LB_PATH="${TMP_ROOT}/laradock"
DOCKER_STATE="${TMP_ROOT}/docker-state.env"
DOCKER_LOG="${TMP_ROOT}/docker.log"
mkdir -p "${BIN_DIR}" "${STATE_DIR}" "${HOME_DIR}" "${LB_PATH}"

cleanup() {
  rm -rf "${TMP_ROOT}"
}
trap cleanup EXIT

cat > "${LB_PATH}/docker-compose.yml" <<'YAML'
services:
  nginx: { image: nginx:stable }
YAML

cat > "${BIN_DIR}/docker" <<'EOF_DOCKER'
#!/usr/bin/env bash
set -euo pipefail

STATE_FILE="${PLUME_TEST_DOCKER_STATE}"
LOG_FILE="${PLUME_TEST_DOCKER_LOG}"
touch "${STATE_FILE}" "${LOG_FILE}"

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
        if [[ -n "${1:-}" ]]; then
          svc="${1}"
          if is_running "${svc}"; then
            echo "fake-${svc}-id"
          fi
        else
          while IFS='=' read -r svc state; do
            [[ "${state}" == "running" ]] || continue
            echo "fake-${svc}-id"
          done < "${STATE_FILE}"
        fi
        exit 0
      fi
      exit 0
      ;;
    down)
      echo "compose down" >> "${LOG_FILE}"
      : > "${STATE_FILE}"
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
      *".State.Running"*)
        if is_running "${svc}"; then
          echo "true"
        else
          echo "false"
        fi
        ;;
      *)
        echo ""
        ;;
    esac
  done
  exit 0
fi

exit 0
EOF_DOCKER
chmod +x "${BIN_DIR}/docker"

printf '%s\n' "nginx=running" > "${DOCKER_STATE}"

BASE_ENV=(
  "HOME=${HOME_DIR}"
  "PATH=${BIN_DIR}:${PATH}"
  "PLUME_STATE_DIR=${STATE_DIR}"
  "PLUME_TEST_DOCKER_STATE=${DOCKER_STATE}"
  "PLUME_TEST_DOCKER_LOG=${DOCKER_LOG}"
)

env "${BASE_ENV[@]}" ./plume.sh mode use laradock-bridge --force --yes >/dev/null
env "${BASE_ENV[@]}" ./plume.sh mode path set laradock-bridge "${LB_PATH}" --force --yes >/dev/null

set +e
env "${BASE_ENV[@]}" ./plume.sh mode use native --force --yes >/tmp/plume-phase11-mode-switch.out 2>&1
rc="$?"
set -e
if [[ "${rc}" -ne 2 ]]; then
  echo "[FAIL] mode switch should be blocked without --down-running (got rc=${rc})" >&2
  cat /tmp/plume-phase11-mode-switch.out >&2 || true
  exit 1
fi
echo "[PASS] mode switch blocked without --down-running"

env "${BASE_ENV[@]}" ./plume.sh mode use native --force --yes --down-running >/dev/null
echo "[PASS] mode switch allowed with --down-running"

env "${BASE_ENV[@]}" ./plume.sh mode current | grep -q '^native$' || {
  echo "[FAIL] expected active mode to be native after auto-down switch" >&2
  exit 1
}
echo "[PASS] mode switched to native"

grep -q '^compose down$' "${DOCKER_LOG}" || {
  echo "[FAIL] expected compose down call during switch" >&2
  cat "${DOCKER_LOG}" >&2 || true
  exit 1
}
echo "[PASS] compose down called"

echo "phase11-mode-switch-laradock-down-smoke:ok"
