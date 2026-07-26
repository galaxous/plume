#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

TMP_ROOT="$(mktemp -d)"
BIN_DIR="${TMP_ROOT}/bin"
COMPOSE_FILE="${TMP_ROOT}/docker-compose.yml"
OUT_FILE="${TMP_ROOT}/out.log"
mkdir -p "${BIN_DIR}"

cleanup() {
  rm -rf "${TMP_ROOT}"
}
trap cleanup EXIT

cat > "${COMPOSE_FILE}" <<'YAML'
services:
  bad:
    image: redisx:7
YAML

cat > "${BIN_DIR}/docker" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" == "compose" ]]; then
  shift
  if [[ "${1:-}" == "-f" ]]; then
    shift 2
  fi
  while [[ "${1:-}" == "--profile" ]]; do
    shift 2
  done
  case "${1:-}" in
    version)
      echo "Docker Compose version v2.26.0"
      exit 0
      ;;
    config)
      shift
      if [[ "${1:-}" == "--images" ]]; then
        echo "redisx:7"
        exit 0
      fi
      ;;
  esac
fi

if [[ "${1:-}" == "image" && "${2:-}" == "inspect" ]]; then
  exit 1
fi

if [[ "${1:-}" == "pull" ]]; then
  exit 1
fi

if [[ "${1:-}" == "search" ]]; then
  cat <<'SEARCH'
NAME                DESCRIPTION
redis               Redis official
bitnami/redis       Bitnami Redis
redis/redis-stack   Redis Stack
SEARCH
  exit 0
fi

exit 0
EOF
chmod +x "${BIN_DIR}/docker"

set +e
PATH="${BIN_DIR}:${PATH}" \
PLUME_DOCKER_LITE_COMPOSE_REQUIRED=true \
PLUME_DOCKER_LITE_COMPOSE_FILE="${COMPOSE_FILE}" \
./plume.sh services workspace up --mode=docker-lite >"${OUT_FILE}" 2>&1
code=$?
set -e

if [[ "${code}" -ne 2 ]]; then
  echo "[FAIL] expected exit code 2, got ${code}" >&2
  cat "${OUT_FILE}" >&2
  exit 1
fi

grep -q "similar images for 'redisx:7'" "${OUT_FILE}" || {
  echo "[FAIL] missing similar image hint" >&2
  cat "${OUT_FILE}" >&2
  exit 1
}

grep -q "redis" "${OUT_FILE}" || {
  echo "[FAIL] missing suggested redis image names" >&2
  cat "${OUT_FILE}" >&2
  exit 1
}

echo "phase7-docker-image-suggest-smoke:ok"
