#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

TMP_ROOT="$(mktemp -d)"
BIN_DIR="${TMP_ROOT}/bin"
STATE_DIR="${TMP_ROOT}/state"
DOCKER_LOG="${TMP_ROOT}/docker.log"
COMPOSE_FILE="${TMP_ROOT}/docker-compose.yml"
OUT_FILE="${TMP_ROOT}/out.log"
mkdir -p "${BIN_DIR}" "${STATE_DIR}"

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
echo "$*" >> "${PLUME_TEST_DOCKER_LOG}"
if [[ "${1:-}" == "compose" ]]; then
  shift
  if [[ "${1:-}" == "-f" ]]; then
    shift 2
  fi
  case "${1:-}" in
    version) echo "Docker Compose version v2.26.0"; exit 0 ;;
    up|pull|stop|down|ps) exit 0 ;;
  esac
fi
if [[ "${1:-}" == "image" && "${2:-}" == "inspect" ]]; then
  exit 0
fi
if [[ "${1:-}" == "inspect" ]]; then
  if [[ "${2:-}" == "-f" ]]; then
    echo "true"
    exit 0
  fi
  exit 0
fi
if [[ "${1:-}" == "port" ]]; then
  if [[ "${2:-}" == "plume-nginx" && "${3:-}" == "80/tcp" ]]; then
    echo "0.0.0.0:80"
    exit 0
  fi
  exit 1
fi
exit 0
EOF
chmod +x "${BIN_DIR}/docker"

cat > "${BIN_DIR}/lsof" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
for a in "$@"; do
  if [[ "${a}" == *"-iTCP:80"* ]]; then
    exit 0
  fi
done
exit 1
EOF
chmod +x "${BIN_DIR}/lsof"

PATH="${BIN_DIR}:${PATH}" \
PLUME_TEST_DOCKER_LOG="${DOCKER_LOG}" \
PLUME_STATE_DIR="${STATE_DIR}" \
PLUME_DOCKER_LITE_COMPOSE_REQUIRED=true \
PLUME_DOCKER_LITE_COMPOSE_FILE="${COMPOSE_FILE}" \
./plume.sh services up web --mode=docker-lite >"${OUT_FILE}" 2>&1

if grep -q "default port busy for web: 80, using 81" "${OUT_FILE}"; then
  echo "[FAIL] expected live port reuse, got fallback warning" >&2
  cat "${OUT_FILE}" >&2
  exit 1
fi

grep -q "^web=80$" "${STATE_DIR}/services_ports_docker-lite.env" || {
  echo "[FAIL] expected web=80 when live container already uses 80" >&2
  cat "${STATE_DIR}/services_ports_docker-lite.env" >&2 || true
  exit 1
}

echo "phase7-docker-lite-preserve-live-ports-smoke:ok"
