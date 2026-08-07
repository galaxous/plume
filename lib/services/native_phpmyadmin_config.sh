#!/usr/bin/env bash
set -euo pipefail

# Native phpMyAdmin: brew/apt files + PLUME/PMA env → config.inc.php + php built-in server.

plume_native_phpmyadmin_state_dir() {
  printf '%s/native/phpmyadmin' "$(plume_state_dir)"
}

plume_native_phpmyadmin_docroot() {
  printf '%s/htdocs' "$(plume_native_phpmyadmin_state_dir)"
}

plume_native_phpmyadmin_config_inc_path() {
  printf '%s/config.inc.php' "$(plume_native_phpmyadmin_docroot)"
}

plume_native_phpmyadmin_blowfish_secret_path() {
  printf '%s/blowfish_secret' "$(plume_native_phpmyadmin_state_dir)"
}

plume_native_phpmyadmin_brew_share_path() {
  local prefix=""
  if ! command -v brew >/dev/null 2>&1; then
    return 1
  fi
  prefix="$(HOMEBREW_NO_AUTO_UPDATE=1 brew --prefix phpmyadmin 2>/dev/null || true)"
  [[ -n "${prefix}" && -d "${prefix}/share/phpmyadmin" ]] || return 1
  printf '%s/share/phpmyadmin' "${prefix}"
}

plume_native_phpmyadmin_apt_share_path() {
  local candidate
  for candidate in /usr/share/phpmyadmin /usr/share/php/phpmyadmin; do
    if [[ -d "${candidate}" && -f "${candidate}/index.php" ]]; then
      printf '%s' "${candidate}"
      return 0
    fi
  done
  return 1
}

plume_native_phpmyadmin_upstream_share_path() {
  plume_native_phpmyadmin_brew_share_path 2>/dev/null \
    || plume_native_phpmyadmin_apt_share_path 2>/dev/null \
    || return 1
}

plume_native_phpmyadmin_engine() {
  printf '%s' "${PMA_DB_ENGINE:-${PMA_ENGINE:-mariadb}}"
}

plume_native_phpmyadmin_list_enabled_db_engines() {
  local engine
  for engine in mariadb mysql; do
    if [[ "$(plume_service_enabled_for_mode "${engine}" native)" == "true" ]]; then
      printf '%s\n' "${engine}"
    fi
  done
}

plume_native_phpmyadmin_list_operational_db_engines() {
  local engine
  for engine in mariadb mysql; do
    [[ "$(plume_service_enabled_for_mode "${engine}" native)" == "true" ]] || continue
    if plume_native_host_health_probe "${engine}" >/dev/null 2>&1; then
      printf '%s\n' "${engine}"
    fi
  done
}

plume_native_phpmyadmin_engine_port() {
  local engine="$1"
  case "${engine}" in
    mysql) printf '%s' "${PLUME_MYSQL_PORT:-3307}" ;;
    mariadb) printf '%s' "${PLUME_MARIADB_PORT:-3306}" ;;
    *) return 1 ;;
  esac
}

plume_native_phpmyadmin_engine_connect_host() {
  local engine="$1"
  if [[ -n "${PMA_HOST:-}" ]]; then
    printf '%s' "${PMA_HOST}"
    return 0
  fi
  printf '%s' "${engine}"
}

plume_native_phpmyadmin_warn_port_conflict() {
  local mariadb_port mysql_port
  if [[ "$(plume_service_enabled_for_mode mariadb native)" != "true" ]] \
    || [[ "$(plume_service_enabled_for_mode mysql native)" != "true" ]]; then
    return 0
  fi
  mariadb_port="$(plume_native_phpmyadmin_engine_port mariadb)"
  mysql_port="$(plume_native_phpmyadmin_engine_port mysql)"
  if [[ "${mariadb_port}" == "${mysql_port}" ]]; then
    plume_warn "mariadb and mysql both enabled on port ${mariadb_port}; set PLUME_MYSQL_PORT=3307 (or change PLUME_MARIADB_PORT)"
  fi
}

plume_native_phpmyadmin_db_host() {
  if [[ -n "${PMA_HOST:-}" ]]; then
    printf '%s' "${PMA_HOST}"
    return 0
  fi
  printf '%s' "127.0.0.1"
}

plume_native_phpmyadmin_db_port() {
  local engine
  engine="$(plume_native_phpmyadmin_engine)"
  if [[ -n "${PMA_DB_PORT:-}" ]]; then
    printf '%s' "${PMA_DB_PORT}"
    return 0
  fi
  plume_native_phpmyadmin_engine_port "${engine}"
}

plume_native_phpmyadmin_db_user() {
  plume_native_phpmyadmin_db_user_for_engine "$(plume_native_phpmyadmin_engine)"
}

plume_native_phpmyadmin_db_user_for_engine() {
  local engine="$1"
  if [[ -n "${PMA_USER:-}" ]]; then
    printf '%s' "${PMA_USER}"
    return 0
  fi
  printf '%s' "root"
}

plume_native_phpmyadmin_db_password() {
  plume_native_phpmyadmin_db_password_for_engine "$(plume_native_phpmyadmin_engine)"
}

plume_native_phpmyadmin_db_password_for_engine() {
  local engine="$1"
  if [[ -n "${PMA_PASSWORD:-}" ]]; then
    printf '%s' "${PMA_PASSWORD}"
    return 0
  fi
  case "${engine}" in
    mysql) plume_native_mariadb_effective_root_password mysql ;;
    *) plume_native_mariadb_effective_root_password mariadb ;;
  esac
}

plume_native_phpmyadmin_auth_type() {
  local auth="${PMA_AUTH_TYPE:-cookie}"
  case "${auth}" in
    cookie|config) printf '%s' "${auth}" ;;
    *)
      plume_err "PMA_AUTH_TYPE must be cookie or config (got: ${auth})"
      return 2
      ;;
  esac
}

plume_native_phpmyadmin_blowfish_secret() {
  local secret_file
  secret_file="$(plume_native_phpmyadmin_blowfish_secret_path)"
  mkdir -p "$(dirname "${secret_file}")"
  if [[ -f "${secret_file}" ]]; then
    cat "${secret_file}"
    return 0
  fi
  if command -v openssl >/dev/null 2>&1; then
    openssl rand -base64 32 | tr -d '\n' > "${secret_file}"
  else
    date +%s | shasum | awk '{print $1}' > "${secret_file}"
  fi
  cat "${secret_file}"
}

plume_native_phpmyadmin_ensure_docroot() {
  local docroot upstream
  docroot="$(plume_native_phpmyadmin_docroot)"
  mkdir -p "$(dirname "${docroot}")"

  if plume_native_driver_is_mock; then
    mkdir -p "${docroot}"
    if [[ ! -f "${docroot}/index.php" ]]; then
      printf '%s\n' '<?php echo "mock phpmyadmin";' > "${docroot}/index.php"
    fi
    return 0
  fi

  upstream="$(plume_native_phpmyadmin_upstream_share_path || true)"
  if [[ -z "${upstream}" ]]; then
    plume_err "phpmyadmin files not found; install with: brew install phpmyadmin (macOS) or apt install phpmyadmin (Linux)"
    return 2
  fi

  if [[ ! -f "${docroot}/index.php" ]]; then
    mkdir -p "${docroot}"
    plume_info "native phpmyadmin: seeding docroot from ${upstream}"
    cp -R "${upstream}/." "${docroot}/"
  fi
  rm -f "${docroot}/config.inc.php" "${docroot}/config.sample.inc.php" 2>/dev/null || true
}

plume_native_phpmyadmin_write_config_inc() {
  local docroot cfg host port user pass secret arbitrary absolute_uri auth_type engine engines
  docroot="$(plume_native_phpmyadmin_docroot)"
  cfg="$(plume_native_phpmyadmin_config_inc_path)"
  auth_type="$(plume_native_phpmyadmin_auth_type)" || return 2
  secret="$(plume_native_phpmyadmin_blowfish_secret)"
  arbitrary="${PMA_ARBITRARY:-1}"
  absolute_uri="${PMA_ABSOLUTE_URI:-}"
  engines=()
  while IFS= read -r engine; do
    [[ -n "${engine}" ]] || continue
    engines+=("${engine}")
  done < <(plume_native_phpmyadmin_list_operational_db_engines)

  if [[ ${#engines[@]} -eq 0 ]]; then
    while IFS= read -r engine; do
      [[ -n "${engine}" ]] || continue
      engines+=("${engine}")
    done < <(plume_native_phpmyadmin_list_enabled_db_engines)
  fi

  plume_native_db_brew_dual_engine_warn
  plume_native_phpmyadmin_warn_port_conflict

  mkdir -p "${docroot}"
  rm -f "${cfg}" 2>/dev/null || true
  {
    printf '%s\n' '<?php'
    printf '%s\n' 'declare(strict_types=1);'
    printf '%s\n' '# Generated by Plume — edit PMA_* / PLUME_* in ~/.config/plume/.env then: services restart phpmyadmin'
    printf '\n'
    printf '%s\n' "\$cfg['blowfish_secret'] = '${secret}';"
    if [[ -n "${absolute_uri}" ]]; then
      printf '%s\n' "\$cfg['PmaAbsoluteUri'] = '${absolute_uri}';"
    fi
    printf '%s\n' '$i = 0;'

    if [[ "$(plume_bool "${arbitrary}")" == "true" && ${#engines[@]} -gt 0 ]]; then
      local first=true
      for engine in "${engines[@]}"; do
        host="$(plume_native_phpmyadmin_engine_connect_host "${engine}")"
        port="$(plume_native_phpmyadmin_engine_port "${engine}")"
        printf '%s\n' '++$i;'
        printf '%s\n' "\$cfg['Servers'][\$i]['host'] = '${host}';"
        printf '%s\n' "\$cfg['Servers'][\$i]['port'] = '${port}';"
        printf '%s\n' "\$cfg['Servers'][\$i]['verbose'] = '${engine}';"
        printf '%s\n' "\$cfg['Servers'][\$i]['auth_type'] = '${auth_type}';"
        printf '%s\n' "\$cfg['Servers'][\$i]['AllowNoPassword'] = false;"
        if [[ "${first}" == "true" ]]; then
          printf '%s\n' "\$cfg['Servers'][\$i]['AllowArbitraryServer'] = true;"
          first=false
        fi
        if [[ "${auth_type}" == "config" ]]; then
          user="$(plume_native_phpmyadmin_db_user_for_engine "${engine}")"
          pass="$(plume_native_phpmyadmin_db_password_for_engine "${engine}")"
          printf '%s\n' "\$cfg['Servers'][\$i]['user'] = '${user}';"
          printf '%s\n' "\$cfg['Servers'][\$i]['password'] = '${pass}';"
        fi
      done
    elif [[ "$(plume_bool "${arbitrary}")" == "true" ]]; then
      printf '%s\n' '++$i;'
      printf '%s\n' "\$cfg['Servers'][\$i]['AllowArbitraryServer'] = true;"
      printf '%s\n' "\$cfg['Servers'][\$i]['auth_type'] = '${auth_type}';"
      printf '%s\n' "\$cfg['Servers'][\$i]['AllowNoPassword'] = false;"
    else
      host="$(plume_native_phpmyadmin_db_host)"
      port="$(plume_native_phpmyadmin_db_port)"
      user="$(plume_native_phpmyadmin_db_user)"
      pass="$(plume_native_phpmyadmin_db_password)"
      printf '%s\n' '++$i;'
      printf '%s\n' "\$cfg['Servers'][\$i]['host'] = '${host}';"
      printf '%s\n' "\$cfg['Servers'][\$i]['port'] = '${port}';"
      printf '%s\n' "\$cfg['Servers'][\$i]['auth_type'] = '${auth_type}';"
      if [[ "${auth_type}" == "config" ]]; then
        printf '%s\n' "\$cfg['Servers'][\$i]['user'] = '${user}';"
        printf '%s\n' "\$cfg['Servers'][\$i]['password'] = '${pass}';"
      fi
      printf '%s\n' "\$cfg['Servers'][\$i]['AllowNoPassword'] = false;"
    fi

    if [[ -n "${PMA_MAX_EXECUTION_TIME:-}" ]]; then
      printf '%s\n' "\$cfg['ExecTimeLimit'] = ${PMA_MAX_EXECUTION_TIME};"
    fi
    if [[ -n "${PMA_MEMORY_LIMIT:-}" ]]; then
      printf '%s\n' "\$cfg['MemoryLimit'] = '${PMA_MEMORY_LIMIT}';"
    fi
    if [[ -n "${PMA_UPLOAD_LIMIT:-}" ]]; then
      printf '%s\n' "\$cfg['UploadDir'] = '';"
      printf '%s\n' "\$cfg['SaveDir'] = '';"
    fi
  } > "${cfg}"
  plume_info "native phpmyadmin: wrote ${cfg}"
}

plume_native_phpmyadmin_sync_config() {
  local dry_run="${1:-false}"
  local port
  port="$(plume_native_driver_default_port phpmyadmin)"

  if [[ "${dry_run}" == "true" ]]; then
    printf 'action: phpmyadmin-sync-config\n'
    printf 'docroot: %s\n' "$(plume_native_phpmyadmin_docroot)"
    printf 'port: %s\n' "${port}"
    printf 'host: %s\n' "$(plume_native_phpmyadmin_db_host)"
    return 0
  fi

  plume_native_phpmyadmin_ensure_docroot || return 2
  plume_native_phpmyadmin_write_config_inc
  plume_native_db_hosts_sync || true
}

plume_native_phpmyadmin_start_server() {
  local port pid_file log_file docroot php_bin
  port="$(plume_native_driver_default_port phpmyadmin)"
  pid_file="$(plume_native_pid_file phpmyadmin)"
  log_file="$(plume_service_log_file phpmyadmin native)"
  docroot="$(plume_native_phpmyadmin_docroot)"

  plume_native_phpmyadmin_sync_config "false" || return 2

  if [[ -f "${pid_file}" ]]; then
    local old_pid
    old_pid="$(cat "${pid_file}" 2>/dev/null || true)"
    if [[ -n "${old_pid}" ]] && kill -0 "${old_pid}" 2>/dev/null; then
      plume_info "native phpmyadmin: already running pid=${old_pid}"
      return 0
    fi
  fi

  php_bin="$(command -v php || true)"
  [[ -n "${php_bin}" ]] || {
    plume_err "php binary required for native phpmyadmin"
    return 2
  }

  mkdir -p "$(dirname "${log_file}")"
  nohup "${php_bin}" -S "127.0.0.1:${port}" -t "${docroot}" >>"${log_file}" 2>&1 &
  echo $! > "${pid_file}"
  plume_info "native phpmyadmin: started on http://127.0.0.1:${port} pid=$(cat "${pid_file}")"
}

plume_native_phpmyadmin_stop_server() {
  local pid_file pid
  pid_file="$(plume_native_pid_file phpmyadmin)"
  [[ -f "${pid_file}" ]] || return 0
  pid="$(cat "${pid_file}" 2>/dev/null || true)"
  [[ -n "${pid}" ]] && kill "${pid}" 2>/dev/null || true
  rm -f "${pid_file}"
}

plume_native_driver_is_managed_http_service() {
  case "${1}" in
    phpmyadmin|mongo_webui|redis_webui) return 0 ;;
    *) return 1 ;;
  esac
}
