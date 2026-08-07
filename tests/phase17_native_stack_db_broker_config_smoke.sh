#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

TMP_ROOT="$(mktemp -d)"
STATE_DIR="${TMP_ROOT}/state"
mkdir -p "${STATE_DIR}"

MARIADB_MAIN="${TMP_ROOT}/my.cnf"
POSTGRES_MAIN="${TMP_ROOT}/postgresql.conf"
MONGODB_MAIN="${TMP_ROOT}/mongod.conf"
RABBITMQ_MAIN="${TMP_ROOT}/rabbitmq.conf"

cleanup() { rm -rf "${TMP_ROOT}"; }
trap cleanup EXIT

cat > "${MARIADB_MAIN}" <<'EOF'
[mysqld]
datadir=/tmp/mysql
EOF

cat > "${POSTGRES_MAIN}" <<'EOF'
# sample postgres
EOF

cat > "${MONGODB_MAIN}" <<'EOF'
# sample mongod
EOF

cat > "${RABBITMQ_MAIN}" <<'EOF'
# sample rabbitmq
EOF

export PLUME_STATE_DIR="${STATE_DIR}"
export PATH="/usr/bin:/bin"
export PLUME_NATIVE_HOST_INSTALL_DRIVER=mock
export PLUME_NATIVE_MARIADB_MAIN_CONF="${MARIADB_MAIN}"
export PLUME_NATIVE_POSTGRES_MAIN_CONF="${POSTGRES_MAIN}"
export PLUME_NATIVE_MONGODB_MAIN_CONF="${MONGODB_MAIN}"
export PLUME_NATIVE_RABBITMQ_MAIN_CONF="${RABBITMQ_MAIN}"
export PLUME_MARIADB_ROOT_PASSWORD=secret_maria
export PLUME_MARIADB_PORT=3307
export PLUME_POSTGRES_PASSWORD=secret_pg
export PLUME_POSTGRES_PORT=5433
export PLUME_MONGODB_PASSWORD=secret_mongo
export PLUME_MONGODB_PORT=27018
export PLUME_RABBITMQ_PASSWORD=secret_rmq
export PLUME_RABBITMQ_PORT=5673

# shellcheck source=../lib/bootstrap.sh
source "${ROOT_DIR}/lib/bootstrap.sh"

plume_native_mariadb_sync_config mariadb false false
grep -Fq '!include' "${MARIADB_MAIN}" || { echo "[FAIL] mariadb include" >&2; cat "${MARIADB_MAIN}" >&2; exit 1; }
grep -q 'port=3307' "$(plume_native_mariadb_plume_conf_path mariadb)" || { echo "[FAIL] mariadb port" >&2; exit 1; }
echo "[PASS] mariadb config sync"

plume_native_postgres_sync_config false false
grep -Fq "include '" "${POSTGRES_MAIN}" || { echo "[FAIL] postgres include" >&2; cat "${POSTGRES_MAIN}" >&2; exit 1; }
grep -q 'port = 5433' "$(plume_native_postgres_plume_conf_path)" || { echo "[FAIL] postgres port" >&2; exit 1; }
echo "[PASS] postgres config sync"

plume_native_mongodb_sync_config false false
grep -Fq 'plume-managed' "${MONGODB_MAIN}" || { echo "[FAIL] mongodb block" >&2; cat "${MONGODB_MAIN}" >&2; exit 1; }
grep -q 'port: 27018' "${MONGODB_MAIN}" || { echo "[FAIL] mongodb port" >&2; exit 1; }
echo "[PASS] mongodb config sync"

plume_native_rabbitmq_sync_config false false
grep -Fq 'default_pass = secret_rmq' "${RABBITMQ_MAIN}" || { echo "[FAIL] rabbitmq block" >&2; cat "${RABBITMQ_MAIN}" >&2; exit 1; }
grep -q 'listeners.tcp.default = 5673' "${RABBITMQ_MAIN}" || { echo "[FAIL] rabbitmq port" >&2; exit 1; }
echo "[PASS] rabbitmq config sync"

# restart lifecycle hook
plume_native_stack_sync_on_lifecycle mariadb
echo "[PASS] stack sync on lifecycle"

echo "phase17-native-stack-db-broker-config-smoke:ok"
