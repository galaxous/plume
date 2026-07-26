#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

TMP_DOCKER_CONFIG=""

cleanup() {
  if [[ -n "${TMP_DOCKER_CONFIG}" && -d "${TMP_DOCKER_CONFIG}" ]]; then
    rm -rf "${TMP_DOCKER_CONFIG}"
  fi
}

trap cleanup EXIT

setup_docker_config_fallback() {
  local docker_cfg="${DOCKER_CONFIG:-$HOME/.docker}"
  local cfg_file="${docker_cfg}/config.json"

  if command -v docker-credential-desktop >/dev/null 2>&1; then
    return 0
  fi

  if [[ ! -f "${cfg_file}" ]]; then
    return 0
  fi

  if ! grep -q '"credsStore"[[:space:]]*:[[:space:]]*"desktop"' "${cfg_file}"; then
    return 0
  fi

  TMP_DOCKER_CONFIG="$(mktemp -d)"
  cat > "${TMP_DOCKER_CONFIG}/config.json" <<'EOF'
{"auths":{}}
EOF
  export DOCKER_CONFIG="${TMP_DOCKER_CONFIG}"
  echo "[INFO] docker-credential-desktop not found; using temporary DOCKER_CONFIG fallback"
}

if ! command -v docker >/dev/null 2>&1; then
  echo "[SKIP] docker not found; linux matrix skipped"
  exit 0
fi

setup_docker_config_fallback

if ! docker info >/dev/null 2>&1; then
  echo "[SKIP] docker daemon not reachable; linux matrix skipped"
  exit 0
fi

run_ubuntu() {
  echo "[RUN] ubuntu:24.04 prereq matrix"
  docker run --rm -v "${ROOT_DIR}":/work -w /work ubuntu:24.04 bash -lc '
    set -euo pipefail
    apt update >/dev/null
    apt install -y bash curl gawk grep sed findutils tar gzip openssh-client git sudo >/dev/null
    ./plume.sh prereq check --profile=base >/dev/null
    ./plume.sh prereq check --profile=git-ops >/dev/null
    ./plume.sh prereq check --profile=native-install >/dev/null
  '
  echo "[PASS] ubuntu:24.04"
}

run_fedora() {
  echo "[RUN] fedora:41 prereq matrix"
  docker run --rm -v "${ROOT_DIR}":/work -w /work fedora:41 bash -lc '
    set -euo pipefail
    dnf install -y bash curl gawk grep sed findutils tar gzip openssh-clients git sudo >/dev/null
    ./plume.sh prereq check --profile=base >/dev/null
    ./plume.sh prereq check --profile=git-ops >/dev/null
    ./plume.sh prereq check --profile=native-install >/dev/null
  '
  echo "[PASS] fedora:41"
}

run_ubuntu
run_fedora

echo "linux-prereq-matrix:ok"
