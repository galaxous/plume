#!/usr/bin/env bash
set -euo pipefail

plume_load_php_state_from_disk() {
  local php_state_file
  php_state_file="$(plume_state_dir)/php.env"
  if [[ ! -f "${php_state_file}" ]]; then
    return 0
  fi
  local key value
  while IFS='=' read -r key value; do
    [[ -z "${key}" ]] && continue
    [[ "${key}" =~ ^# ]] && continue
    if [[ ! "${key}" =~ ^PLUME_PHP_[A-Z0-9_]+$ ]]; then
      continue
    fi
    export "${key}=${value}"
  done < "${php_state_file}"
}

plume_load_defaults() {
  : "${PLUME_APP_NAME:=plume}"
  : "${PLUME_STATE_DIR:=$HOME/.config/plume/state}"
  : "${PLUME_LOG_DIR:=$HOME/.config/plume/logs}"
  : "${PLUME_HOSTS_FILE:=/etc/hosts}"
  : "${PLUME_SITE_HOSTS_SYNC:=true}"
  : "${PLUME_SITE_HOSTS_IP:=127.0.0.1}"
  : "${PLUME_SITE_HOSTS_REQUIRED:=false}"
  : "${PLUME_SITE_RELOAD_REQUIRED:=false}"
  : "${PLUME_SITE_RELOAD_VALIDATE:=true}"
  : "${PLUME_SITE_NGINX_STRICT:=false}"
  : "${PLUME_NGINX_INCLUDE_DIR:=}"
  : "${PLUME_SITE_APACHE2_STRICT:=false}"
  : "${PLUME_APACHE2_INCLUDE_DIR:=}"
  : "${PLUME_SITE_CADDY_STRICT:=false}"
  : "${PLUME_CADDY_INCLUDE_DIR:=}"

  plume_load_php_state_from_disk

  if [[ -f "${PLUME_STATE_DIR}/mode" ]]; then
    PLUME_MODE="$(cat "${PLUME_STATE_DIR}/mode")"
  else
    PLUME_MODE="native"
  fi

  # Minimal default profile (core true).
  : "${PLUME_WEB_SERVER_ENABLED:=true}"
  : "${PLUME_PHP_ENABLED:=true}"
  : "${PLUME_COMPOSER_ENABLED:=true}"
  : "${PLUME_MARIADB_ENABLED:=true}"
  : "${PLUME_WEB_SERVER_VERSION:=latest}"
  : "${PLUME_PHP_VERSION:=8.3}"
  : "${PLUME_COMPOSER_VERSION:=latest}"
  : "${PLUME_MARIADB_VERSION:=11.0}"
  : "${PLUME_WEB_PORT:=80}"
  : "${PLUME_WEB_HTTPS_PORT:=443}"
  : "${PLUME_MARIADB_PORT:=3306}"

  # Optional defaults false.
  : "${PLUME_MYSQL_ENABLED:=false}"
  : "${PLUME_MYSQL_PORT:=3306}"
  : "${PLUME_POSTGRES_ENABLED:=false}"
  : "${PLUME_POSTGRES_PORT:=5432}"
  : "${PLUME_REDIS_ENABLED:=false}"
  : "${PLUME_REDIS_PORT:=6379}"
  : "${PLUME_MEMCACHED_ENABLED:=false}"
  : "${PLUME_MEMCACHED_PORT:=11211}"
  : "${PLUME_RABBITMQ_ENABLED:=false}"
  : "${PLUME_RABBITMQ_PORT:=5672}"
  : "${PLUME_MONGODB_ENABLED:=false}"
  : "${PLUME_MONGODB_PORT:=27017}"
  : "${PLUME_MONGO_WEBUI_ENABLED:=false}"
  : "${PLUME_MONGO_WEBUI_PORT:=8081}"
  : "${PLUME_MAILPIT_ENABLED:=false}"
  : "${PLUME_MAILPIT_PORT:=8025}"
  : "${PLUME_MEILISEARCH_ENABLED:=false}"
  : "${PLUME_MEILISEARCH_PORT:=7700}"
  : "${PLUME_MINIO_ENABLED:=false}"
  : "${PLUME_MINIO_PORT:=9000}"
  : "${PLUME_SUPERVISOR_ENABLED:=false}"
  : "${PLUME_HORIZON_ENABLED:=false}"
  : "${PLUME_PHP_WORKER_ENABLED:=false}"
  : "${PLUME_HORIZON_REQUIRE_SUPERVISOR:=true}"
  : "${PLUME_PHP_DEFAULT_ALIAS:=php}"
  : "${PLUME_PHP_DEFAULT_VERSION:=8.3}"
  : "${PLUME_PHP_INSTALLED_VERSIONS:=8.1,8.2,8.3}"
  : "${PLUME_PHP_ALIAS_PHP81:=8.1}"
  : "${PLUME_PHP_ALIAS_PHP82:=8.2}"
  : "${PLUME_PHP_ALIAS_PHP83:=8.3}"
  : "${PLUME_PHP_EXTENSIONS_GLOBAL:=}"
  : "${PLUME_PHP_EXT_PRESET:=none}"
  : "${PLUME_PHP_EXTENSIONS_STRICT:=true}"
  : "${PLUME_PHP_EXTENSIONS_AUTO_SYNC:=true}"
  : "${PLUME_PHP_EXTENSIONS_AUTO_SYNC_PROFILE:=matrix}"
  : "${PLUME_PHP_EXT_INSTALL_DRIVER:=}"

  : "${PLUME_NATIVE_HOST_PROVISION:=false}"

  : "${PLUME_SITE_AUTO_PROVISION_WEB:=true}"

  : "${PLUME_SITE_NGINX_STRICT_ON_RELOAD:=true}"

  : "${PLUME_NATIVE_NGINX_MANAGE_MAIN_CONFIG:=false}"
  : "${PLUME_NATIVE_NGINX_HTTP_PORT:=80}"

  # Optional service version defaults for non-core services (default strategy = pinned or latest).
  : "${PLUME_HORIZON_VERSION:=latest}"
  : "${PLUME_SUPERVISOR_VERSION:=latest}"
  : "${PLUME_PHP_WORKER_VERSION:=latest}"
  : "${PLUME_MYSQL_VERSION:=8.0}"
  : "${PLUME_POSTGRES_VERSION:=16}"
  : "${PLUME_REDIS_VERSION:=7}"
  : "${PLUME_MEMCACHED_VERSION:=1.6}"
  : "${PLUME_RABBITMQ_VERSION:=3.13}"
  : "${PLUME_MONGODB_VERSION:=7}"
  : "${PLUME_MONGO_WEBUI_VERSION:=latest}"
  : "${PLUME_MAILPIT_VERSION:=latest}"
  : "${PLUME_MEILISEARCH_VERSION:=1.8}"
  : "${PLUME_MINIO_VERSION:=latest}"
  : "${PLUME_DOCKER_LITE_COMPOSE_REQUIRED:=false}"
  : "${PLUME_LARADOCK_STRICT:=false}"
  : "${PLUME_LARADOCK_COMPOSE_FILE:=}"
}
