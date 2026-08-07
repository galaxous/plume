#!/usr/bin/env bash
set -euo pipefail

# Laradock-aligned stack connection env (PLUME_*). See docs/operations/env-contract.md.

# Laradock-style short names ↔ internal PLUME_* (D-130). Short name wins when both set.
plume_env_laradock_alias_pairs() {
  cat <<'EOF'
REDIS_ENABLED|PLUME_REDIS_ENABLED
MARIADB_ENABLED|PLUME_MARIADB_ENABLED
MYSQL_ENABLED|PLUME_MYSQL_ENABLED
PHPMYADMIN_ENABLED|PLUME_PHPMYADMIN_ENABLED
POSTGRES_ENABLED|PLUME_POSTGRES_ENABLED
MEMCACHED_ENABLED|PLUME_MEMCACHED_ENABLED
RABBITMQ_ENABLED|PLUME_RABBITMQ_ENABLED
MONGODB_ENABLED|PLUME_MONGODB_ENABLED
MONGO_WEBUI_ENABLED|PLUME_MONGO_WEBUI_ENABLED
REDIS_WEBUI_ENABLED|PLUME_REDIS_WEBUI_ENABLED
MAILPIT_ENABLED|PLUME_MAILPIT_ENABLED
MEILISEARCH_ENABLED|PLUME_MEILISEARCH_ENABLED
MINIO_ENABLED|PLUME_MINIO_ENABLED
SUPERVISOR_ENABLED|PLUME_SUPERVISOR_ENABLED
HORIZON_ENABLED|PLUME_HORIZON_ENABLED
PHP_WORKER_ENABLED|PLUME_PHP_WORKER_ENABLED
COMPOSER_ENABLED|PLUME_COMPOSER_ENABLED
REDIS_PORT|PLUME_REDIS_PORT
REDIS_PASSWORD|PLUME_REDIS_PASSWORD
MARIADB_PORT|PLUME_MARIADB_PORT
MARIADB_ROOT_PASSWORD|PLUME_MARIADB_ROOT_PASSWORD
MYSQL_PORT|PLUME_MYSQL_PORT
MYSQL_ROOT_PASSWORD|PLUME_MYSQL_ROOT_PASSWORD
POSTGRES_PORT|PLUME_POSTGRES_PORT
POSTGRES_USER|PLUME_POSTGRES_USER
POSTGRES_PASSWORD|PLUME_POSTGRES_PASSWORD
POSTGRES_DB|PLUME_POSTGRES_DB
MONGODB_PORT|PLUME_MONGODB_PORT
MONGO_USERNAME|PLUME_MONGODB_USERNAME
MONGO_PASSWORD|PLUME_MONGODB_PASSWORD
RABBITMQ_NODE_HOST_PORT|PLUME_RABBITMQ_PORT
RABBITMQ_MANAGEMENT_HTTP_HOST_PORT|PLUME_RABBITMQ_MANAGEMENT_PORT
RABBITMQ_DEFAULT_USER|PLUME_RABBITMQ_USER
RABBITMQ_DEFAULT_PASS|PLUME_RABBITMQ_PASSWORD
MONGO_WEBUI_PORT|PLUME_MONGO_WEBUI_PORT
REDIS_WEBUI_PORT|PLUME_REDIS_WEBUI_PORT
REDIS_WEBUI_USERNAME|PLUME_REDIS_WEBUI_USERNAME
REDIS_WEBUI_PASSWORD|PLUME_REDIS_WEBUI_PASSWORD
REDIS_WEBUI_CONNECT_HOST|PLUME_REDIS_WEBUI_HOST
REDIS_WEBUI_CONNECT_PORT|PLUME_REDIS_WEBUI_REDIS_PORT
EOF
}

plume_env_laradock_short_name() {
  local pair short plume
  short="$1"
  while IFS='|' read -r pair_short plume_key; do
    [[ -n "${pair_short}" ]] || continue
    if [[ "${pair_short}" == "${short}" ]]; then
      printf '%s' "${plume_key}"
      return 0
    fi
  done < <(plume_env_laradock_alias_pairs)
  return 1
}

plume_env_laradock_plume_to_short() {
  local plume="$1"
  local short plume_key
  while IFS='|' read -r short plume_key; do
    [[ -n "${short}" && -n "${plume_key}" ]] || continue
    if [[ "${plume_key}" == "${plume}" ]]; then
      printf '%s' "${short}"
      return 0
    fi
  done < <(plume_env_laradock_alias_pairs)
  return 1
}

plume_env_is_laradock_short_name() {
  plume_env_laradock_short_name "$1" >/dev/null 2>&1
}

plume_env_sync_alias_pair() {
  local short="$1"
  local plume="$2"
  local direction="${3:-both}"
  local short_set="false" plume_set="false"

  if [[ -n "${!short+x}" ]]; then
    short_set="true"
  fi
  if [[ -n "${!plume+x}" ]]; then
    plume_set="true"
  fi

  case "${direction}" in
    outward)
      if [[ "${plume_set}" == "true" && "${short_set}" != "true" ]]; then
        export "${short}=${!plume}"
      fi
      ;;
    inward)
      if [[ "${short_set}" == "true" ]]; then
        export "${plume}=${!short}"
      elif [[ "${plume_set}" == "true" ]]; then
        export "${short}=${!plume}"
      fi
      ;;
    refresh)
      if [[ "${plume_set}" == "true" ]]; then
        export "${short}=${!plume}"
      fi
      ;;
    both)
      if [[ "${short_set}" == "true" ]]; then
        export "${plume}=${!short}"
      elif [[ "${plume_set}" == "true" ]]; then
        export "${short}=${!plume}"
      fi
      ;;
    *)
      plume_err "invalid laradock alias direction: ${direction}"
      return 2
      ;;
  esac
}

plume_env_apply_laradock_aliases_outward() {
  local short plume
  while IFS='|' read -r short plume; do
    [[ -n "${short}" && -n "${plume}" ]] || continue
    plume_env_sync_alias_pair "${short}" "${plume}" outward
  done < <(plume_env_laradock_alias_pairs)
}

plume_env_apply_laradock_aliases_inward() {
  local short plume
  while IFS='|' read -r short plume; do
    [[ -n "${short}" && -n "${plume}" ]] || continue
    plume_env_sync_alias_pair "${short}" "${plume}" inward
  done < <(plume_env_laradock_alias_pairs)
}

plume_env_apply_laradock_aliases_refresh() {
  local short plume
  while IFS='|' read -r short plume; do
    [[ -n "${short}" && -n "${plume}" ]] || continue
    plume_env_sync_alias_pair "${short}" "${plume}" refresh
  done < <(plume_env_laradock_alias_pairs)
}

plume_env_apply_laradock_aliases() {
  plume_env_apply_laradock_aliases_outward
  plume_env_apply_laradock_aliases_inward
}

plume_stack_service_env_short_to_key() {
  local service="$1"
  local short="$2"
  case "${service}:${short}" in
    redis:password) echo "PLUME_REDIS_PASSWORD" ;;
    redis:port) echo "PLUME_REDIS_PORT" ;;
    mariadb:password|mariadb:root_password) echo "PLUME_MARIADB_ROOT_PASSWORD" ;;
    mariadb:port) echo "PLUME_MARIADB_PORT" ;;
    mysql:password|mysql:root_password) echo "PLUME_MYSQL_ROOT_PASSWORD" ;;
    mysql:port) echo "PLUME_MYSQL_PORT" ;;
    postgres:password) echo "PLUME_POSTGRES_PASSWORD" ;;
    postgres:port) echo "PLUME_POSTGRES_PORT" ;;
    postgres:user|postgres:username) echo "PLUME_POSTGRES_USER" ;;
    postgres:database|postgres:db) echo "PLUME_POSTGRES_DB" ;;
    mongodb:username|mongodb:user) echo "PLUME_MONGODB_USERNAME" ;;
    mongodb:password) echo "PLUME_MONGODB_PASSWORD" ;;
    mongodb:port) echo "PLUME_MONGODB_PORT" ;;
    mongodb:database|mongodb:db) echo "PLUME_MONGODB_DATABASE" ;;
    rabbitmq:user|rabbitmq:username) echo "PLUME_RABBITMQ_USER" ;;
    rabbitmq:password) echo "PLUME_RABBITMQ_PASSWORD" ;;
    rabbitmq:port) echo "PLUME_RABBITMQ_PORT" ;;
    rabbitmq:management_port) echo "PLUME_RABBITMQ_MANAGEMENT_PORT" ;;
    mongo_webui:uri) echo "PLUME_MONGO_WEBUI_URI" ;;
    mongo_webui:username|mongo_webui:user) echo "PLUME_MONGO_WEBUI_USERNAME" ;;
    mongo_webui:password) echo "PLUME_MONGO_WEBUI_PASSWORD" ;;
    mongo_webui:port) echo "PLUME_MONGO_WEBUI_PORT" ;;
    redis_webui:username|redis_webui:user) echo "PLUME_REDIS_WEBUI_USERNAME" ;;
    redis_webui:password) echo "PLUME_REDIS_WEBUI_PASSWORD" ;;
    redis_webui:host) echo "PLUME_REDIS_WEBUI_HOST" ;;
    redis_webui:port) echo "PLUME_REDIS_WEBUI_PORT" ;;
    redis_webui:redis_port|redis_webui:connect_port) echo "PLUME_REDIS_WEBUI_REDIS_PORT" ;;
    *)
      return 1
      ;;
  esac
}

plume_stack_service_env_keys_for_service() {
  local service="$1"
  case "${service}" in
    redis)
      printf '%s\n' PLUME_REDIS_PORT PLUME_REDIS_PASSWORD
      ;;
    mariadb)
      printf '%s\n' PLUME_MARIADB_PORT PLUME_MARIADB_ROOT_PASSWORD
      ;;
    mysql)
      printf '%s\n' PLUME_MYSQL_PORT PLUME_MYSQL_ROOT_PASSWORD
      ;;
    postgres)
      printf '%s\n' \
        PLUME_POSTGRES_PORT \
        PLUME_POSTGRES_USER \
        PLUME_POSTGRES_PASSWORD \
        PLUME_POSTGRES_DB
      ;;
    mongodb)
      printf '%s\n' \
        PLUME_MONGODB_PORT \
        PLUME_MONGODB_USERNAME \
        PLUME_MONGODB_PASSWORD \
        PLUME_MONGODB_DATABASE
      ;;
    rabbitmq)
      printf '%s\n' \
        PLUME_RABBITMQ_PORT \
        PLUME_RABBITMQ_MANAGEMENT_PORT \
        PLUME_RABBITMQ_USER \
        PLUME_RABBITMQ_PASSWORD
      ;;
    mongo_webui)
      printf '%s\n' \
        PLUME_MONGO_WEBUI_PORT \
        PLUME_MONGO_WEBUI_URI \
        PLUME_MONGO_WEBUI_USERNAME \
        PLUME_MONGO_WEBUI_PASSWORD
      ;;
    redis_webui)
      printf '%s\n' \
        PLUME_REDIS_WEBUI_PORT \
        PLUME_REDIS_WEBUI_USERNAME \
        PLUME_REDIS_WEBUI_PASSWORD \
        PLUME_REDIS_WEBUI_HOST \
        PLUME_REDIS_WEBUI_REDIS_PORT
      ;;
    *)
      return 1
      ;;
  esac
}

plume_stack_service_env_affected_services() {
  local key="$1"
  case "${key}" in
    PLUME_REDIS_*)
      printf '%s\n' redis redis_webui
      ;;
    PLUME_MARIADB_*)
      printf '%s\n' mariadb
      ;;
    PLUME_MYSQL_*)
      printf '%s\n' mysql
      ;;
    PLUME_POSTGRES_*)
      printf '%s\n' postgres
      ;;
    PLUME_MONGODB_*)
      printf '%s\n' mongodb mongo_webui
      ;;
    PLUME_RABBITMQ_*)
      printf '%s\n' rabbitmq
      ;;
    PLUME_MONGO_WEBUI_*)
      printf '%s\n' mongo_webui
      ;;
    PLUME_REDIS_WEBUI_*)
      printf '%s\n' redis_webui
      ;;
    *)
      return 1
      ;;
  esac
}

plume_stack_build_mongo_webui_uri() {
  local user pass host port db uri
  if [[ -n "${PLUME_MONGO_WEBUI_URI:-}" ]]; then
    printf '%s' "${PLUME_MONGO_WEBUI_URI}"
    return 0
  fi
  user="${PLUME_MONGODB_USERNAME:-root}"
  pass="${PLUME_MONGODB_PASSWORD:-example}"
  host="${PLUME_MONGODB_HOST:-127.0.0.1}"
  port="${PLUME_MONGODB_PORT:-27017}"
  db="${PLUME_MONGODB_DATABASE:-admin}"
  if [[ -n "${user}" && -n "${pass}" ]]; then
    uri="mongodb://${user}:${pass}@${host}:${port}/${db}"
  else
    uri="mongodb://${host}:${port}/${db}"
  fi
  printf '%s' "${uri}"
}

plume_stack_build_redis_commander_hosts() {
  local host port db pass label
  host="${PLUME_REDIS_WEBUI_HOST:-127.0.0.1}"
  port="${PLUME_REDIS_WEBUI_REDIS_PORT:-${PLUME_REDIS_PORT:-6379}}"
  db="0"
  pass="${PLUME_REDIS_PASSWORD:-}"
  label="local"
  if [[ -n "${pass}" ]]; then
    printf '%s:%s:%s:%s:%s' "${label}" "${host}" "${port}" "${db}" "${pass}"
  else
    printf '%s:%s:%s:%s' "${label}" "${host}" "${port}" "${db}"
  fi
}

plume_stack_service_env_resolve_assignment() {
  local service="$1"
  local assignment="$2"
  local key value

  if [[ "${assignment}" == PLUME_*=* ]]; then
    key="${assignment%%=*}"
    value="${assignment#*=}"
    printf '%s=%s' "${key}" "${value}"
    return 0
  fi

  if [[ "${assignment}" != *=* ]]; then
    return 1
  fi

  key="$(plume_stack_service_env_short_to_key "${service}" "${assignment%%=*}" || true)"
  if [[ -z "${key}" ]]; then
    return 1
  fi
  value="${assignment#*=}"
  printf '%s=%s' "${key}" "${value}"
}

plume_stack_service_env_write_and_export() {
  local key="$1"
  local value="$2"
  local env_file

  if [[ ! "${key}" =~ ^PLUME_[A-Z0-9_]+$ ]]; then
    plume_err "invalid env key (expected PLUME_*): ${key}"
    return 2
  fi

  env_file="$(plume_global_env_file)"
  mkdir -p "$(dirname "${env_file}")"
  plume_global_env_set_kv "${env_file}" "${key}" "${value}"
  export "${key}=${value}"
  plume_info "updated ${env_file}: ${key}=${value}"
}
