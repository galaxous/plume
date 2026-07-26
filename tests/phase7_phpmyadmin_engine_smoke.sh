#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

TMP_ROOT="$(mktemp -d)"
BIN_DIR="${TMP_ROOT}/bin"
STATE_DIR="${TMP_ROOT}/state"
DOCKER_LOG="${TMP_ROOT}/docker.log"
DL_PATH="${TMP_ROOT}/docker-lite"
mkdir -p "${BIN_DIR}" "${STATE_DIR}" "${DL_PATH}"

cleanup() {
  rm -rf "${TMP_ROOT}"
}
trap cleanup EXIT

cat > "${DL_PATH}/docker-compose.yml" <<'YAML'
services:
  mariadb:
    image: mariadb:11
  mysql:
    image: mysql:8
  phpmyadmin:
    image: phpmyadmin:latest
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
    version|up|pull|stop|down|ps|logs) exit 0 ;;
    config)
      shift
      if [[ "${1:-}" == "--images" ]]; then
        echo "phpmyadmin:latest"
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

BASE_ENV=(
  "PATH=${BIN_DIR}:${PATH}"
  "PLUME_TEST_DOCKER_LOG=${DOCKER_LOG}"
  "PLUME_STATE_DIR=${STATE_DIR}"
  "PLUME_DOCKER_LITE_COMPOSE_REQUIRED=true"
  "PLUME_PHPMYADMIN_ENABLED=true"
  "PLUME_PHPMYADMIN_VERSION=latest"
  "PMA_PORT=8081"
)

env "${BASE_ENV[@]}" ./plume.sh mode use docker-lite >/dev/null
env "${BASE_ENV[@]}" ./plume.sh mode path set "${DL_PATH}" >/dev/null

env "${BASE_ENV[@]}" \
  "PMA_DB_ENGINE=" \
  "PMA_ENGINE=mariadb" \
  "PLUME_MARIADB_ENABLED=true" \
  ./plume.sh services up phpmyadmin --mode=docker-lite >/tmp/plume-phase7-pma.out 2>&1

grep -q "compose -f ${DL_PATH}/docker-compose.yml up -d phpmyadmin" "${DOCKER_LOG}" || {
  echo "[FAIL] phpmyadmin did not map to docker compose service" >&2
  cat "${DOCKER_LOG}" >&2 || true
  exit 1
}

grep -Eq "^phpmyadmin=[0-9]+$" "${STATE_DIR}/services_ports_docker-lite.env" || {
  echo "[FAIL] expected phpmyadmin port to be tracked with a numeric value" >&2
  cat "${STATE_DIR}/services_ports_docker-lite.env" >&2 || true
  exit 1
}

set +e
env "${BASE_ENV[@]}" \
  "PMA_DB_ENGINE=postgres" \
  "PLUME_MARIADB_ENABLED=true" \
  ./plume.sh services up phpmyadmin --mode=docker-lite >/tmp/plume-phase7-pma-fail1.out 2>&1
code="$?"
set -e
if [[ "${code}" -ne 2 ]]; then
  echo "[FAIL] invalid PMA_DB_ENGINE should fail with exit 2 (got ${code})" >&2
  cat /tmp/plume-phase7-pma-fail1.out >&2 || true
  exit 1
fi

set +e
env "${BASE_ENV[@]}" \
  "PMA_DB_ENGINE=mysql" \
  "PLUME_MYSQL_ENABLED=false" \
  ./plume.sh services up phpmyadmin --mode=docker-lite >/tmp/plume-phase7-pma-fail2.out 2>&1
code="$?"
set -e
if [[ "${code}" -ne 2 ]]; then
  echo "[FAIL] disabled mysql dependency should fail with exit 2 (got ${code})" >&2
  cat /tmp/plume-phase7-pma-fail2.out >&2 || true
  exit 1
fi

echo "phase7-phpmyadmin-engine-smoke:ok"
