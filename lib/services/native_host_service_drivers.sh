#!/usr/bin/env bash
set -euo pipefail

# Phase 17: per-service native host drivers (brew/apt/dnf + npm web UIs).

plume_native_driver_install_driver() {
  printf '%s' "${PLUME_NATIVE_HOST_INSTALL_DRIVER:-$(plume_detect_package_manager)}"
}

plume_native_driver_is_mock() {
  [[ "$(plume_native_driver_install_driver)" == "mock" ]]
}

plume_native_credentials_dir() {
  printf '%s/native-credentials' "$(plume_state_dir)"
}

plume_native_credentials_file() {
  local service="$1"
  mkdir -p "$(plume_native_credentials_dir)"
  printf '%s/%s.env' "$(plume_native_credentials_dir)" "${service}"
}

plume_native_credentials_set() {
  local service="$1" key="$2" val="$3"
  local file
  file="$(plume_native_credentials_file "${service}")"
  touch "${file}"
  if grep -q "^${key}=" "${file}" 2>/dev/null; then
    sed -i.bak "s|^${key}=.*|${key}=${val}|" "${file}" && rm -f "${file}.bak"
  else
    printf '%s=%s\n' "${key}" "${val}" >> "${file}"
  fi
}

plume_native_credentials_get() {
  local service="$1" key="$2"
  local file val=""
  file="$(plume_native_credentials_file "${service}")"
  [[ -f "${file}" ]] || return 1
  val="$(grep -E "^${key}=" "${file}" 2>/dev/null | tail -1 | cut -d= -f2-)"
  [[ -n "${val}" ]] || return 1
  printf '%s' "${val}"
}

plume_native_pid_file() {
  local service="$1"
  mkdir -p "$(plume_state_dir)/native-pids"
  printf '%s/native-pids/%s.pid' "$(plume_state_dir)" "${service}"
}

plume_native_driver_supported_services() {
  cat <<'SVC'
web
nginx
apache2
mariadb
mysql
postgres
redis
mongodb
rabbitmq
mailpit
phpmyadmin
mongo_webui
redis_webui
SVC
}

plume_native_driver_service_supported() {
  local service="$1"
  grep -Fxq "${service}" <<< "$(plume_native_driver_supported_services)"
}

plume_native_driver_brew_formula() {
  local service="$1"
  case "${service}" in
    nginx) echo "nginx" ;;
    apache2) echo "httpd" ;;
    mariadb) echo "mariadb" ;;
    mysql) echo "mysql" ;;
    postgres) echo "postgresql@16" ;;
    redis) echo "redis" ;;
    mongodb) echo "mongodb-community" ;;
    rabbitmq) echo "rabbitmq" ;;
    mailpit) echo "mailpit" ;;
    phpmyadmin) echo "phpmyadmin" ;;
    *) return 1 ;;
  esac
}

plume_native_driver_apt_packages() {
  local service="$1"
  case "${service}" in
    nginx) echo "nginx" ;;
    apache2) echo "apache2" ;;
    mariadb) echo "mariadb-server" ;;
    mysql) echo "mysql-server" ;;
    postgres) echo "postgresql" ;;
    redis) echo "redis-server" ;;
    rabbitmq) echo "rabbitmq-server" ;;
    phpmyadmin) echo "phpmyadmin" ;;
    *) return 1 ;;
  esac
}

plume_native_driver_dnf_packages() {
  local service="$1"
  case "${service}" in
    nginx) echo "nginx" ;;
    apache2) echo "httpd" ;;
    mariadb) echo "mariadb-server" ;;
    mysql) echo "mysql-server" ;;
    postgres) echo "postgresql-server" ;;
    redis) echo "redis" ;;
    rabbitmq) echo "rabbitmq-server" ;;
    phpmyadmin) echo "phpmyadmin" ;;
    *) return 1 ;;
  esac
}

plume_native_driver_brew_service_name() {
  local service="$1"
  case "${service}" in
    nginx) echo "nginx" ;;
    apache2) echo "httpd" ;;
    mariadb) echo "mariadb" ;;
    mysql) echo "mysql" ;;
    postgres) echo "postgresql@16" ;;
    redis) echo "redis" ;;
    mongodb) echo "mongodb-community" ;;
    rabbitmq) echo "rabbitmq" ;;
    mailpit) echo "mailpit" ;;
    *) return 1 ;;
  esac
}

plume_native_driver_systemd_unit() {
  local service="$1"
  case "${service}" in
    nginx) echo "nginx" ;;
    apache2) echo "apache2" ;;
    mariadb) echo "mariadb" ;;
    mysql) echo "mysql" ;;
    postgres) echo "postgresql" ;;
    redis) echo "redis" ;;
    rabbitmq) echo "rabbitmq" ;;
    mongodb) echo "mongod" ;;
    *) return 1 ;;
  esac
}

plume_native_driver_npm_package() {
  local service="$1"
  case "${service}" in
    mongo_webui) echo "mongo-express" ;;
    redis_webui) echo "redis-commander" ;;
    *) return 1 ;;
  esac
}

plume_native_driver_default_port() {
  local service="$1"
  case "${service}" in
    phpmyadmin) echo "${PMA_PORT:-${PLUME_PHPMYADMIN_PORT:-8081}}" ;;
    mongo_webui) echo "${PLUME_MONGO_WEBUI_PORT:-8082}" ;;
    redis_webui) echo "${PLUME_REDIS_WEBUI_PORT:-8083}" ;;
    rabbitmq) echo "${PLUME_RABBITMQ_MANAGEMENT_PORT:-15672}" ;;
    postgres) echo "${PLUME_POSTGRES_PORT:-5432}" ;;
    mariadb|mysql) echo "${PLUME_MARIADB_PORT:-3306}" ;;
    redis) echo "${PLUME_REDIS_PORT:-6379}" ;;
    mongodb) echo "${PLUME_MONGODB_PORT:-27017}" ;;
    mailpit) echo "${PLUME_MAILPIT_PORT:-8025}" ;;
    *) return 1 ;;
  esac
}

plume_native_driver_post_install() {
  local service="$1"
  case "${service}" in
    postgres)
      plume_native_credentials_set postgres host "127.0.0.1"
      plume_native_credentials_set postgres port "$(plume_native_driver_default_port postgres)"
      plume_native_credentials_set postgres user "${PLUME_POSTGRES_USER:-postgres}"
      plume_native_credentials_set postgres database "${PLUME_POSTGRES_DB:-postgres}"
      plume_native_credentials_set postgres password "$(plume_native_postgres_effective_password)"
      ;;
    mariadb)
      plume_native_credentials_set mariadb host "127.0.0.1"
      plume_native_credentials_set mariadb port "$(plume_native_driver_default_port mariadb)"
      plume_native_credentials_set mariadb user "root"
      plume_native_credentials_set mariadb database "mysql"
      plume_native_credentials_set mariadb password "$(plume_native_mariadb_effective_root_password mariadb)"
      ;;
    mysql)
      plume_native_credentials_set mysql host "127.0.0.1"
      plume_native_credentials_set mysql port "$(plume_native_mariadb_effective_port mysql)"
      plume_native_credentials_set mysql user "root"
      plume_native_credentials_set mysql database "mysql"
      plume_native_credentials_set mysql password "$(plume_native_mariadb_effective_root_password mysql)"
      ;;
    mongodb)
      plume_native_credentials_set mongodb host "127.0.0.1"
      plume_native_credentials_set mongodb port "$(plume_native_driver_default_port mongodb)"
      plume_native_credentials_set mongodb user "${PLUME_MONGODB_USERNAME:-root}"
      plume_native_credentials_set mongodb password "${PLUME_MONGODB_PASSWORD:-example}"
      plume_native_credentials_set mongodb database "${PLUME_MONGODB_DATABASE:-admin}"
      ;;
    redis)
      plume_native_credentials_set redis host "127.0.0.1"
      plume_native_credentials_set redis port "$(plume_native_driver_default_port redis)"
      plume_native_credentials_set redis password "$(plume_native_redis_effective_password)"
      ;;
    rabbitmq)
      plume_native_credentials_set rabbitmq host "127.0.0.1"
      plume_native_credentials_set rabbitmq port "${PLUME_RABBITMQ_PORT:-5672}"
      plume_native_credentials_set rabbitmq management_port "${PLUME_RABBITMQ_MANAGEMENT_PORT:-15672}"
      plume_native_credentials_set rabbitmq user "${PLUME_RABBITMQ_USER:-guest}"
      plume_native_credentials_set rabbitmq password "${PLUME_RABBITMQ_PASSWORD:-guest}"
      ;;
    mongo_webui)
      plume_native_credentials_set mongo_webui uri "$(plume_stack_build_mongo_webui_uri)"
      plume_native_credentials_set mongo_webui username "${PLUME_MONGO_WEBUI_USERNAME:-admin}"
      plume_native_credentials_set mongo_webui password "${PLUME_MONGO_WEBUI_PASSWORD:-pass}"
      plume_native_credentials_set mongo_webui port "$(plume_native_driver_default_port mongo_webui)"
      ;;
    phpmyadmin)
      local engine
      plume_native_credentials_set phpmyadmin http_port "$(plume_native_driver_default_port phpmyadmin)"
      while IFS= read -r engine; do
        [[ -n "${engine}" ]] || continue
        plume_native_credentials_set phpmyadmin "${engine}_server" "${engine}"
        plume_native_credentials_set phpmyadmin "${engine}_host" "$(plume_native_phpmyadmin_engine_connect_host "${engine}")"
        plume_native_credentials_set phpmyadmin "${engine}_port" "$(plume_native_phpmyadmin_engine_port "${engine}")"
        plume_native_credentials_set phpmyadmin "${engine}_user" "$(plume_native_phpmyadmin_db_user_for_engine "${engine}")"
        plume_native_credentials_set phpmyadmin "${engine}_password" "$(plume_native_phpmyadmin_db_password_for_engine "${engine}")"
      done < <(plume_native_phpmyadmin_list_operational_db_engines)
      ;;
    redis_webui)
      plume_native_credentials_set redis_webui username "${PLUME_REDIS_WEBUI_USERNAME:-laradock}"
      plume_native_credentials_set redis_webui password "${PLUME_REDIS_WEBUI_PASSWORD:-laradock}"
      plume_native_credentials_set redis_webui host "${PLUME_REDIS_WEBUI_HOST:-127.0.0.1}"
      plume_native_credentials_set redis_webui redis_port "${PLUME_REDIS_WEBUI_REDIS_PORT:-${PLUME_REDIS_PORT:-6379}}"
      plume_native_credentials_set redis_webui port "$(plume_native_driver_default_port redis_webui)"
      ;;
    *) return 0 ;;
  esac
}

plume_native_driver_install_packages() {
  local service="$1"
  local pm formula pkgs npm_pkg

  if plume_native_driver_is_mock; then
    plume_info "native driver mock install: ${service}"
    plume_native_driver_post_install "${service}" || true
    if [[ "${service}" == "phpmyadmin" ]]; then
      plume_native_phpmyadmin_sync_config "false" || true
    else
      plume_native_stack_sync_on_lifecycle "${service}" || true
    fi
    return 0
  fi

  if npm_pkg="$(plume_native_driver_npm_package "${service}" 2>/dev/null)" && [[ -n "${npm_pkg}" ]]; then
    if ! command -v npm >/dev/null 2>&1; then
      plume_err "npm required for native ${service}; install Node.js or use docker-lite"
      return 2
    fi
    plume_info "native driver: npm install -g ${npm_pkg}"
    npm install -g "${npm_pkg}" || return 2
    plume_native_driver_post_install "${service}" || true
    return 0
  fi

  pm="$(plume_detect_package_manager)"
  case "${pm}" in
    brew)
      if [[ "${service}" == "mongodb" ]]; then
        if ! brew tap | grep -q mongodb/brew 2>/dev/null; then
          plume_info "native driver: brew tap mongodb/brew"
          brew tap mongodb/brew || {
            plume_warn "native mongodb: brew tap failed; install manually or use docker-lite"
            return 2
          }
        fi
      fi
      formula="$(plume_native_driver_brew_formula "${service}")" || return 2
      if brew list "${formula}" >/dev/null 2>&1; then
        plume_info "native driver: ${formula} already installed"
      else
        if declare -F plume_macos_permissions_confirm_host_install >/dev/null 2>&1; then
          plume_macos_permissions_confirm_host_install \
            "brew install ${formula}" \
            "Plume will install ${formula} for native ${service}." || return 2
        fi
        brew install "${formula}" || return 2
      fi
      ;;
    apt)
      pkgs="$(plume_native_driver_apt_packages "${service}")" || {
        plume_warn "native ${service}: no apt packages; use docker-lite or manual install"
        return 2
      }
      apt-get update -qq
      DEBIAN_FRONTEND=noninteractive apt-get install -y ${pkgs}
      ;;
    dnf)
      pkgs="$(plume_native_driver_dnf_packages "${service}")" || {
        plume_warn "native ${service}: no dnf packages; use docker-lite or manual install"
        return 2
      }
      dnf install -y ${pkgs}
      ;;
    *)
      plume_err "unsupported package manager for ${service}: ${pm}"
      return 2
      ;;
  esac
  plume_native_driver_post_install "${service}" || true
  if [[ "${service}" == "phpmyadmin" ]]; then
    plume_native_phpmyadmin_sync_config "false" || true
  else
    plume_native_stack_sync_on_lifecycle "${service}" || true
    case "${service}" in
      mariadb|mysql) plume_native_db_hosts_sync || true ;;
    esac
  fi
}

plume_native_driver_start_npm_service() {
  local service="$1"
  local npm_pkg port pid_file log_file
  npm_pkg="$(plume_native_driver_npm_package "${service}")" || return 2
  port="$(plume_native_driver_default_port "${service}")"
  pid_file="$(plume_native_pid_file "${service}")"
  log_file="$(plume_service_log_file "${service}" native)"

  if [[ -f "${pid_file}" ]]; then
    local old_pid
    old_pid="$(cat "${pid_file}" 2>/dev/null || true)"
    if [[ -n "${old_pid}" ]] && kill -0 "${old_pid}" 2>/dev/null; then
      plume_info "native driver: ${service} already running pid=${old_pid}"
      return 0
    fi
  fi

  mkdir -p "$(dirname "${log_file}")"
  case "${service}" in
    mongo_webui)
      local mongo_uri basic_user basic_pass
      mongo_uri="$(plume_stack_build_mongo_webui_uri)"
      basic_user="${PLUME_MONGO_WEBUI_USERNAME:-}"
      basic_pass="${PLUME_MONGO_WEBUI_PASSWORD:-}"
      if [[ -n "${basic_user}" && -n "${basic_pass}" ]]; then
        ME_CONFIG_MONGODB_URL="${mongo_uri}" \
          ME_CONFIG_BASICAUTH_USERNAME="${basic_user}" \
          ME_CONFIG_BASICAUTH_PASSWORD="${basic_pass}" \
          nohup "$(command -v mongo-express || echo mongo-express)" -p "${port}" >>"${log_file}" 2>&1 &
      else
        ME_CONFIG_MONGODB_URL="${mongo_uri}" \
          nohup "$(command -v mongo-express || echo mongo-express)" -p "${port}" >>"${log_file}" 2>&1 &
      fi
      ;;
    redis_webui)
      local redis_hosts http_user http_pass
      redis_hosts="$(plume_stack_build_redis_commander_hosts)"
      http_user="${PLUME_REDIS_WEBUI_USERNAME:-}"
      http_pass="${PLUME_REDIS_WEBUI_PASSWORD:-}"
      if [[ -n "${http_user}" && -n "${http_pass}" ]]; then
        HTTP_USER="${http_user}" HTTP_PASSWORD="${http_pass}" REDIS_HOSTS="${redis_hosts}" \
          nohup "$(command -v redis-commander || echo redis-commander)" --port "${port}" >>"${log_file}" 2>&1 &
      else
        REDIS_HOSTS="${redis_hosts}" \
          nohup "$(command -v redis-commander || echo redis-commander)" --port "${port}" >>"${log_file}" 2>&1 &
      fi
      ;;
    *) return 2 ;;
  esac
  echo $! > "${pid_file}"
  plume_info "native driver: started ${service} on port ${port} pid=$(cat "${pid_file}")"
}

plume_native_driver_stop_npm_service() {
  local service="$1"
  local pid_file pid
  pid_file="$(plume_native_pid_file "${service}")"
  [[ -f "${pid_file}" ]] || return 0
  pid="$(cat "${pid_file}" 2>/dev/null || true)"
  [[ -n "${pid}" ]] && kill "${pid}" 2>/dev/null || true
  rm -f "${pid_file}"
}

plume_native_driver_start_service() {
  local service="$1"
  local pm os

  plume_native_driver_post_install "${service}" || true
  if [[ "${service}" == "phpmyadmin" ]]; then
    plume_native_phpmyadmin_sync_config "false" || true
  else
    plume_native_stack_sync_on_lifecycle "${service}" || true
    case "${service}" in
      mariadb|mysql) plume_native_db_hosts_sync || true ;;
    esac
  fi

  if [[ "${service}" == "phpmyadmin" ]]; then
    plume_native_phpmyadmin_start_server
    return $?
  fi

  if plume_native_driver_npm_package "${service}" >/dev/null 2>&1; then
    plume_native_driver_start_npm_service "${service}"
    return $?
  fi

  if plume_native_driver_is_mock; then
    plume_info "native driver mock start: ${service}"
    return 0
  fi

  pm="$(plume_detect_package_manager)"
  os="$(plume_detect_os)"
  case "${pm}" in
    brew)
      local svc
      svc="$(plume_native_driver_brew_service_name "${service}")" || return 2
      brew services start "${svc}" 2>/dev/null || brew services restart "${svc}"
      ;;
    apt|dnf)
      local unit
      unit="$(plume_native_driver_systemd_unit "${service}")" || return 2
      if [[ "${os}" == "linux" ]] && command -v systemctl >/dev/null 2>&1; then
        systemctl enable "${unit}" 2>/dev/null || true
        systemctl start "${unit}"
      else
        plume_err "systemd required for native start: ${service}"
        return 2
      fi
      ;;
    *)
      return 2
      ;;
  esac
  plume_native_stack_apply_runtime_credentials "${service}" || true
}

plume_native_driver_stop_service() {
  local service="$1"
  if [[ "${service}" == "phpmyadmin" ]]; then
    plume_native_phpmyadmin_stop_server
    return 0
  fi
  if plume_native_driver_npm_package "${service}" >/dev/null 2>&1; then
    plume_native_driver_stop_npm_service "${service}"
    return 0
  fi
  if plume_native_driver_is_mock; then
    plume_info "native driver mock stop: ${service}"
    return 0
  fi
  local pm os
  pm="$(plume_detect_package_manager)"
  os="$(plume_detect_os)"
  case "${pm}" in
    brew)
      local svc
      svc="$(plume_native_driver_brew_service_name "${service}")" || return 0
      brew services stop "${svc}" 2>/dev/null || true
      ;;
    apt|dnf)
      local unit
      unit="$(plume_native_driver_systemd_unit "${service}")" || return 0
      if [[ "${os}" == "linux" ]] && command -v systemctl >/dev/null 2>&1; then
        systemctl stop "${unit}" 2>/dev/null || true
      fi
      ;;
  esac
}

plume_native_driver_health_probe() {
  local service="$1"
  local port host

  if plume_native_driver_npm_package "${service}" >/dev/null 2>&1 \
    || [[ "${service}" == "phpmyadmin" ]]; then
    port="$(plume_native_driver_default_port "${service}")"
    if command -v curl >/dev/null 2>&1 && curl -sf "http://127.0.0.1:${port}/" >/dev/null 2>&1; then
      return 0
    fi
    local pid_file pid
    pid_file="$(plume_native_pid_file "${service}")"
    pid="$(cat "${pid_file}" 2>/dev/null || true)"
    [[ -n "${pid}" ]] && kill -0 "${pid}" 2>/dev/null
    return $?
  fi

  case "${service}" in
    redis)
      plume_native_redis_cli_ping
      ;;
    postgres)
      local ppass pport puser
      pport="$(plume_native_driver_default_port postgres)"
      puser="${PLUME_POSTGRES_USER:-postgres}"
      ppass="$(plume_native_postgres_effective_password)"
      if command -v pg_isready >/dev/null 2>&1; then
        pg_isready -h127.0.0.1 -p"${pport}" -q 2>/dev/null
      elif command -v psql >/dev/null 2>&1; then
        if [[ -n "${ppass}" ]]; then
          PGPASSWORD="${ppass}" psql -h127.0.0.1 -p"${pport}" -U"${puser}" -d postgres -c "SELECT 1" >/dev/null 2>&1
        else
          psql -h127.0.0.1 -p"${pport}" -U"${puser}" -d postgres -c "SELECT 1" >/dev/null 2>&1
        fi
      else
        return 1
      fi
      ;;
    mariadb|mysql)
      plume_native_driver_is_mock && return 0
      local mpass mport sock
      mport="$(plume_native_mariadb_effective_port "${service}")"
      mpass="$(plume_native_mariadb_effective_root_password "${service}")"
      command -v mysqladmin >/dev/null 2>&1 || return 1
      if [[ -n "${mpass}" ]]; then
        mysqladmin ping -h127.0.0.1 -P"${mport}" -uroot -p"${mpass}" --silent --batch </dev/null 2>/dev/null
      else
        sock="$(plume_native_mariadb_socket_path 2>/dev/null || true)"
        [[ -n "${sock}" ]] || return 1
        mysqladmin ping --socket="${sock}" -uroot --silent --batch </dev/null 2>/dev/null
      fi
      ;;
    rabbitmq)
      command -v rabbitmq-diagnostics >/dev/null 2>&1 && rabbitmq-diagnostics -q ping 2>/dev/null
      ;;
    mongodb)
      if command -v mongosh >/dev/null 2>&1; then
        mongosh --quiet --eval "db.runCommand({ ping: 1 })" >/dev/null 2>&1
      elif command -v mongo >/dev/null 2>&1; then
        mongo --quiet --eval "db.runCommand({ ping: 1 })" >/dev/null 2>&1
      else
        return 1
      fi
      ;;
    mailpit)
      plume_native_driver_is_mock && return 0
      if declare -F plume_service_effective_port >/dev/null 2>&1; then
        port="$(plume_service_effective_port mailpit native 2>/dev/null || true)"
      fi
      [[ -n "${port}" ]] || port="$(plume_native_driver_default_port mailpit 2>/dev/null || true)"
      [[ -n "${port}" ]] || port="${PLUME_MAILPIT_PORT:-8025}"
      if command -v curl >/dev/null 2>&1 && curl -sf "http://127.0.0.1:${port}/" >/dev/null 2>&1; then
        return 0
      fi
      return 1
      ;;
    nginx|apache2)
      plume_native_driver_is_mock && return 0
      return 1
      ;;
    *)
      return 1
      ;;
  esac
}

plume_native_driver_service_url() {
  local service="$1"
  local port scheme="http"
  case "${service}" in
    phpmyadmin|mongo_webui|redis_webui|mailpit)
      port="$(plume_native_driver_default_port "${service}" 2>/dev/null || plume_service_default_port "${service}")"
      printf '%s://127.0.0.1:%s' "${scheme}" "${port}"
      ;;
    rabbitmq)
      port="${PLUME_RABBITMQ_MANAGEMENT_PORT:-15672}"
      printf '%s://127.0.0.1:%s' "${scheme}" "${port}"
      ;;
    *)
      return 1
      ;;
  esac
}

plume_native_driver_print_credentials() {
  local service="$1"
  local key val
  local file
  plume_native_driver_post_install "${service}" || true
  file="$(plume_native_credentials_file "${service}")"
  [[ -f "${file}" ]] || return 1
  while IFS= read -r line; do
    [[ "${line}" == *=* ]] || continue
    key="${line%%=*}"
    val="${line#*=}"
    printf '%s=%s\n' "${key}" "${val}"
  done < "${file}"
}
