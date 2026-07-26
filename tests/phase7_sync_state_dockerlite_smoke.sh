#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

TMP_ROOT="$(mktemp -d)"
STATE_DIR="${TMP_ROOT}/state"
BIN_DIR="${TMP_ROOT}/bin"
DL_PATH="${TMP_ROOT}/dl"
COMPOSE_FILE="${DL_PATH}/docker-compose.yml"
mkdir -p "${STATE_DIR}" "${BIN_DIR}" "${DL_PATH}"

cleanup() {
  rm -rf "${TMP_ROOT}"
}
trap cleanup EXIT

cat > "${COMPOSE_FILE}" <<'YAML'
services:
  nginx:
    image: nginx:stable
YAML

cat > "${BIN_DIR}/docker" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [[ "${1:-}" == "compose" ]]; then
  shift
  if [[ "${1:-}" == "-f" ]]; then
    shift 2
  fi
  case "${1:-}" in
    version) echo "Docker Compose version v2.26.0"; exit 0 ;;
    ps)
      if [[ "${2:-}" == "-q" ]]; then
        echo "cid-nginx"
      fi
      exit 0
      ;;
  esac
fi
if [[ "${1:-}" == "inspect" ]]; then
  if [[ "${2:-}" == "-f" ]]; then
    echo "true"
    exit 0
  fi
  exit 0
fi
if [[ "${1:-}" == "port" && "${2:-}" == "plume-nginx" && "${3:-}" == "80/tcp" ]]; then
  echo "0.0.0.0:80"
  exit 0
fi
exit 0
EOF
chmod +x "${BIN_DIR}/docker"

BASE_ENV=("PLUME_STATE_DIR=${STATE_DIR}" "PATH=${BIN_DIR}:${PATH}")

env "${BASE_ENV[@]}" ./plume.sh mode use docker-lite >/dev/null
env "${BASE_ENV[@]}" ./plume.sh mode path set "${DL_PATH}" >/dev/null
env "${BASE_ENV[@]}" ./plume.sh sync state --mode=docker-lite --path="${DL_PATH}" >/tmp/plume-phase7-sync-state.out 2>&1

grep -q "^web.running=true$" "${STATE_DIR}/services_runtime_docker-lite.env" || {
  echo "[FAIL] expected web.running=true after sync state" >&2
  cat "${STATE_DIR}/services_runtime_docker-lite.env" >&2 || true
  exit 1
}

grep -q "^web=80$" "${STATE_DIR}/services_ports_docker-lite.env" || {
  echo "[FAIL] expected web=80 after sync state" >&2
  cat "${STATE_DIR}/services_ports_docker-lite.env" >&2 || true
  exit 1
}

echo "phase7-sync-state-dockerlite-smoke:ok"
