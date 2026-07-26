#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

TMP_ROOT="$(mktemp -d)"
BIN_DIR="${TMP_ROOT}/bin"
STATE_DIR="${TMP_ROOT}/state"
DOCKER_LOG="${TMP_ROOT}/docker.log"
COMPOSE_FILE="${TMP_ROOT}/docker-compose.yml"
mkdir -p "${BIN_DIR}" "${STATE_DIR}"

cleanup() {
  rm -rf "${TMP_ROOT}"
}
trap cleanup EXIT

cat > "${COMPOSE_FILE}" <<'YAML'
services:
  nginx:
    image: nginx:stable
    profiles: ["core"]
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
  while [[ "${1:-}" == "--profile" ]]; do
    shift 2
  done
  case "${1:-}" in
    version) echo "Docker Compose version v2.26.0"; exit 0 ;;
    up|pull|stop|down|ps) exit 0 ;;
    config)
      shift
      if [[ "${1:-}" == "--images" ]]; then
        echo "nginx:stable"
      fi
      exit 0
      ;;
  esac
fi
if [[ "${1:-}" == "image" && "${2:-}" == "inspect" ]]; then
  exit 0
fi
if [[ "${1:-}" == "inspect" ]]; then
  echo "true"
  exit 0
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
  if [[ "${a}" == *"-iTCP:443"* ]]; then
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
./plume.sh services workspace up --mode=docker-lite >/tmp/plume-phase7-ports.out 2>&1

grep -q "docker-lite preflight image found: nginx:stable" /tmp/plume-phase7-ports.out || {
  echo "[FAIL] workspace preflight output missing" >&2
  cat /tmp/plume-phase7-ports.out >&2
  exit 1
}

grep -q "^web=81$" "${STATE_DIR}/services_ports_docker-lite.env" || {
  echo "[FAIL] expected web=81 fallback in services_ports_docker-lite.env" >&2
  cat "${STATE_DIR}/services_ports_docker-lite.env" >&2 || true
  exit 1
}

grep -q "^web_https=444$" "${STATE_DIR}/services_ports_docker-lite.env" || {
  echo "[FAIL] expected web_https=444 fallback in services_ports_docker-lite.env" >&2
  cat "${STATE_DIR}/services_ports_docker-lite.env" >&2 || true
  exit 1
}

echo "phase7-docker-lite-ports-smoke:ok"
