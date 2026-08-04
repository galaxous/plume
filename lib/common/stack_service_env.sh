#!/usr/bin/env bash
set -euo pipefail

# Laradock-aligned stack connection env (PLUME_*). See docs/operations/env-contract.md.

plume_stack_service_env_short_to_key() {
  local service="$1"
  local short="$2"
  case "${service}:${short}" in
    redis:password) echo "PLUME_REDIS_PASSWORD" ;;
    redis:port) echo "PLUME_REDIS_PORT" ;;
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
