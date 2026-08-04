#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

TMP_ROOT="$(mktemp -d)"
HOME_DIR="${TMP_ROOT}/home"
STATE_DIR="${TMP_ROOT}/state"
MOCK_BIN="${TMP_ROOT}/bin"
MOCK_LOG="${TMP_ROOT}/pkg.log"
mkdir -p "${HOME_DIR}" "${STATE_DIR}" "${MOCK_BIN}"

cleanup() { rm -rf "${TMP_ROOT}"; }
trap cleanup EXIT

if [[ "$(uname -s)" == "Darwin" ]]; then
  cat > "${MOCK_BIN}/brew" <<EOF
#!/usr/bin/env bash
echo "brew \$*" >> "${MOCK_LOG}"
exit 0
EOF
  chmod +x "${MOCK_BIN}/brew"
else
  cat > "${MOCK_BIN}/apt-get" <<EOF
#!/usr/bin/env bash
echo "apt-get \$*" >> "${MOCK_LOG}"
exit 0
EOF
  chmod +x "${MOCK_BIN}/apt-get"
  cat > "${MOCK_BIN}/systemctl" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
  chmod +x "${MOCK_BIN}/systemctl"
fi

BASE_ENV=(
  "HOME=${HOME_DIR}"
  "PLUME_STATE_DIR=${STATE_DIR}"
  "PATH=${MOCK_BIN}:/usr/bin:/bin"
  "PLUME_NATIVE_HOST_PROVISION=true"
  "PLUME_NATIVE_HOST_INSTALL_DRIVER=mock"
  "PLUME_ALLOW_NON_ROOT_INSTALL=true"
  "PLUME_SKIP_ON_FIRST_RUN_PROVISION=true"
  "PLUME_REDIS_ENABLED=true"
  "PLUME_MONGODB_ENABLED=true"
  "PLUME_RABBITMQ_ENABLED=true"
)

env "${BASE_ENV[@]}" ./plume.sh mode use native --force --yes >/dev/null

for svc in redis mongodb rabbitmq; do
  env "${BASE_ENV[@]}" ./plume.sh services install "${svc}" --mode=native >/dev/null
  env "${BASE_ENV[@]}" ./plume.sh services up "${svc}" --mode=native >/dev/null
  echo "[PASS] ${svc} mock install+up"
done

echo "phase17-native-stack-broker-smoke:ok"
