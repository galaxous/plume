#!/usr/bin/env bash
set -euo pipefail

plume_state_db_file() {
  printf '%s' "${PLUME_STATE_DB_FILE:-$(plume_state_dir)/plume-state.db}"
}

plume_state_db_available() {
  command -v sqlite3 >/dev/null 2>&1
}

plume_state_db_escape() {
  local value="${1:-}"
  printf "%s" "${value//\'/''}"
}

plume_state_db_exec() {
  local sql="${1:-}"
  [[ -n "${sql}" ]] || return 0
  if ! plume_state_db_available; then
    return 0
  fi
  sqlite3 "$(plume_state_db_file)" "${sql}" >/dev/null 2>&1 || true
}

plume_state_db_init() {
  if [[ "${PLUME_STATE_DB_READY:-false}" == "true" ]]; then
    return 0
  fi
  if ! plume_state_db_available; then
    PLUME_STATE_DB_READY="false"
    return 0
  fi
  local db
  db="$(plume_state_db_file)"
  mkdir -p "$(dirname "${db}")"
  sqlite3 "${db}" <<'SQL' >/dev/null 2>&1 || true
CREATE TABLE IF NOT EXISTS services (
  mode TEXT NOT NULL,
  service TEXT NOT NULL,
  enabled TEXT,
  running TEXT,
  health TEXT,
  port TEXT,
  version TEXT,
  updated_at TEXT,
  PRIMARY KEY (mode, service)
);
CREATE TABLE IF NOT EXISTS runtime_events (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  ts TEXT NOT NULL,
  mode TEXT NOT NULL,
  service TEXT,
  event TEXT NOT NULL,
  details TEXT
);
CREATE TABLE IF NOT EXISTS locks (
  name TEXT PRIMARY KEY,
  locked TEXT NOT NULL,
  mode TEXT,
  path TEXT,
  reason TEXT,
  updated_at TEXT
);
CREATE TABLE IF NOT EXISTS desired_services (
  mode TEXT NOT NULL,
  path TEXT NOT NULL,
  service TEXT NOT NULL,
  enabled TEXT NOT NULL DEFAULT 'true',
  updated_at TEXT,
  PRIMARY KEY (mode, path, service)
);
SQL
  PLUME_STATE_DB_READY="true"
}

plume_state_db_upsert_service() {
  local mode="$1"
  local service="$2"
  local enabled="$3"
  local running="$4"
  local health="$5"
  local port="$6"
  local version="$7"
  local ts
  ts="$(date '+%Y-%m-%d %H:%M:%S')"
  plume_state_db_exec "
INSERT INTO services (mode, service, enabled, running, health, port, version, updated_at)
VALUES ('$(plume_state_db_escape "${mode}")',
        '$(plume_state_db_escape "${service}")',
        '$(plume_state_db_escape "${enabled}")',
        '$(plume_state_db_escape "${running}")',
        '$(plume_state_db_escape "${health}")',
        '$(plume_state_db_escape "${port}")',
        '$(plume_state_db_escape "${version}")',
        '$(plume_state_db_escape "${ts}")')
ON CONFLICT(mode, service) DO UPDATE SET
  enabled=excluded.enabled,
  running=excluded.running,
  health=excluded.health,
  port=excluded.port,
  version=excluded.version,
  updated_at=excluded.updated_at;"
}

plume_state_db_append_event() {
  local mode="$1"
  local service="$2"
  local event="$3"
  local details="${4:-}"
  local ts
  ts="$(date '+%Y-%m-%d %H:%M:%S')"
  plume_state_db_exec "
INSERT INTO runtime_events (ts, mode, service, event, details)
VALUES ('$(plume_state_db_escape "${ts}")',
        '$(plume_state_db_escape "${mode}")',
        '$(plume_state_db_escape "${service}")',
        '$(plume_state_db_escape "${event}")',
        '$(plume_state_db_escape "${details}")');"
}

plume_state_db_set_lock() {
  local name="$1"
  local locked="$2"
  local mode="$3"
  local path="$4"
  local reason="$5"
  local ts
  ts="$(date '+%Y-%m-%d %H:%M:%S')"
  plume_state_db_exec "
INSERT INTO locks (name, locked, mode, path, reason, updated_at)
VALUES ('$(plume_state_db_escape "${name}")',
        '$(plume_state_db_escape "${locked}")',
        '$(plume_state_db_escape "${mode}")',
        '$(plume_state_db_escape "${path}")',
        '$(plume_state_db_escape "${reason}")',
        '$(plume_state_db_escape "${ts}")')
ON CONFLICT(name) DO UPDATE SET
  locked=excluded.locked,
  mode=excluded.mode,
  path=excluded.path,
  reason=excluded.reason,
  updated_at=excluded.updated_at;"
}

plume_state_db_prune_services_not_in_list() {
  local mode="$1"
  local csv_list="$2"
  plume_state_db_exec "DELETE FROM services WHERE mode='$(plume_state_db_escape "${mode}")' AND service NOT IN (${csv_list});"
}

plume_state_db_desired_service_set() {
  local mode="$1"
  local path="$2"
  local service="$3"
  local enabled="${4:-true}"
  local ts
  ts="$(date '+%Y-%m-%d %H:%M:%S')"
  plume_state_db_exec "
INSERT INTO desired_services (mode, path, service, enabled, updated_at)
VALUES ('$(plume_state_db_escape "${mode}")',
        '$(plume_state_db_escape "${path}")',
        '$(plume_state_db_escape "${service}")',
        '$(plume_state_db_escape "${enabled}")',
        '$(plume_state_db_escape "${ts}")')
ON CONFLICT(mode, path, service) DO UPDATE SET
  enabled=excluded.enabled,
  updated_at=excluded.updated_at;"
}

plume_state_db_desired_service_delete() {
  local mode="$1"
  local path="$2"
  local service="$3"
  plume_state_db_exec "
DELETE FROM desired_services
WHERE mode='$(plume_state_db_escape "${mode}")'
  AND path='$(plume_state_db_escape "${path}")'
  AND service='$(plume_state_db_escape "${service}")';"
}

plume_state_db_desired_services_clear() {
  local mode="$1"
  local path="$2"
  plume_state_db_exec "
DELETE FROM desired_services
WHERE mode='$(plume_state_db_escape "${mode}")'
  AND path='$(plume_state_db_escape "${path}")';"
}

plume_state_db_desired_services_list() {
  local mode="$1"
  local path="$2"
  plume_state_db_init
  if ! plume_state_db_available; then
    return 0
  fi
  sqlite3 "$(plume_state_db_file)" "
SELECT service
FROM desired_services
WHERE mode='$(plume_state_db_escape "${mode}")'
  AND path='$(plume_state_db_escape "${path}")'
  AND enabled='true'
ORDER BY service;" 2>/dev/null || true
}

plume_state_db_desired_services_count() {
  local mode="$1"
  local path="$2"
  plume_state_db_init
  if ! plume_state_db_available; then
    printf '%s' "0"
    return 0
  fi
  sqlite3 "$(plume_state_db_file)" "
SELECT COUNT(*)
FROM desired_services
WHERE mode='$(plume_state_db_escape "${mode}")'
  AND path='$(plume_state_db_escape "${path}")'
  AND enabled='true';" 2>/dev/null || printf '%s' "0"
}
