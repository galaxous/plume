#!/usr/bin/env bash
set -euo pipefail

plume_services_runtime_file() {
  local mode="${1:-$(plume_mode_current)}"
  printf '%s' "$(plume_state_dir)/services_runtime_${mode}.env"
}

plume_services_ports_file() {
  local mode="${1:-$(plume_mode_current)}"
  printf '%s' "$(plume_state_dir)/services_ports_${mode}.env"
}

plume_services_runtime_set() {
  local service="$1"
  local field="$2"
  local value="$3"
  local mode="${4:-$(plume_mode_current)}"
  local file
  local key
  file="$(plume_services_runtime_file "${mode}")"
  key="${service}.${field}"
  touch "${file}"
  if grep -qE "^${key}=" "${file}"; then
    sed -i.bak -E "s|^${key}=.*$|${key}=${value}|" "${file}" && rm -f "${file}.bak"
  else
    printf '%s=%s\n' "${key}" "${value}" >> "${file}"
  fi
  plume_state_db_sync_service "${service}" "${mode}"
}

plume_services_ports_set() {
  local service="$1"
  local port="$2"
  local mode="${3:-$(plume_mode_current)}"
  local file
  file="$(plume_services_ports_file "${mode}")"
  touch "${file}"
  if grep -qE "^${service}=" "${file}"; then
    sed -i.bak -E "s|^${service}=.*$|${service}=${port}|" "${file}" && rm -f "${file}.bak"
  else
    printf '%s=%s\n' "${service}" "${port}" >> "${file}"
  fi
  plume_state_db_sync_service "${service}" "${mode}"
}

plume_services_ports_unset() {
  local service="$1"
  local mode="${2:-$(plume_mode_current)}"
  local file
  file="$(plume_services_ports_file "${mode}")"
  [[ -f "${file}" ]] || return 0
  sed -i.bak -E "/^${service}=.*/d" "${file}" && rm -f "${file}.bak"
  plume_state_db_sync_service "${service}" "${mode}"
}

plume_services_runtime_get() {
  local service="$1"
  local field="$2"
  local mode="${3:-$(plume_mode_current)}"
  local file key line
  file="$(plume_services_runtime_file "${mode}")"
  key="${service}.${field}"
  if [[ ! -f "${file}" ]]; then
    return 1
  fi
  line="$(grep -E "^${key}=" "${file}" || true)"
  [[ -n "${line}" ]] || return 1
  printf '%s' "${line#*=}"
}

plume_services_ports_get() {
  local service="$1"
  local mode="${2:-$(plume_mode_current)}"
  local file line
  file="$(plume_services_ports_file "${mode}")"
  if [[ ! -f "${file}" ]]; then
    return 1
  fi
  line="$(grep -E "^${service}=" "${file}" || true)"
  [[ -n "${line}" ]] || return 1
  printf '%s' "${line#*=}"
}

plume_state_db_sync_service() {
  local service="$1"
  local mode="${2:-$(plume_mode_current)}"
  local enabled running version port health
  if ! plume_service_exists "${service}" "${mode}"; then
    return 0
  fi
  enabled="$(plume_service_enabled "${service}")"
  running="$(plume_services_runtime_get "${service}" running "${mode}" || true)"
  [[ -n "${running}" ]] || running="false"
  version="$(plume_service_version "${service}")"
  port="$(plume_services_ports_get "${service}" "${mode}" || true)"
  if [[ "${running}" == "true" ]]; then
    health="healthy"
  elif [[ "${enabled}" != "true" ]]; then
    health="disabled"
  else
    health="stopped"
  fi
  plume_state_db_upsert_service "${mode}" "${service}" "${enabled}" "${running}" "${health}" "${port}" "${version}"
}

plume_service_default_port() {
  local service="$1"
  case "${service}" in
    web) echo "${PLUME_WEB_PORT:-80}" ;;
    phpmyadmin) echo "${PMA_PORT:-${PLUME_PHPMYADMIN_PORT:-8081}}" ;;
    mariadb) echo "${PLUME_MARIADB_PORT:-3306}" ;;
    mysql) echo "${PLUME_MYSQL_PORT:-3306}" ;;
    postgres) echo "${PLUME_POSTGRES_PORT:-5432}" ;;
    redis) echo "${PLUME_REDIS_PORT:-6379}" ;;
    memcached) echo "${PLUME_MEMCACHED_PORT:-11211}" ;;
    rabbitmq) echo "${PLUME_RABBITMQ_PORT:-5672}" ;;
    mongodb) echo "${PLUME_MONGODB_PORT:-27017}" ;;
    mongo_webui) echo "${PLUME_MONGO_WEBUI_PORT:-8081}" ;;
    mailpit) echo "${PLUME_MAILPIT_PORT:-8025}" ;;
    meilisearch) echo "${PLUME_MEILISEARCH_PORT:-7700}" ;;
    minio) echo "${PLUME_MINIO_PORT:-9000}" ;;
    *) echo "" ;;
  esac
}

plume_service_default_https_port() {
  local service="$1"
  case "${service}" in
    web) echo "${PLUME_WEB_HTTPS_PORT:-443}" ;;
    *) echo "" ;;
  esac
}

plume_service_port_in_use() {
  local port="$1"
  [[ -n "${port}" ]] || return 1
  if command -v lsof >/dev/null 2>&1; then
    lsof -nP -iTCP:"${port}" -sTCP:LISTEN >/dev/null 2>&1
    return $?
  fi
  if command -v ss >/dev/null 2>&1; then
    ss -ltn "( sport = :${port} )" 2>/dev/null | grep -q ":${port}"
    return $?
  fi
  if command -v netstat >/dev/null 2>&1; then
    netstat -an 2>/dev/null | grep -E "[.:]${port}[[:space:]]" | grep -q LISTEN
    return $?
  fi
  return 1
}

plume_service_allocate_explicit_port() {
  local label="$1"
  local preferred="$2"
  local candidate

  [[ -n "${preferred}" ]] || return 0

  if ! plume_service_port_in_use "${preferred}"; then
    printf '%s' "${preferred}"
    return 0
  fi

  candidate=$((preferred + 1))
  while (( candidate <= preferred + 50 )); do
    if ! plume_service_port_in_use "${candidate}"; then
      plume_warn "default port busy for ${label}: ${preferred}, using ${candidate}"
      printf '%s' "${candidate}"
      return 0
    fi
    candidate=$((candidate + 1))
  done

  plume_err "no available port found for ${label} (base=${preferred})"
  return 2
}

plume_service_allocate_port() {
  local service="$1"
  local preferred candidate
  preferred="$(plume_service_default_port "${service}")"
  plume_service_allocate_explicit_port "${service}" "${preferred}"
}

plume_service_log_file() {
  local service="$1"
  local mode="${2:-$(plume_mode_current)}"
  local base="${PLUME_LOG_DIR:-$HOME/.config/plume/logs}"
  mkdir -p "${base}/services/${mode}"
  printf '%s' "${base}/services/${mode}/${service}.log"
}

plume_service_append_log() {
  local service="$1"
  local line="$2"
  local mode="${3:-$(plume_mode_current)}"
  local file
  file="$(plume_service_log_file "${service}" "${mode}")"
  printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "${line}" >> "${file}"
  plume_state_db_append_event "${mode}" "${service}" "log" "${line}"
}

plume_docker_lite_service_name() {
  local service="$1"
  case "${service}" in
    web) echo "${PLUME_DOCKER_LITE_WEB_SERVICE:-nginx}" ;;
    php) echo "${PLUME_DOCKER_LITE_PHP_SERVICE:-php-fpm}" ;;
    phpmyadmin) echo "${PLUME_DOCKER_LITE_PHPMYADMIN_SERVICE:-phpmyadmin}" ;;
    composer) echo "${PLUME_DOCKER_LITE_WORKSPACE_SERVICE:-workspace}" ;;
    mariadb) echo "${PLUME_DOCKER_LITE_MARIADB_SERVICE:-mariadb}" ;;
    mysql) echo "${PLUME_DOCKER_LITE_MYSQL_SERVICE:-mysql}" ;;
    postgres) echo "${PLUME_DOCKER_LITE_POSTGRES_SERVICE:-postgres}" ;;
    redis) echo "${PLUME_DOCKER_LITE_REDIS_SERVICE:-redis}" ;;
    memcached) echo "${PLUME_DOCKER_LITE_MEMCACHED_SERVICE:-memcached}" ;;
    rabbitmq) echo "${PLUME_DOCKER_LITE_RABBITMQ_SERVICE:-rabbitmq}" ;;
    mongodb) echo "${PLUME_DOCKER_LITE_MONGODB_SERVICE:-mongodb}" ;;
    mongo_webui) echo "${PLUME_DOCKER_LITE_MONGO_WEBUI_SERVICE:-mongo-express}" ;;
    mailpit) echo "${PLUME_DOCKER_LITE_MAILPIT_SERVICE:-mailpit}" ;;
    meilisearch) echo "${PLUME_DOCKER_LITE_MEILISEARCH_SERVICE:-meilisearch}" ;;
    minio) echo "${PLUME_DOCKER_LITE_MINIO_SERVICE:-minio}" ;;
    supervisor) echo "${PLUME_DOCKER_LITE_SUPERVISOR_SERVICE:-laravel-horizon}" ;;
    horizon) echo "${PLUME_DOCKER_LITE_HORIZON_SERVICE:-laravel-horizon}" ;;
    php_worker) echo "${PLUME_DOCKER_LITE_PHP_WORKER_SERVICE:-php-worker}" ;;
    *) echo "${service}" ;;
  esac
}

plume_docker_lite_port_env_key() {
  local service="$1"
  case "${service}" in
    web)
      case "${PLUME_WEB_SERVER_DRIVER:-nginx}" in
        apache2) echo "PLUME_APACHE_HTTP_PORT" ;;
        caddy) echo "PLUME_CADDY_HTTP_PORT" ;;
        nginx|*) echo "PLUME_NGINX_HTTP_PORT" ;;
      esac
      ;;
    mariadb) echo "PLUME_MARIADB_PORT" ;;
    mysql) echo "PLUME_MYSQL_PORT" ;;
    phpmyadmin) echo "PMA_PORT" ;;
    postgres) echo "PLUME_POSTGRES_PORT" ;;
    redis) echo "PLUME_REDIS_PORT" ;;
    memcached) echo "PLUME_MEMCACHED_PORT" ;;
    rabbitmq) echo "PLUME_RABBITMQ_PORT" ;;
    mongodb) echo "PLUME_MONGODB_PORT" ;;
    mongo_webui) echo "PLUME_MONGO_WEBUI_PORT" ;;
    mailpit) echo "PLUME_MAILPIT_PORT" ;;
    meilisearch) echo "PLUME_MEILISEARCH_PORT" ;;
    minio) echo "PLUME_MINIO_PORT" ;;
    *) echo "" ;;
  esac
}

plume_docker_lite_web_https_port_env_key() {
  case "${PLUME_WEB_SERVER_DRIVER:-nginx}" in
    apache2) echo "PLUME_APACHE_HTTPS_PORT" ;;
    caddy) echo "PLUME_CADDY_HTTPS_PORT" ;;
    nginx|*) echo "PLUME_NGINX_HTTPS_PORT" ;;
  esac
}

plume_docker_lite_container_name() {
  local service="$1"
  local project_name compose_service
  project_name="${PLUME_PROJECT_NAME:-plume}"
  compose_service="$(plume_docker_lite_service_name "${service}")"
  printf '%s-%s' "${project_name}" "${compose_service}"
}

plume_docker_lite_internal_port() {
  local service="$1"
  case "${service}" in
    web) echo "80" ;;
    phpmyadmin) echo "80" ;;
    mariadb|mysql) echo "3306" ;;
    postgres) echo "5432" ;;
    redis) echo "6379" ;;
    memcached) echo "11211" ;;
    rabbitmq) echo "5672" ;;
    mongodb) echo "27017" ;;
    mongo_webui) echo "8081" ;;
    mailpit) echo "8025" ;;
    meilisearch) echo "7700" ;;
    minio) echo "9000" ;;
    *) echo "" ;;
  esac
}

plume_docker_lite_container_running() {
  local service="$1"
  local container_name
  container_name="$(plume_docker_lite_container_name "${service}")"
  if ! docker inspect "${container_name}" >/dev/null 2>&1; then
    return 1
  fi
  [[ "$(docker inspect -f '{{.State.Running}}' "${container_name}" 2>/dev/null || true)" == "true" ]]
}

plume_docker_lite_live_port() {
  local service="$1"
  local internal_port="${2:-}"
  local container_name map host_port
  if [[ -z "${internal_port}" ]]; then
    internal_port="$(plume_docker_lite_internal_port "${service}")"
  fi
  [[ -n "${internal_port}" ]] || return 1
  container_name="$(plume_docker_lite_container_name "${service}")"
  if ! docker inspect "${container_name}" >/dev/null 2>&1; then
    return 1
  fi
  map="$(docker port "${container_name}" "${internal_port}/tcp" 2>/dev/null | head -n1 || true)"
  [[ -n "${map}" ]] || return 1
  host_port="$(printf '%s' "${map}" | sed -E 's/^.*:([0-9]+)$/\1/')"
  [[ "${host_port}" =~ ^[0-9]+$ ]] || return 1
  printf '%s' "${host_port}"
}

plume_laradock_bridge_compose_file_runtime() {
  if [[ -n "${PLUME_RUNTIME_LARADOCK_COMPOSE_FILE:-}" && -f "${PLUME_RUNTIME_LARADOCK_COMPOSE_FILE}" ]]; then
    printf '%s' "${PLUME_RUNTIME_LARADOCK_COMPOSE_FILE}"
    return 0
  fi
  if [[ -n "${PLUME_LARADOCK_COMPOSE_FILE:-}" && -f "${PLUME_LARADOCK_COMPOSE_FILE}" ]]; then
    printf '%s' "${PLUME_LARADOCK_COMPOSE_FILE}"
    return 0
  fi
  if command -v plume_mode_path_get >/dev/null 2>&1; then
    local path
    path="$(plume_mode_path_get laradock-bridge || true)"
    if [[ -n "${path}" && -f "${path}/docker-compose.yml" ]]; then
      printf '%s' "${path}/docker-compose.yml"
      return 0
    fi
    if [[ -n "${path}" && -f "${path}/compose.yml" ]]; then
      printf '%s' "${path}/compose.yml"
      return 0
    fi
  fi
  return 1
}

plume_laradock_bridge_service_name() {
  local service="$1"
  case "${service}" in
    web)
      case "${PLUME_WEB_SERVER_DRIVER:-nginx}" in
        apache2) echo "${PLUME_LARADOCK_APACHE_SERVICE:-apache2}" ;;
        caddy) echo "${PLUME_LARADOCK_CADDY_SERVICE:-caddy}" ;;
        nginx|*) echo "${PLUME_LARADOCK_WEB_SERVICE:-nginx}" ;;
      esac
      ;;
    php)
      local base_service requested_version default_version versioned_service
      base_service="${PLUME_LARADOCK_PHP_SERVICE:-php-fpm}"
      requested_version="$(plume_service_resolve_php_alias "${PLUME_SERVICE_VERSION:-}")"
      default_version="$(plume_service_resolve_php_alias "${PLUME_PHP_DEFAULT_VERSION:-}")"
      if [[ -n "${PLUME_SERVICE_VERSION:-}" && "${requested_version}" != "${default_version}" ]]; then
        versioned_service="${base_service}-${requested_version}"
        if plume_laradock_bridge_compose_has_service "${versioned_service}"; then
          echo "${versioned_service}"
          return 0
        fi
      fi
      echo "${base_service}"
      ;;
    composer) echo "${PLUME_LARADOCK_WORKSPACE_SERVICE:-workspace}" ;;
    workspace) echo "${PLUME_LARADOCK_WORKSPACE_SERVICE:-workspace}" ;;
    phpmyadmin) echo "${PLUME_LARADOCK_PHPMYADMIN_SERVICE:-phpmyadmin}" ;;
    supervisor) echo "${PLUME_LARADOCK_SUPERVISOR_SERVICE:-laravel-horizon}" ;;
    horizon) echo "${PLUME_LARADOCK_HORIZON_SERVICE:-laravel-horizon}" ;;
    php_worker) echo "${PLUME_LARADOCK_PHP_WORKER_SERVICE:-php-worker}" ;;
    *) echo "${service}" ;;
  esac
}

plume_laradock_bridge_internal_port() {
  local service="$1"
  case "${service}" in
    web|nginx|apache2|caddy) echo "80" ;;
    phpmyadmin) echo "80" ;;
    mariadb|mysql) echo "3306" ;;
    postgres) echo "5432" ;;
    redis) echo "6379" ;;
    memcached) echo "11211" ;;
    rabbitmq) echo "5672" ;;
    mongodb) echo "27017" ;;
    mongo_webui) echo "8081" ;;
    mailpit) echo "8025" ;;
    meilisearch) echo "7700" ;;
    minio) echo "9000" ;;
    *) echo "" ;;
  esac
}

plume_laradock_bridge_container_id() {
  local service="$1"
  local cached
  cached="$(plume_laradock_bridge_cache_get "${service}" "id" || true)"
  if [[ -n "${cached}" ]]; then
    printf '%s' "${cached}"
    return 0
  fi
  local compose_file compose_service
  compose_file="$(plume_laradock_bridge_compose_file_runtime || true)"
  [[ -n "${compose_file}" && -f "${compose_file}" ]] || return 1
  (plume_docker_compose_has_v2 || plume_docker_compose_has_v1) || return 1
  compose_service="$(plume_laradock_bridge_service_name "${service}")"
  plume_docker_compose_exec "${compose_file}" ps -q "${compose_service}" 2>/dev/null | head -n1
}

plume_laradock_bridge_cache_clear() {
  unset PLUME_LARADOCK_CACHE_READY || true
  unset PLUME_LARADOCK_CACHE_DATA || true
  unset PLUME_LARADOCK_COMPOSE_SERVICES_READY || true
  unset PLUME_LARADOCK_COMPOSE_SERVICES || true
}

plume_laradock_bridge_cache_set() {
  local service="$1"
  local field="$2"
  local value="$3"
  local line="${service}|${field}|${value}"
  if [[ -z "${PLUME_LARADOCK_CACHE_DATA:-}" ]]; then
    PLUME_LARADOCK_CACHE_DATA="${line}"
  else
    PLUME_LARADOCK_CACHE_DATA="${PLUME_LARADOCK_CACHE_DATA}"$'\n'"${line}"
  fi
}

plume_laradock_bridge_cache_get() {
  local service="$1"
  local field="$2"
  [[ -n "${PLUME_LARADOCK_CACHE_DATA:-}" ]] || return 1
  awk -F'|' -v svc="${service}" -v fld="${field}" '
    $1 == svc && $2 == fld { print $3; exit }
  ' <<< "${PLUME_LARADOCK_CACHE_DATA}" 2>/dev/null
}

plume_laradock_bridge_runtime_cache_refresh() {
  if [[ "${PLUME_LARADOCK_CACHE_READY:-false}" == "true" ]]; then
    return 0
  fi
  local compose_file inspect_lines line id service running health ports_json
  local -a ids=()
  compose_file="$(plume_laradock_bridge_compose_file_runtime || true)"
  [[ -n "${compose_file}" && -f "${compose_file}" ]] || return 1
  (plume_docker_compose_has_v2 || plume_docker_compose_has_v1) || return 1

  plume_laradock_bridge_cache_clear
  while IFS= read -r id; do
    [[ -n "${id}" ]] && ids+=("${id}")
  done < <(plume_docker_compose_exec "${compose_file}" ps -q 2>/dev/null || true)
  [[ ${#ids[@]} -gt 0 ]] || {
    PLUME_LARADOCK_CACHE_READY="true"
    return 0
  }
  inspect_lines="$(docker inspect -f '{{.Id}}|{{ index .Config.Labels "com.docker.compose.service" }}|{{.State.Running}}||{{json .NetworkSettings.Ports}}' "${ids[@]}" 2>/dev/null || true)"
  while IFS= read -r line; do
    [[ -n "${line}" ]] || continue
    id="${line%%|*}"
    line="${line#*|}"
    service="${line%%|*}"
    [[ -n "${service}" ]] || continue
    line="${line#*|}"
    running="${line%%|*}"
    line="${line#*|}"
    health="${line%%|*}"
    ports_json="${line#*|}"
    plume_laradock_bridge_cache_set "${service}" "id" "${id}"
    plume_laradock_bridge_cache_set "${service}" "running" "${running}"
    plume_laradock_bridge_cache_set "${service}" "health" "${health}"
    plume_laradock_bridge_cache_set "${service}" "ports" "${ports_json}"
  done <<< "${inspect_lines}"
  PLUME_LARADOCK_CACHE_READY="true"
  return 0
}

plume_laradock_bridge_compose_services_refresh() {
  if [[ "${PLUME_LARADOCK_COMPOSE_SERVICES_READY:-false}" == "true" ]]; then
    return 0
  fi
  local compose_file parsed
  compose_file="$(plume_laradock_bridge_compose_file_runtime || true)"
  [[ -n "${compose_file}" && -f "${compose_file}" ]] || return 1
  parsed="$(
    awk '
      /^services:/ { in_services=1; next }
      in_services == 1 && /^[[:space:]]*$/ { next }
      in_services == 1 && /^[[:space:]]*#/ { next }
      in_services == 1 && /^[^[:space:]#]/ { exit }
      in_services == 1 && /^[[:space:]]+[A-Za-z0-9_.-]+:/ {
        line=$0
        indent=match(line, /[^ ]/) - 1
        if (indent < 0) {
          next
        }
        if (base_indent == 0) {
          base_indent=indent
        }
        if (indent != base_indent) {
          next
        }
        sub(/^[[:space:]]+/, "", line)
        sub(/:.*/, "", line)
        print line
      }
    ' "${compose_file}" 2>/dev/null || true
  )"
  PLUME_LARADOCK_COMPOSE_SERVICES="${parsed}"
  PLUME_LARADOCK_COMPOSE_SERVICES_READY="true"
  return 0
}

plume_laradock_bridge_container_running() {
  local service="$1"
  local cached
  cached="$(plume_laradock_bridge_cache_get "${service}" "running" || true)"
  if [[ -n "${cached}" ]]; then
    [[ "${cached}" == "true" ]]
    return $?
  fi
  local container_id
  container_id="$(plume_laradock_bridge_container_id "${service}" || true)"
  [[ -n "${container_id}" ]] || return 1
  [[ "$(docker inspect -f '{{.State.Running}}' "${container_id}" 2>/dev/null || true)" == "true" ]]
}

plume_laradock_bridge_live_port() {
  local service="$1"
  local internal_port="${2:-}"
  local container_id map host_port ports_json
  if [[ -z "${internal_port}" ]]; then
    internal_port="$(plume_laradock_bridge_internal_port "${service}")"
  fi
  [[ -n "${internal_port}" ]] || return 1
  ports_json="$(plume_laradock_bridge_cache_get "${service}" "ports" || true)"
  if [[ -n "${ports_json}" ]]; then
    host_port="$(printf '%s' "${ports_json}" | grep -oE "\"${internal_port}/tcp\":\\[[^]]*\"HostPort\":\"[0-9]+\"" | sed -E 's/.*"HostPort":"([0-9]+)"/\1/' | head -n1)"
    if [[ "${host_port}" =~ ^[0-9]+$ ]]; then
      printf '%s' "${host_port}"
      return 0
    fi
  fi
  if [[ "${PLUME_LARADOCK_CACHE_READY:-false}" == "true" ]]; then
    return 1
  fi
  container_id="$(plume_laradock_bridge_container_id "${service}" || true)"
  [[ -n "${container_id}" ]] || return 1
  map="$(docker port "${container_id}" "${internal_port}/tcp" 2>/dev/null | head -n1 || true)"
  [[ -n "${map}" ]] || return 1
  host_port="$(printf '%s' "${map}" | sed -E 's/^.*:([0-9]+)$/\1/')"
  [[ "${host_port}" =~ ^[0-9]+$ ]] || return 1
  printf '%s' "${host_port}"
}

plume_laradock_bridge_live_ports_all() {
  local service="$1"
  local ports_json ports
  ports_json="$(plume_laradock_bridge_cache_get "${service}" "ports" || true)"
  if [[ -n "${ports_json}" ]]; then
    ports="$(
      printf '%s' "${ports_json}" \
        | grep -oE '"HostPort":"[0-9]+"' \
        | sed -E 's/.*"HostPort":"([0-9]+)"/\1/' \
        | awk '!seen[$0]++' \
        | sort -n \
        | paste -sd ',' -
    )"
    if [[ -n "${ports}" ]]; then
      printf '%s' "${ports}"
      return 0
    fi
  fi
  return 1
}

plume_laradock_bridge_compose_has_service() {
  local service="$1"
  plume_laradock_bridge_compose_services_refresh >/dev/null 2>&1 || return 1
  grep -Fxq "${service}" <<< "${PLUME_LARADOCK_COMPOSE_SERVICES:-}"
}

plume_laradock_bridge_compose_services() {
  plume_laradock_bridge_compose_services_refresh >/dev/null 2>&1 || return 1
  printf '%s\n' "${PLUME_LARADOCK_COMPOSE_SERVICES:-}" | sed '/^$/d'
}

plume_docker_lite_resolve_port() {
  local service="$1"
  local internal_port="${2:-}"
  local default_label="${3:-$1}"
  local default_port="${4:-}"
  local live_port
  live_port="$(plume_docker_lite_live_port "${service}" "${internal_port}" || true)"
  if [[ -n "${live_port}" ]]; then
    printf '%s' "${live_port}"
    return 0
  fi
  plume_service_allocate_explicit_port "${default_label}" "${default_port}"
}

plume_docker_lite_compose_exec_required() {
  local compose_file
  local required
  required="$(plume_bool "${PLUME_DOCKER_LITE_COMPOSE_REQUIRED:-false}")"
  if ! plume_docker_lite_compose_preflight; then
    return 2
  fi
  compose_file="$(plume_docker_lite_compose_file)"
  if [[ -z "${compose_file}" || ! -f "${compose_file}" ]]; then
    if [[ "${required}" == "true" ]]; then
      plume_err "docker-lite compose file not found"
      return 2
    fi
    return 1
  fi
  if ! plume_docker_compose_has_v2 && ! plume_docker_compose_has_v1; then
    if [[ "${required}" == "true" ]]; then
      plume_err "docker compose is required for docker-lite operations"
      return 2
    fi
    return 1
  fi
  printf '%s' "${compose_file}"
}

plume_service_names() {
  cat <<'SERVICES'
web
php
composer
phpmyadmin
mariadb
mysql
postgres
redis
memcached
rabbitmq
mongodb
mongo_webui
mailpit
meilisearch
minio
supervisor
horizon
php_worker
SERVICES
}

plume_service_names_for_mode() {
  local mode="${1:-$(plume_mode_current)}"
  case "${mode}" in
    docker-lite)
      cat <<'SERVICES'
web
php
phpmyadmin
mariadb
mysql
postgres
redis
memcached
rabbitmq
mongodb
mongo_webui
mailpit
meilisearch
minio
supervisor
horizon
php_worker
SERVICES
      ;;
    laradock-bridge)
      if ! plume_laradock_bridge_compose_services; then
        cat <<'SERVICES'
web
php
phpmyadmin
mariadb
mysql
postgres
redis
memcached
rabbitmq
mongodb
mongo_webui
mailpit
meilisearch
minio
supervisor
horizon
php_worker
workspace
php-fpm
SERVICES
      fi
      ;;
    native|*)
      plume_service_names
      ;;
  esac
}

plume_service_env_key() {
  local service="$1"
  case "${service}" in
    web) echo "PLUME_WEB_SERVER_ENABLED" ;;
    php) echo "PLUME_PHP_ENABLED" ;;
    composer) echo "PLUME_COMPOSER_ENABLED" ;;
    phpmyadmin) echo "PLUME_PHPMYADMIN_ENABLED" ;;
    mariadb) echo "PLUME_MARIADB_ENABLED" ;;
    mysql) echo "PLUME_MYSQL_ENABLED" ;;
    postgres) echo "PLUME_POSTGRES_ENABLED" ;;
    redis) echo "PLUME_REDIS_ENABLED" ;;
    memcached) echo "PLUME_MEMCACHED_ENABLED" ;;
    rabbitmq) echo "PLUME_RABBITMQ_ENABLED" ;;
    mongodb) echo "PLUME_MONGODB_ENABLED" ;;
    mongo_webui) echo "PLUME_MONGO_WEBUI_ENABLED" ;;
    mailpit) echo "PLUME_MAILPIT_ENABLED" ;;
    meilisearch) echo "PLUME_MEILISEARCH_ENABLED" ;;
    minio) echo "PLUME_MINIO_ENABLED" ;;
    supervisor) echo "PLUME_SUPERVISOR_ENABLED" ;;
    horizon) echo "PLUME_HORIZON_ENABLED" ;;
    php_worker) echo "PLUME_PHP_WORKER_ENABLED" ;;
    *)
      return 1
      ;;
  esac
}

plume_service_version_env_key() {
  local service="$1"
  case "${service}" in
    web) echo "PLUME_WEB_SERVER_VERSION" ;;
    php) echo "PLUME_PHP_VERSION" ;;
    composer) echo "PLUME_COMPOSER_VERSION" ;;
    phpmyadmin) echo "PLUME_PHPMYADMIN_VERSION" ;;
    mariadb) echo "PLUME_MARIADB_VERSION" ;;
    mysql) echo "PLUME_MYSQL_VERSION" ;;
    postgres) echo "PLUME_POSTGRES_VERSION" ;;
    redis) echo "PLUME_REDIS_VERSION" ;;
    memcached) echo "PLUME_MEMCACHED_VERSION" ;;
    rabbitmq) echo "PLUME_RABBITMQ_VERSION" ;;
    mongodb) echo "PLUME_MONGODB_VERSION" ;;
    mongo_webui) echo "PLUME_MONGO_WEBUI_VERSION" ;;
    meilisearch) echo "PLUME_MEILISEARCH_VERSION" ;;
    mailpit) echo "PLUME_MAILPIT_VERSION" ;;
    minio) echo "PLUME_MINIO_VERSION" ;;
    supervisor) echo "PLUME_SUPERVISOR_VERSION" ;;
    horizon) echo "PLUME_HORIZON_VERSION" ;;
    php_worker) echo "PLUME_PHP_WORKER_VERSION" ;;
    *)
      return 1
      ;;
  esac
}

plume_service_enabled() {
  local service="$1"
  local key
  key="$(plume_service_env_key "${service}" || true)"
  if [[ -z "${key}" ]]; then
    printf '%s' "false"
    return 0
  fi
  local val="${!key:-false}"
  plume_bool "${val}"
}

plume_service_enabled_for_mode() {
  local service="$1"
  local mode="${2:-$(plume_mode_current)}"

  case "${mode}" in
    laradock-bridge)
      local mapped_service
      mapped_service="$(plume_laradock_bridge_service_name "${service}")"
      if plume_laradock_bridge_compose_has_service "${mapped_service}"; then
        printf '%s' "true"
      else
        printf '%s' "false"
      fi
      ;;
    native|docker-lite|*)
      plume_service_enabled "${service}"
      ;;
  esac
}

plume_service_resolve_php_alias() {
  local version="$1"
  local alias_key

  if [[ -z "${version}" ]]; then
    printf '%s\n' "${PLUME_PHP_DEFAULT_VERSION}"
    return 0
  fi

  if [[ "${version}" == "default" ]]; then
    printf '%s\n' "${PLUME_PHP_DEFAULT_VERSION}"
    return 0
  fi

  if [[ "${version}" == "php" || "${version}" == "${PLUME_PHP_DEFAULT_ALIAS}" ]]; then
    printf '%s\n' "${PLUME_PHP_DEFAULT_VERSION}"
    return 0
  fi

  alias_key="PLUME_PHP_ALIAS_$(printf '%s' "${version}" | tr '[:lower:]' '[:upper:]')"
  if [[ -n "${!alias_key:-}" ]]; then
    printf '%s\n' "${!alias_key}"
    return 0
  fi

  printf '%s\n' "${version}"
}

plume_service_validate_version() {
  local service="$1"
  local version="$2"

  if [[ "${service}" == "php" ]]; then
    local installed
    local found="false"
    IFS=',' read -r -a installed <<< "${PLUME_PHP_INSTALLED_VERSIONS}"
    local item
    for item in "${installed[@]}"; do
      item="$(printf '%s' "${item}" | sed 's/^ *//;s/ *$//')"
      [[ -z "${item}" ]] && continue
      [[ "${version}" == "${item}" ]] && found="true" && break
    done
    if [[ "${found}" == "false" ]]; then
      plume_err "unsupported php version: ${version}"
      return 2
    fi
    return 0
  fi

  if [[ "${version}" == "latest" ]]; then
    return 0
  fi

  if ! printf '%s' "${version}" | grep -Eq '^[0-9A-Za-z._-]+$'; then
    plume_err "unsupported version format: ${version} for ${service}"
    return 2
  fi
}

plume_service_version() {
  local service="$1"
  local request="${2:-${PLUME_SERVICE_VERSION:-}}"
  local env_key
  local version

  if [[ -z "${request}" ]]; then
    env_key="$(plume_service_version_env_key "${service}" || true)"
    if [[ -n "${env_key}" ]]; then
      version="${!env_key:-latest}"
    else
      version="latest"
    fi
  else
    version="${request}"
  fi

  if [[ "${service}" == "php" ]]; then
    version="$(plume_service_resolve_php_alias "${version}")"
  fi

  printf '%s\n' "${version}"
}

plume_service_require_dependencies() {
  local service="$1"
  local mode="${2:-$(plume_mode_current)}"

  if [[ "${service}" != "horizon" ]]; then
    if [[ "${service}" == "phpmyadmin" ]]; then
      local engine="${PMA_DB_ENGINE:-${PMA_ENGINE:-mariadb}}"
      case "${engine}" in
        mariadb|mysql) ;;
        *)
          plume_err "phpmyadmin requires PMA_DB_ENGINE to be mariadb or mysql"
          return 2
          ;;
      esac
      if [[ "$(plume_service_enabled_for_mode "${engine}" "${mode}")" != "true" ]]; then
        plume_err "phpmyadmin requires ${engine} to be enabled"
        return 2
      fi
    fi
    return 0
  fi

  if [[ "$(plume_bool "${PLUME_HORIZON_REQUIRE_SUPERVISOR:-true}")" != "true" ]]; then
    return 0
  fi

  if [[ "${mode}" == "docker-lite" ]]; then
    local supervisor_target horizon_target
    supervisor_target="$(plume_docker_lite_service_name supervisor)"
    horizon_target="$(plume_docker_lite_service_name horizon)"
    if [[ -n "${supervisor_target}" && "${supervisor_target}" == "${horizon_target}" ]]; then
      return 0
    fi
  fi

  if [[ "$(plume_service_enabled_for_mode supervisor "${mode}")" != "true" ]]; then
    plume_err "horizon requires supervisor in ${mode} mode"
    return 2
  fi
}

plume_service_contract_normalize() {
  local service="${1:-}"
  local _mode="${2:-$(plume_mode_current)}"
  local alias_key

  case "${service}" in
    php-fpm-*)
      echo "php"
      return 0
      ;;
    php-[0-9]*|php[0-9]*)
      if [[ "${service}" =~ ^php-[0-9.]+$ || "${service}" =~ ^php[0-9]+$ ]]; then
        echo "php"
        return 0
      fi
      ;;
  esac

  alias_key="PLUME_PHP_ALIAS_$(printf '%s' "${service}" | tr '[:lower:]' '[:upper:]')"
  if [[ -n "${!alias_key:-}" ]]; then
    echo "php"
    return 0
  fi

  case "${service}" in
    php-fpm) echo "php" ;;
    workspace) echo "composer" ;;
    php-worker) echo "php_worker" ;;
    laravel-horizon) echo "horizon" ;;
    *) echo "${service}" ;;
  esac
}

plume_service_contract_php_token_to_version() {
  local token="${1:-}"
  if [[ -z "${token}" ]]; then
    return 1
  fi
  if [[ "${token}" =~ ^[0-9]+\.[0-9]+([.][0-9]+)?$ ]]; then
    printf '%s\n' "${token}"
    return 0
  fi
  if [[ "${token}" =~ ^[0-9]{2}$ ]]; then
    printf '%s.%s\n' "${token:0:1}" "${token:1:1}"
    return 0
  fi
  if [[ "${token}" =~ ^[0-9]{3}$ ]]; then
    printf '%s.%s\n' "${token:0:1}" "${token:1:2}"
    return 0
  fi
  return 1
}

plume_service_contract_target_version() {
  local target="${1:-}"
  local mode="${2:-$(plume_mode_current)}"
  local normalized token=""
  normalized="$(plume_service_contract_normalize "${target}" "${mode}")"
  [[ "${normalized}" == "php" ]] || return 1

  case "${target}" in
    php|php-fpm|default|"${PLUME_PHP_DEFAULT_ALIAS:-php}")
      return 1
      ;;
    php-fpm-*)
      token="${target#php-fpm-}"
      ;;
    php-*)
      token="${target#php-}"
      ;;
    php[0-9]*)
      token="${target#php}"
      ;;
    *)
      token="${target}"
      ;;
  esac

  if token="$(plume_service_contract_php_token_to_version "${token}" 2>/dev/null)"; then
    plume_service_resolve_php_alias "${token}"
    return 0
  fi

  # Alias key resolution (php84x -> 8.4, etc.)
  local alias_key
  alias_key="PLUME_PHP_ALIAS_$(printf '%s' "${target}" | tr '[:lower:]' '[:upper:]')"
  if [[ -n "${!alias_key:-}" ]]; then
    plume_service_resolve_php_alias "${target}"
    return 0
  fi

  return 1
}

plume_service_contract_variants() {
  local candidate="${1:-}"
  local mode="${2:-$(plume_mode_current)}"
  local out="${candidate}"
  local normalized reverse_alt
  normalized="$(plume_service_contract_normalize "${candidate}" "${mode}")"
  if [[ -n "${normalized}" && "${normalized}" != "${candidate}" ]]; then
    out="${out}"$'\n'"${normalized}"
  fi
  case "${normalized}" in
    php) reverse_alt="php-fpm" ;;
    composer) reverse_alt="workspace" ;;
    php_worker) reverse_alt="php-worker" ;;
    horizon) reverse_alt="laravel-horizon" ;;
    *) reverse_alt="" ;;
  esac
  if [[ -n "${reverse_alt}" ]]; then
    if ! grep -Fxq "${reverse_alt}" <<< "${out}"; then
      out="${out}"$'\n'"${reverse_alt}"
    fi
  fi
  printf '%s\n' "${out}" | awk 'NF && !seen[$0]++'
}

plume_service_exists() {
  local candidate="$1"
  local mode="${2:-$(plume_mode_current)}"
  local variant
  while IFS= read -r variant; do
    [[ -z "${variant}" ]] && continue
    if [[ "${mode}" == "laradock-bridge" ]]; then
      if plume_laradock_bridge_compose_has_service "${variant}"; then
        return 0
      fi
      local mapped
      mapped="$(plume_laradock_bridge_service_name "${variant}")"
      if [[ -n "${mapped}" ]] && plume_laradock_bridge_compose_has_service "${mapped}"; then
        return 0
      fi
    fi
    local service
    while IFS= read -r service; do
      [[ -z "${service}" ]] && continue
      if [[ "${service}" == "${variant}" ]]; then
        return 0
      fi
    done < <(plume_service_names_for_mode "${mode}")
  done < <(plume_service_contract_variants "${candidate}" "${mode}")
  return 1
}

plume_native_php_install_brew() {
  local version="$1"
  local mm pkg
  mm="$(plume_php_version_major_minor "${version}" || true)"
  if [[ -z "${mm}" ]]; then
    plume_err "invalid php version for brew install: ${version}"
    return 2
  fi
  if ! command -v brew >/dev/null 2>&1; then
    plume_err "brew is required to install php ${mm} on macOS"
    return 2
  fi
  if plume_is_root; then
    plume_err "brew installs must run as normal user, not root"
    return 2
  fi
  pkg="php@${mm}"
  if HOMEBREW_NO_AUTO_UPDATE=1 brew list --versions "${pkg}" >/dev/null 2>&1; then
    plume_info "native php package already installed: ${pkg}"
    return 0
  fi
  plume_info "installing native php package via brew: ${pkg}"
  HOMEBREW_NO_AUTO_UPDATE=1 brew install "${pkg}" || return 2
}

plume_native_php_install_apt() {
  local version="$1"
  local mm
  mm="$(plume_php_version_major_minor "${version}" || true)"
  if [[ -z "${mm}" ]]; then
    plume_err "invalid php version for apt install: ${version}"
    return 2
  fi
  export DEBIAN_FRONTEND=noninteractive
  plume_info "installing native php packages via apt: php${mm}-cli php${mm}-fpm"
  apt update -y || return 2
  apt install -y "php${mm}-cli" "php${mm}-fpm" || {
    plume_err "apt install failed for php ${mm}. On Ubuntu you may need ondrej/php PPA."
    return 2
  }
}

plume_native_php_install_dnf() {
  local version="$1"
  local mm
  mm="$(plume_php_version_major_minor "${version}" || true)"
  if [[ -z "${mm}" ]]; then
    plume_err "invalid php version for dnf install: ${version}"
    return 2
  fi
  plume_err "dnf version-specific php install is not fully automated yet for ${mm}; install php-cli/php-fpm for ${mm} manually and retry"
  return 2
}

plume_native_php_install_host_version() {
  local version="$1"
  local driver
  driver="${PLUME_PHP_NATIVE_INSTALL_DRIVER:-$(plume_detect_package_manager)}"
  case "${driver}" in
    brew) plume_native_php_install_brew "${version}" ;;
    apt) plume_native_php_install_apt "${version}" ;;
    dnf) plume_native_php_install_dnf "${version}" ;;
    mock)
      plume_info "mock native php install driver active for ${version}"
      ;;
    *)
      plume_err "unsupported native php install driver: ${driver}"
      return 2
      ;;
  esac
}

plume_native_php_verify_host_binaries() {
  local version="$1"
  local cli_bin fpm_bin
  cli_bin="$(plume_php_find_cli_bin "${version}" || true)"
  fpm_bin="$(plume_php_find_fpm_bin "${version}" || true)"
  if [[ -z "${cli_bin}" || -z "${fpm_bin}" ]]; then
    plume_err "php ${version} install incomplete: cli/fpm binaries not found (cli=${cli_bin:-missing}, fpm=${fpm_bin:-missing})"
    return 2
  fi
  plume_info "native php ${version} binaries ready: cli=${cli_bin} fpm=${fpm_bin}"
}

plume_native_php_fpm_www_conf_for_version() {
  local version="$1"
  local conf=""
  if [[ -n "${PLUME_PHP_FPM_WWW_CONF:-}" ]]; then
    [[ -f "${PLUME_PHP_FPM_WWW_CONF}" ]] || return 1
    printf '%s' "${PLUME_PHP_FPM_WWW_CONF}"
    return 0
  fi
  while IFS= read -r conf; do
    [[ -f "${conf}" ]] || continue
    printf '%s' "${conf}"
    return 0
  done < <(plume_sites_php_fpm_pool_config_candidates "${version}")
  return 1
}

plume_native_php_canonical_fpm_listen_socket() {
  local version="$1"
  if [[ -n "${PLUME_PHP_FPM_ENSURE_LISTEN_SOCKET:-}" ]]; then
    printf '%s' "${PLUME_PHP_FPM_ENSURE_LISTEN_SOCKET}"
    return 0
  fi
  plume_sites_php_canonical_homebrew_socket "${version}"
}

plume_native_php_ensure_fpm_listen() {
  local version="$1"
  local driver canonical www_conf current
  version="$(plume_php_version_normalize "${version}")" || return 2
  driver="${PLUME_PHP_NATIVE_INSTALL_DRIVER:-$(plume_detect_package_manager)}"
  case "${driver}" in
    mock) return 0 ;;
    brew) ;;
    *) return 0 ;;
  esac

  canonical="$(plume_native_php_canonical_fpm_listen_socket "${version}" 2>/dev/null || true)"
  if [[ -z "${canonical}" ]]; then
    return 0
  fi

  www_conf="$(plume_native_php_fpm_www_conf_for_version "${version}" 2>/dev/null || true)"
  if [[ -z "${www_conf}" ]]; then
    plume_warn "native php fpm: www.conf not found for ${version}; listen not adjusted"
    return 0
  fi

  current="$(plume_sites_php_fpm_listen_from_pool_config "${version}" 2>/dev/null || true)"
  if [[ "${current}" == "${canonical}" ]]; then
    return 0
  fi

  if [[ ! -f "${www_conf}.plume-bak" ]]; then
    cp "${www_conf}" "${www_conf}.plume-bak"
  fi

  plume_info "native php fpm: pool listen ${current:-unknown} -> ${canonical} (${www_conf})"
  if ! sed -i.bak -E "s|^[[:space:]]*listen[[:space:]]*=.*|listen = ${canonical}|" "${www_conf}"; then
    plume_err "native php fpm: failed to update listen in ${www_conf}"
    return 2
  fi
  rm -f "${www_conf}.bak"
  return 0
}

plume_native_php_fpm_brew_log_tail() {
  local version="$1"
  local mm log
  mm="$(plume_php_version_major_minor "${version}" || true)"
  for log in \
    "/opt/homebrew/var/log/php-fpm.log" \
    "/usr/local/var/log/php-fpm.log" \
    "/opt/homebrew/var/log/php@${mm}.log" \
    "/usr/local/var/log/php@${mm}.log"; do
    [[ -f "${log}" ]] || continue
    tail -n 8 "${log}" 2>/dev/null || true
    return 0
  done
  return 1
}

plume_native_php_verify_fpm_after_brew_start() {
  local version="$1"
  local driver canonical attempt log_hint
  version="$(plume_php_version_normalize "${version}")" || return 2
  driver="${PLUME_PHP_NATIVE_INSTALL_DRIVER:-$(plume_detect_package_manager)}"
  case "${driver}" in
    mock) return 0 ;;
    brew) ;;
    *) return 0 ;;
  esac
  if [[ "${PLUME_PHP_FPM_VERIFY_AFTER_START:-true}" == "false" ]]; then
    return 0
  fi

  canonical="$(plume_native_php_canonical_fpm_listen_socket "${version}" 2>/dev/null || true)"
  if [[ -z "${canonical}" ]]; then
    return 0
  fi

  for attempt in 1 2 3 4 5; do
    if [[ -S "${canonical}" ]]; then
      plume_info "native php fpm: socket ready ${canonical}"
      return 0
    fi
    sleep 1
  done

  log_hint="$(plume_native_php_fpm_brew_log_tail "${version}" 2>/dev/null || true)"
  if grep -qE 'Address already in use|unable to bind listening socket' <<< "${log_hint}"; then
    plume_err "native php fpm: bind failed (often 127.0.0.1:9000 in use). Plume sets listen to ${canonical}; run services up php82 again after fixing pool config."
  else
    plume_err "native php fpm: expected socket missing after brew start: ${canonical}"
  fi
  if [[ -n "${log_hint}" ]]; then
    plume_err "native php fpm log (tail):"
    printf '%s\n' "${log_hint}" >&2
  fi
  return 2
}

plume_native_php_brew_service_name() {
  local version="$1"
  local mm pkg
  mm="$(plume_php_version_major_minor "${version}" || true)"
  if [[ -z "${mm}" ]]; then
    plume_err "invalid php version for brew service: ${version}"
    return 2
  fi
  pkg="php@${mm}"
  if command -v brew >/dev/null 2>&1; then
    if HOMEBREW_NO_AUTO_UPDATE=1 brew list --formula "${pkg}" >/dev/null 2>&1; then
      printf '%s\n' "${pkg}"
      return 0
    fi
    local default_mm=""
    default_mm="$(plume_php_version_major_minor "${PLUME_PHP_DEFAULT_VERSION:-}" || true)"
    if [[ -n "${default_mm}" && "${mm}" == "${default_mm}" ]] \
      && HOMEBREW_NO_AUTO_UPDATE=1 brew list --formula php >/dev/null 2>&1; then
      printf '%s\n' "php"
      return 0
    fi
  fi
  printf '%s\n' "${pkg}"
}

plume_native_php_start_fpm_service() {
  local version="$1"
  local driver
  version="$(plume_php_version_normalize "${version}")" || return 2
  driver="${PLUME_PHP_NATIVE_INSTALL_DRIVER:-$(plume_detect_package_manager)}"
  case "${driver}" in
    mock)
      local mm=""
      mm="$(plume_php_version_major_minor "${version}" || true)"
      plume_info "mock native php fpm start: php@${mm}"
      return 0
      ;;
    brew)
      local svc=""
      if ! command -v brew >/dev/null 2>&1; then
        plume_warn "brew missing; php-fpm start skipped for ${version}"
        return 0
      fi
      svc="$(plume_native_php_brew_service_name "${version}")" || return 2
      plume_native_php_ensure_fpm_listen "${version}" || return 2
      plume_info "native php fpm: starting ${svc} (brew services)"
      if ! HOMEBREW_NO_AUTO_UPDATE=1 brew services start "${svc}" 2>/dev/null \
        && ! HOMEBREW_NO_AUTO_UPDATE=1 brew services restart "${svc}"; then
        plume_err "brew services start failed for ${svc}"
        return 2
      fi
      plume_native_php_verify_fpm_after_brew_start "${version}" || return 2
      ;;
    apt)
      local mm="" unit=""
      mm="$(plume_php_version_major_minor "${version}" || true)"
      if [[ -z "${mm}" ]]; then
        return 2
      fi
      unit="php${mm}-fpm"
      if command -v systemctl >/dev/null 2>&1; then
        plume_info "native php fpm: starting ${unit} (systemd)"
        systemctl enable "${unit}" 2>/dev/null || true
        systemctl start "${unit}" || return 2
      else
        plume_warn "systemctl missing; php-fpm start skipped for ${version}"
      fi
      ;;
    dnf)
      plume_warn "native php fpm start not automated for dnf (${version})"
      ;;
    *)
      plume_warn "unsupported native php fpm start driver: ${driver}"
      ;;
  esac
}

plume_native_php_stop_fpm_service() {
  local version="$1"
  local driver
  version="$(plume_php_version_normalize "${version}")" || return 2
  driver="${PLUME_PHP_NATIVE_INSTALL_DRIVER:-$(plume_detect_package_manager)}"
  case "${driver}" in
    mock)
      local mm=""
      mm="$(plume_php_version_major_minor "${version}" || true)"
      plume_info "mock native php fpm stop: php@${mm}"
      return 0
      ;;
    brew)
      local svc=""
      if ! command -v brew >/dev/null 2>&1; then
        return 0
      fi
      svc="$(plume_native_php_brew_service_name "${version}")" || return 2
      plume_info "native php fpm: stopping ${svc} (brew services)"
      HOMEBREW_NO_AUTO_UPDATE=1 brew services stop "${svc}" 2>/dev/null || true
      ;;
    apt)
      local mm="" unit=""
      mm="$(plume_php_version_major_minor "${version}" || true)"
      if [[ -z "${mm}" ]]; then
        return 2
      fi
      unit="php${mm}-fpm"
      if command -v systemctl >/dev/null 2>&1; then
        plume_info "native php fpm: stopping ${unit} (systemd)"
        systemctl stop "${unit}" 2>/dev/null || true
      fi
      ;;
    dnf|*)
      ;;
  esac
}

plume_native_php_ensure_ready_for_start() {
  local version="$1"
  local installed_csv needs_provision="false"
  version="$(plume_php_version_normalize "${version}")" || return 2
  installed_csv="$(plume_php_versions_csv_normalize "${PLUME_PHP_INSTALLED_VERSIONS}")" || return 2

  if ! plume_php_csv_has_version "${installed_csv}" "${version}"; then
    needs_provision="true"
  fi
  if ! plume_native_php_verify_host_binaries "${version}" >/dev/null 2>&1; then
    needs_provision="true"
  fi

  if [[ "${needs_provision}" == "true" ]]; then
    plume_info "native php ${version} auto-provision: triggered by services up php"
    plume_require_native_install_privileges || return 2
    plume_native_php_install_host_version "${version}" || return 2
    plume_native_php_verify_host_binaries "${version}" || return 2
    plume_php_register_installed_version "${version}" || return 2
  fi
}

plume_native_php_extensions_autosync_profile() {
  local raw="${PLUME_PHP_EXTENSIONS_AUTO_SYNC_PROFILE:-matrix}"
  case "${raw}" in
    matrix|target|default)
      printf '%s\n' "${raw}"
      ;;
    *)
      plume_warn "invalid PLUME_PHP_EXTENSIONS_AUTO_SYNC_PROFILE=${raw}; using matrix"
      printf '%s\n' "matrix"
      ;;
  esac
}

plume_native_php_extensions_autosync_on_up() {
  local target_version="${1:-}"
  local strict profile default_v csv merged version seen=""
  [[ -n "${target_version}" ]] || return 0
  if [[ "$(plume_bool "${PLUME_PHP_EXTENSIONS_AUTO_SYNC:=true}")" != "true" ]]; then
    return 0
  fi
  strict="$(plume_php_extensions_strict)"
  profile="$(plume_native_php_extensions_autosync_profile)"
  case "${profile}" in
    target)
      plume_info "native php extension auto-sync profile=target version=${target_version}"
      plume_php_extensions_sync_version "${target_version}" "${strict}" || return 2
      ;;
    default)
      default_v="$(plume_php_version_normalize "${PLUME_PHP_DEFAULT_VERSION:-${PLUME_PHP_VERSION:-8.3}}")" || return 2
      plume_info "native php extension auto-sync profile=default version=${default_v}"
      plume_php_extensions_sync_version "${default_v}" "${strict}" || return 2
      ;;
    matrix)
      default_v="$(plume_php_version_normalize "${PLUME_PHP_DEFAULT_VERSION:-${PLUME_PHP_VERSION:-8.3}}")" || return 2
      csv="$(plume_php_versions_csv_normalize "${PLUME_PHP_INSTALLED_VERSIONS:-${default_v}}")" || return 2
      merged="${csv},${default_v}"
      plume_info "native php extension auto-sync profile=matrix versions=${merged}"
      IFS=',' read -r -a _ext_versions <<< "${merged}"
      for version in "${_ext_versions[@]}"; do
        version="$(printf '%s' "${version}" | sed 's/^ *//;s/ *$//')"
        [[ -n "${version}" ]] || continue
        if [[ ",${seen}," == *",${version},"* ]]; then
          continue
        fi
        seen="${seen},${version}"
        plume_php_extensions_sync_version "${version}" "${strict}" || return 2
      done
      ;;
  esac
}

plume_native_php_ensure_matrix_ready() {
  local default_v csv merged version seen=""
  default_v="$(plume_php_version_normalize "${PLUME_PHP_DEFAULT_VERSION:-${PLUME_PHP_VERSION:-8.3}}")" || return 2
  csv="$(plume_php_versions_csv_normalize "${PLUME_PHP_INSTALLED_VERSIONS:-${default_v}}")" || return 2
  merged="${csv},${default_v}"

  plume_info "native php matrix ensure: ${merged}"
  IFS=',' read -r -a _matrix_versions <<< "${merged}"
  for version in "${_matrix_versions[@]}"; do
    version="$(printf '%s' "${version}" | sed 's/^ *//;s/ *$//')"
    [[ -n "${version}" ]] || continue
    if [[ ",${seen}," == *",${version},"* ]]; then
      continue
    fi
    seen="${seen},${version}"
    plume_native_php_ensure_ready_for_start "${version}" || return 2
  done
}

plume_service_install_native() {
  local service="$1"
  local normalized
  normalized="$(plume_service_version "${service}")"
  if [[ "${service}" == "php" ]]; then
    normalized="$(plume_php_version_normalize "${normalized}")" || return 2
  else
    if ! plume_service_validate_version "${service}" "${normalized}"; then
      return 2
    fi
  fi
  if [[ "${service}" == "php" ]]; then
    plume_native_php_install_host_version "${normalized}" || return 2
    plume_native_php_verify_host_binaries "${normalized}" || return 2
    plume_php_register_installed_version "${normalized}" || return 2
  else
    plume_native_host_provision_install "${service}" || return 2
  fi
  local allocated_port=""
  allocated_port="$(plume_service_allocate_port "${service}")" || return 2
  if [[ -n "${allocated_port}" ]]; then
    plume_services_ports_set "${service}" "${allocated_port}" native
  fi
  plume_services_runtime_set "${service}" "installed" "true" native
  plume_services_runtime_set "${service}" "version" "${normalized}" native
  plume_service_append_log "${service}" "install (native) version=${normalized} port=${allocated_port:-none}" native
  plume_info "install hook: ${service} (native) [version=${normalized}]"
}

plume_service_start_native() {
  local service="$1"
  local normalized
  normalized="$(plume_service_version "${service}")"
  if [[ "${service}" == "php" ]]; then
    normalized="$(plume_php_version_normalize "${normalized}")" || return 2
    if [[ "$(plume_bool "${PLUME_PHP_AUTOPROVISION_ALL_ON_UP:-true}")" == "true" ]]; then
      plume_native_php_ensure_matrix_ready || return 2
    fi
    plume_native_php_ensure_ready_for_start "${normalized}" || return 2
    plume_native_php_extensions_autosync_on_up "${normalized}" || return 2
  else
    if ! plume_service_validate_version "${service}" "${normalized}"; then
      return 2
    fi
  fi
  if ! plume_service_require_dependencies "${service}" native; then
    return 2
  fi
  if [[ "${service}" == "php" ]]; then
    plume_native_php_start_fpm_service "${normalized}" || return 2
  fi
  local allocated_port=""
  allocated_port="$(plume_service_allocate_port "${service}")" || return 2
  if [[ -n "${allocated_port}" ]]; then
    plume_services_ports_set "${service}" "${allocated_port}" native
  fi
  plume_services_runtime_set "${service}" "running" "true" native
  plume_services_runtime_set "${service}" "version" "${normalized}" native
  plume_native_host_provision_start "${service}" || return 2
  plume_service_append_log "${service}" "start (native) version=${normalized} port=${allocated_port:-none}" native
  plume_info "start hook: ${service} (native) [version=${normalized}]"
}

plume_service_stop_native() {
  local service="$1"
  if [[ "${service}" == "php" ]]; then
    local normalized=""
    normalized="$(plume_service_version "${service}")"
    normalized="$(plume_php_version_normalize "${normalized}")" || return 2
    plume_native_php_stop_fpm_service "${normalized}" || return 2
  fi
  plume_native_host_provision_stop "${service}" || return 2
  plume_services_runtime_set "${service}" "running" "false" native
  plume_service_append_log "${service}" "stop (native)" native
  plume_info "stop hook: ${service} (native)"
}

plume_service_install_docker_lite() {
  local service="$1"
  if ! command -v docker >/dev/null 2>&1; then
    plume_warn "docker-lite service install skipped: docker missing"
    return 0
  fi
  local normalized
  normalized="$(plume_service_version "${service}")"
  if ! plume_service_validate_version "${service}" "${normalized}"; then
    return 2
  fi
  if ! plume_service_require_dependencies "${service}" docker-lite; then
    return 2
  fi
  local compose_file compose_service
  compose_file="$(plume_docker_lite_compose_exec_required)" || {
    if [[ "$?" -eq 2 ]]; then
      return 2
    fi
    compose_file=""
  }
  compose_service="$(plume_docker_lite_service_name "${service}")"
  if [[ -n "${compose_file}" ]]; then
    plume_docker_compose_exec "${compose_file}" pull "${compose_service}" || true
  else
    plume_warn "docker-lite install running in stub mode: compose not available"
  fi
  plume_services_runtime_set "${service}" "installed" "true" docker-lite
  plume_services_runtime_set "${service}" "version" "${normalized}" docker-lite
  plume_service_append_log "${service}" "install (docker-lite) version=${normalized} compose_service=${compose_service}" docker-lite
  plume_info "install hook: ${service} (docker-lite) [version=${normalized}]"
}

plume_service_start_docker_lite() {
  local service="$1"
  if ! command -v docker >/dev/null 2>&1; then
    plume_warn "docker-lite service start skipped: docker missing"
    return 0
  fi
  local normalized
  normalized="$(plume_service_version "${service}")"
  if ! plume_service_validate_version "${service}" "${normalized}"; then
    return 2
  fi
  if ! plume_service_require_dependencies "${service}" docker-lite; then
    return 2
  fi
  local allocated_port=""
  local allocated_https_port=""
  allocated_port="$(plume_docker_lite_resolve_port "${service}" "" "${service}" "$(plume_service_default_port "${service}")")" || return 2
  if [[ -n "${allocated_port}" ]]; then
    plume_services_ports_set "${service}" "${allocated_port}" docker-lite
  fi
  if [[ "${service}" == "web" ]]; then
    local preferred_https_port
    preferred_https_port="$(plume_service_default_https_port web)"
    allocated_https_port="$(plume_docker_lite_resolve_port "web" "443" "web_https" "${preferred_https_port}")" || return 2
    if [[ -n "${allocated_https_port}" ]]; then
      plume_services_ports_set "web_https" "${allocated_https_port}" docker-lite
    fi
  fi

  local port_env_key=""
  local https_port_env_key=""
  local had_port_env="false"
  local old_port_env=""
  local had_https_port_env="false"
  local old_https_port_env=""
  local had_web_port="false"
  local old_web_port=""
  local had_web_https_port="false"
  local old_web_https_port=""
  if [[ -n "${allocated_port}" ]]; then
    port_env_key="$(plume_docker_lite_port_env_key "${service}")"
    if [[ -n "${port_env_key}" ]]; then
      if [[ -n "${!port_env_key+x}" ]]; then
        had_port_env="true"
        old_port_env="${!port_env_key}"
      fi
      export "${port_env_key}=${allocated_port}"
    fi
    if [[ "${service}" == "web" ]]; then
      if [[ -n "${PLUME_WEB_PORT+x}" ]]; then
        had_web_port="true"
        old_web_port="${PLUME_WEB_PORT}"
      fi
      export "PLUME_WEB_PORT=${allocated_port}"
    fi
  fi
  if [[ "${service}" == "web" && -n "${allocated_https_port}" ]]; then
    https_port_env_key="$(plume_docker_lite_web_https_port_env_key)"
    if [[ -n "${https_port_env_key}" ]]; then
      if [[ -n "${!https_port_env_key+x}" ]]; then
        had_https_port_env="true"
        old_https_port_env="${!https_port_env_key}"
      fi
      export "${https_port_env_key}=${allocated_https_port}"
    fi
    if [[ -n "${PLUME_WEB_HTTPS_PORT+x}" ]]; then
      had_web_https_port="true"
      old_web_https_port="${PLUME_WEB_HTTPS_PORT}"
    fi
    export "PLUME_WEB_HTTPS_PORT=${allocated_https_port}"
  fi

  local compose_file compose_service
  compose_file="$(plume_docker_lite_compose_exec_required)" || {
    if [[ "$?" -eq 2 ]]; then
      return 2
    fi
    compose_file=""
  }
  compose_service="$(plume_docker_lite_service_name "${service}")"
  if [[ -n "${compose_file}" ]]; then
    plume_docker_compose_exec "${compose_file}" up -d "${compose_service}" || {
      if [[ "${had_port_env}" == "true" ]]; then
        export "${port_env_key}=${old_port_env}"
      elif [[ -n "${port_env_key}" ]]; then
        unset "${port_env_key}" || true
      fi
      if [[ "${had_web_port}" == "true" ]]; then
        export "PLUME_WEB_PORT=${old_web_port}"
      elif [[ "${service}" == "web" ]]; then
        unset PLUME_WEB_PORT || true
      fi
      if [[ "${had_https_port_env}" == "true" ]]; then
        export "${https_port_env_key}=${old_https_port_env}"
      elif [[ -n "${https_port_env_key}" ]]; then
        unset "${https_port_env_key}" || true
      fi
      if [[ "${had_web_https_port}" == "true" ]]; then
        export "PLUME_WEB_HTTPS_PORT=${old_web_https_port}"
      elif [[ "${service}" == "web" ]]; then
        unset PLUME_WEB_HTTPS_PORT || true
      fi
      plume_err "docker-lite start failed for ${service} (compose service: ${compose_service})"
      return 2
    }
  else
    plume_warn "docker-lite start running in stub mode: compose not available"
  fi

  if [[ "${had_port_env}" == "true" ]]; then
    export "${port_env_key}=${old_port_env}"
  elif [[ -n "${port_env_key}" ]]; then
    unset "${port_env_key}" || true
  fi
  if [[ "${had_web_port}" == "true" ]]; then
    export "PLUME_WEB_PORT=${old_web_port}"
  elif [[ "${service}" == "web" ]]; then
    unset PLUME_WEB_PORT || true
  fi
  if [[ "${had_https_port_env}" == "true" ]]; then
    export "${https_port_env_key}=${old_https_port_env}"
  elif [[ -n "${https_port_env_key}" ]]; then
    unset "${https_port_env_key}" || true
  fi
  if [[ "${had_web_https_port}" == "true" ]]; then
    export "PLUME_WEB_HTTPS_PORT=${old_web_https_port}"
  elif [[ "${service}" == "web" ]]; then
    unset PLUME_WEB_HTTPS_PORT || true
  fi

  plume_services_runtime_set "${service}" "running" "true" docker-lite
  plume_services_runtime_set "${service}" "version" "${normalized}" docker-lite
  plume_service_append_log "${service}" "start (docker-lite) version=${normalized} compose_service=${compose_service}" docker-lite
  plume_info "start hook: ${service} (docker-lite) [version=${normalized}]"
}

plume_service_stop_docker_lite() {
  local service="$1"
  if ! command -v docker >/dev/null 2>&1; then
    plume_warn "docker-lite service stop skipped: docker missing"
    return 0
  fi
  local compose_file compose_service
  compose_file="$(plume_docker_lite_compose_exec_required)" || {
    if [[ "$?" -eq 2 ]]; then
      return 2
    fi
    compose_file=""
  }
  compose_service="$(plume_docker_lite_service_name "${service}")"
  if [[ -n "${compose_file}" ]]; then
    plume_docker_compose_exec "${compose_file}" stop "${compose_service}" || true
  else
    plume_warn "docker-lite stop running in stub mode: compose not available"
  fi
  plume_services_runtime_set "${service}" "running" "false" docker-lite
  plume_service_append_log "${service}" "stop (docker-lite) compose_service=${compose_service}" docker-lite
  plume_info "stop hook: ${service} (docker-lite)"
}

plume_service_install_laradock_bridge() {
  local service="$1"
  if ! command -v docker >/dev/null 2>&1; then
    plume_warn "laradock-bridge service install skipped: docker missing"
    return 0
  fi
  local normalized
  normalized="$(plume_service_version "${service}")"
  if ! plume_service_validate_version "${service}" "${normalized}"; then
    return 2
  fi
  if ! plume_service_require_dependencies "${service}" laradock-bridge; then
    return 2
  fi
  local compose_file compose_service
  compose_file="$(plume_laradock_bridge_compose_file_runtime)" || {
    plume_err "laradock compose file not found"
    return 2
  }
  if ! plume_docker_compose_has_v2 && ! plume_docker_compose_has_v1; then
    plume_err "docker compose is required for laradock-bridge operations"
    return 2
  fi
  compose_service="$(plume_laradock_bridge_service_name "${service}")"
  plume_docker_compose_exec "${compose_file}" pull "${compose_service}" || true
  plume_services_runtime_set "${service}" "installed" "true" laradock-bridge
  plume_services_runtime_set "${service}" "version" "${normalized}" laradock-bridge
  plume_service_append_log "${service}" "install (laradock-bridge) version=${normalized} compose_service=${compose_service}" laradock-bridge
  plume_info "install hook: ${service} (laradock-bridge) [version=${normalized}]"
}

plume_service_start_laradock_bridge() {
  local service="$1"
  if ! command -v docker >/dev/null 2>&1; then
    plume_warn "laradock-bridge service start skipped: docker missing"
    return 0
  fi
  local normalized
  normalized="$(plume_service_version "${service}")"
  if ! plume_service_validate_version "${service}" "${normalized}"; then
    return 2
  fi
  if ! plume_service_require_dependencies "${service}" laradock-bridge; then
    return 2
  fi
  local compose_file compose_service
  compose_file="$(plume_laradock_bridge_compose_file_runtime)" || {
    plume_err "laradock compose file not found"
    return 2
  }
  if ! plume_docker_compose_has_v2 && ! plume_docker_compose_has_v1; then
    plume_err "docker compose is required for laradock-bridge operations"
    return 2
  fi
  compose_service="$(plume_laradock_bridge_service_name "${service}")"
  plume_docker_compose_exec "${compose_file}" up -d "${compose_service}" || {
    plume_err "laradock-bridge start failed for ${service} (compose service: ${compose_service})"
    return 2
  }
  local live_port=""
  live_port="$(plume_laradock_bridge_live_port "${service}" || true)"
  if [[ -n "${live_port}" ]]; then
    plume_services_ports_set "${service}" "${live_port}" laradock-bridge
  fi
  plume_services_runtime_set "${service}" "running" "true" laradock-bridge
  plume_services_runtime_set "${service}" "version" "${normalized}" laradock-bridge
  plume_service_append_log "${service}" "start (laradock-bridge) version=${normalized} compose_service=${compose_service}" laradock-bridge
  plume_info "start hook: ${service} (laradock-bridge) [version=${normalized}]"
}

plume_service_stop_laradock_bridge() {
  local service="$1"
  if ! command -v docker >/dev/null 2>&1; then
    plume_warn "laradock-bridge service stop skipped: docker missing"
    return 0
  fi
  local compose_file compose_service
  compose_file="$(plume_laradock_bridge_compose_file_runtime)" || {
    plume_err "laradock compose file not found"
    return 2
  }
  if ! plume_docker_compose_has_v2 && ! plume_docker_compose_has_v1; then
    plume_err "docker compose is required for laradock-bridge operations"
    return 2
  fi
  compose_service="$(plume_laradock_bridge_service_name "${service}")"
  plume_docker_compose_exec "${compose_file}" stop "${compose_service}" || true
  plume_services_runtime_set "${service}" "running" "false" laradock-bridge
  plume_service_append_log "${service}" "stop (laradock-bridge) compose_service=${compose_service}" laradock-bridge
  plume_info "stop hook: ${service} (laradock-bridge)"
}

plume_service_install() {
  local service="$1"
  local mode="${PLUME_MODE:-$(plume_mode_current)}"
  case "${mode}" in
    docker-lite)
      plume_service_install_docker_lite "${service}"
      ;;
    laradock-bridge)
      plume_service_install_laradock_bridge "${service}"
      ;;
    native|*)
      plume_service_install_native "${service}"
      ;;
  esac
}

plume_service_start() {
  local service="$1"
  local mode="${PLUME_MODE:-$(plume_mode_current)}"
  case "${mode}" in
    docker-lite)
      plume_service_start_docker_lite "${service}"
      ;;
    laradock-bridge)
      plume_service_start_laradock_bridge "${service}"
      ;;
    native|*)
      plume_service_start_native "${service}"
      ;;
  esac
}

plume_service_stop() {
  local service="$1"
  local mode="${PLUME_MODE:-$(plume_mode_current)}"
  case "${mode}" in
    docker-lite)
      plume_service_stop_docker_lite "${service}"
      ;;
    laradock-bridge)
      plume_service_stop_laradock_bridge "${service}"
      ;;
    native|*)
      plume_service_stop_native "${service}"
      ;;
  esac
}

plume_service_status() {
  local service="$1"
  local mode="${2:-$(plume_mode_current)}"
  local enabled running health port version
  enabled="$(plume_service_enabled_for_mode "${service}" "${mode}")"
  version="$(plume_service_version "${service}")"
  if [[ "${mode}" == "docker-lite" ]]; then
    local live_port=""
    local live_https_port=""
    local https_port=""
    health="$(plume_service_health "${service}" "${mode}")"
    case "${health}" in
      healthy) running="true" ;;
      stopped|disabled) running="false" ;;
      *) running="$(plume_services_runtime_get "${service}" running "${mode}" || true)" ;;
    esac
    port="$(plume_services_ports_get "${service}" "${mode}" || true)"
    live_port="$(plume_docker_lite_live_port "${service}" || true)"
    if [[ -n "${live_port}" ]]; then
      port="${live_port}"
      plume_services_ports_set "${service}" "${live_port}" docker-lite
    fi
    if [[ "${service}" == "web" ]]; then
      https_port="$(plume_services_ports_get "web_https" "${mode}" || true)"
      live_https_port="$(plume_docker_lite_live_port "${service}" "443" || true)"
      if [[ -n "${live_https_port}" ]]; then
        https_port="${live_https_port}"
        plume_services_ports_set "web_https" "${live_https_port}" docker-lite
      fi
      if [[ -n "${https_port}" ]]; then
        if [[ -n "${port}" ]]; then
          port="${port},${https_port}"
        else
          port="${https_port}"
        fi
      fi
    fi
    [[ -n "${port}" ]] || port="-"
  elif [[ "${mode}" == "laradock-bridge" ]]; then
    local live_port=""
    health="$(plume_service_health "${service}" "${mode}")"
    case "${health}" in
      healthy) running="true" ;;
      stopped|disabled) running="false" ;;
      *) running="$(plume_services_runtime_get "${service}" running "${mode}" || true)" ;;
    esac
    port="$(plume_services_ports_get "${service}" "${mode}" || true)"
    live_port="$(plume_laradock_bridge_live_ports_all "${service}" || true)"
    if [[ -z "${live_port}" ]]; then
      live_port="$(plume_laradock_bridge_live_port "${service}" || true)"
    fi
    if [[ -n "${live_port}" ]]; then
      port="${live_port}"
    fi
    [[ -n "${port}" ]] || port="-"
  else
    running="$(plume_services_runtime_get "${service}" running "${mode}" || true)"
    port="$(plume_services_ports_get "${service}" "${mode}" || true)"
    [[ -n "${port}" ]] || port="-"
    if [[ -z "${running}" ]]; then
      running="false"
    fi
    if [[ "${enabled}" != "true" ]]; then
      health="disabled"
    elif [[ "${running}" == "true" ]]; then
      health="healthy"
    else
      health="stopped"
    fi
  fi
  printf '%s\t%s\t%s\t%s\t%s\t%s\n' "${service}" "${enabled}" "${running}" "${health}" "${port}" "${version}"
}

plume_service_health() {
  local service="$1"
  local mode="${2:-$(plume_mode_current)}"
  if [[ "${mode}" == "docker-lite" ]]; then
    local compose_file compose_service container_id
    local running
    local enabled
    enabled="$(plume_service_enabled_for_mode "${service}" "${mode}")"
    compose_file="$(plume_docker_lite_compose_file)"
    compose_service="$(plume_docker_lite_service_name "${service}")"
    if [[ -n "${compose_file}" && -f "${compose_file}" ]] && (plume_docker_compose_has_v2 || plume_docker_compose_has_v1); then
      container_id="$(plume_docker_compose_exec "${compose_file}" ps -q "${compose_service}" 2>/dev/null || true)"
      if [[ -n "${container_id}" ]]; then
        running="$(docker inspect -f '{{.State.Running}}' "${container_id}" 2>/dev/null || true)"
        if [[ "${running}" == "true" ]]; then
          printf '%s' "healthy"
          return 0
        fi
      fi
    fi
    if command -v docker >/dev/null 2>&1 && plume_docker_lite_container_running "${service}"; then
      printf '%s' "healthy"
      return 0
    fi
    if [[ "${enabled}" != "true" ]]; then
      printf '%s' "disabled"
      return 0
    fi
    printf '%s' "stopped"
    return 0
  fi
  if [[ "${mode}" == "laradock-bridge" ]]; then
    local enabled cached_running cached_health
    enabled="$(plume_service_enabled_for_mode "${service}" "${mode}")"
    plume_laradock_bridge_runtime_cache_refresh >/dev/null 2>&1 || true
    cached_running="$(plume_laradock_bridge_cache_get "$(plume_laradock_bridge_service_name "${service}")" "running" || true)"
    cached_health="$(plume_laradock_bridge_cache_get "$(plume_laradock_bridge_service_name "${service}")" "health" || true)"
    if [[ "${cached_running}" == "true" ]]; then
      case "${cached_health}" in
        healthy) printf '%s' "healthy" ; return 0 ;;
        starting) printf '%s' "starting" ; return 0 ;;
        unhealthy) printf '%s' "unhealthy" ; return 0 ;;
        *) printf '%s' "healthy" ; return 0 ;;
      esac
    fi
    if [[ "${enabled}" != "true" ]]; then
      printf '%s' "disabled"
      return 0
    fi
    printf '%s' "stopped"
    return 0
  fi
  local running enabled
  enabled="$(plume_service_enabled_for_mode "${service}" "${mode}")"
  running="$(plume_services_runtime_get "${service}" running "${mode}" || true)"
  [[ -n "${running}" ]] || running="false"
  if [[ "${enabled}" != "true" ]]; then
    printf '%s' "disabled"
    return 0
  fi
  if [[ "${running}" == "true" ]]; then
    printf '%s' "healthy"
    return 0
  fi
  printf '%s' "stopped"
}

plume_service_logs() {
  local service="$1"
  local mode="${2:-$(plume_mode_current)}"
  local tail_count="${3:-30}"
  local follow="${4:-false}"
  if [[ "${mode}" == "docker-lite" ]]; then
    local compose_file compose_service
    compose_file="$(plume_docker_lite_compose_file)"
    compose_service="$(plume_docker_lite_service_name "${service}")"
    if [[ -n "${compose_file}" && -f "${compose_file}" ]] && (plume_docker_compose_has_v2 || plume_docker_compose_has_v1); then
      if [[ "${follow}" == "true" ]]; then
        plume_docker_compose_exec "${compose_file}" logs -f --tail "${tail_count}" "${compose_service}" 2>/dev/null || true
      else
        plume_docker_compose_exec "${compose_file}" logs --tail "${tail_count}" "${compose_service}" 2>/dev/null || true
      fi
      return 0
    fi
  elif [[ "${mode}" == "laradock-bridge" ]]; then
    local compose_file compose_service
    compose_file="$(plume_laradock_bridge_compose_file_runtime || true)"
    compose_service="$(plume_laradock_bridge_service_name "${service}")"
    if [[ -n "${compose_file}" && -f "${compose_file}" ]] && (plume_docker_compose_has_v2 || plume_docker_compose_has_v1); then
      if [[ "${follow}" == "true" ]]; then
        plume_docker_compose_exec "${compose_file}" logs -f --tail "${tail_count}" "${compose_service}" 2>/dev/null || true
      else
        plume_docker_compose_exec "${compose_file}" logs --tail "${tail_count}" "${compose_service}" 2>/dev/null || true
      fi
      return 0
    fi
  fi
  local file
  file="$(plume_service_log_file "${service}" "${mode}")"
  if [[ ! -f "${file}" ]]; then
    printf '%s\n' "no logs yet for ${service} (${mode})"
    return 0
  fi
  if [[ "${follow}" == "true" ]]; then
    tail -n "${tail_count}" -f "${file}"
  else
    tail -n "${tail_count}" "${file}"
  fi
}
