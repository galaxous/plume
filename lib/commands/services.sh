#!/usr/bin/env bash
set -euo pipefail

plume_services_state_file() {
  printf '%s' "$(plume_state_dir)/services_enabled.env"
}

plume_services_write_state() {
  : > "$(plume_services_state_file)"
  local mode="${1:-$(plume_mode_current)}"
  while IFS= read -r service; do
    [[ -z "${service}" ]] && continue
    local current
    local version
    current="$(plume_service_enabled "${service}")"
    version="$(plume_service_version "${service}" "")"
    printf '%s.enabled=%s\n' "${service}" "${current}" >> "$(plume_services_state_file)"
    printf '%s.version=%s\n' "${service}" "${version}" >> "$(plume_services_state_file)"
  done < <(plume_service_names_for_mode "${mode}")
}

plume_services_prev_enabled() {
  local service="$1"
  if [[ ! -f "$(plume_services_state_file)" ]]; then
    echo "false"
    return 0
  fi
  local line
  line="$(grep -E "^${service}\\.enabled=" "$(plume_services_state_file)" || true)"
  if [[ -z "${line}" ]]; then
    line="$(grep -E "^${service}=" "$(plume_services_state_file)" || true)"
  fi
  if [[ -z "${line}" ]]; then
    echo "false"
  else
    echo "${line#*=}"
  fi
}

plume_services_parse_version() {
  local version=""
  local expect_next="false"
  local arg
  for arg in "$@"; do
    if [[ "${expect_next}" == "true" ]]; then
      version="${arg}"
      expect_next="false"
      continue
    fi
    case "${arg}" in
      --version=*) version="${arg#*=}" ;;
      --version) expect_next="true" ;;
    esac
  done

  if [[ "${expect_next}" == "true" ]]; then
    plume_err "missing value for --version"
    return 2
  fi

  PLUME_SERVICE_VERSION="${version}"
}

plume_services_parse_mode() {
  local mode
  mode="$(plume_mode_current)"
  local arg
  PLUME_SERVICES_NO_PROVISION="false"
  for arg in "$@"; do
    case "${arg}" in
      --mode=*) mode="${arg#*=}" ;;
      --no-provision) PLUME_SERVICES_NO_PROVISION="true" ;;
    esac
  done

  case "${mode}" in
    ""|native|docker-lite|laradock-bridge) ;;
    *)
      plume_err "invalid mode for services: ${mode}"
      return 2
      ;;
  esac

  printf '%s' "${mode}"
}

plume_services_first_positional() {
  local arg
  for arg in "$@"; do
    if [[ "${arg}" == --* ]]; then
      continue
    fi
    printf '%s' "${arg}"
    return 0
  done
}

plume_services_second_positional() {
  local found="false"
  local arg
  for arg in "$@"; do
    if [[ "${arg}" == --* ]]; then
      continue
    fi
    if [[ "${found}" == "false" ]]; then
      found="true"
      continue
    fi
    printf '%s' "${arg}"
    return 0
  done
}

plume_services_status_running_only() {
  local arg
  for arg in "$@"; do
    case "${arg}" in
      --running|--running-only|--active)
        printf '%s' "true"
        return 0
        ;;
    esac
  done
  printf '%s' "false"
}

plume_services_status_wide() {
  local arg
  for arg in "$@"; do
    case "${arg}" in
      --wide)
        printf '%s' "true"
        return 0
        ;;
    esac
  done
  printf '%s' "false"
}

plume_services_status_port_text() {
  local port_value="${1:-}"
  local max_items="${2:-3}"
  [[ -n "${port_value}" ]] || {
    printf '%s' "-"
    return 0
  }
  [[ "${port_value}" != "-" ]] || {
    printf '%s' "-"
    return 0
  }
  local IFS=','
  local -a parts=()
  read -r -a parts <<< "${port_value}"
  local count="${#parts[@]}"
  if (( count <= max_items )); then
    printf '%s' "${port_value}"
    return 0
  fi
  local shown
  shown="$(printf '%s,%s,%s' "${parts[0]}" "${parts[1]}" "${parts[2]}")"
  printf '%s,+%s' "${shown}" "$((count - max_items))"
}

plume_services_target_running() {
  local service="$1"
  local mode="${2:-$(plume_mode_current)}"
  local version_override="${3:-}"
  local status_line _svc _enabled _running _health _port _version
  if [[ -n "${version_override}" ]]; then
    status_line="$(PLUME_SERVICE_VERSION="${version_override}" plume_services_display_status_line "${service}" "${mode}")"
  else
    status_line="$(plume_services_display_status_line "${service}" "${mode}")"
  fi
  IFS=$'\t' read -r _svc _enabled _running _health _port _version <<< "${status_line}"
  if [[ "${mode}" == "docker-lite" ]]; then
    case "${_health}" in
      healthy) _running="true" ;;
      stopped|disabled) _running="false" ;;
    esac
  fi
  [[ "${_running}" == "true" ]]
}

plume_services_target_normalized() {
  local target="${1:-}"
  local mode="${2:-$(plume_mode_current)}"
  if [[ -z "${target}" || "${target}" == "all" || "${target}" == @* ]]; then
    printf '%s' "${target}"
    return 0
  fi
  plume_service_contract_normalize "${target}" "${mode}"
}

plume_services_target_version_override() {
  local target="${1:-}"
  local mode="${2:-$(plume_mode_current)}"
  local normalized version=""
  normalized="$(plume_service_contract_normalize "${target}" "${mode}")"
  version="$(plume_service_contract_target_version "${target}" "${mode}" 2>/dev/null || true)"
  if [[ -z "${version}" && "${normalized}" == "php" ]]; then
    version="${PLUME_SERVICE_VERSION:-}"
  fi
  printf '%s' "${version}"
}

plume_services_logs_follow() {
  local arg
  for arg in "$@"; do
    case "${arg}" in
      --follow|-f|--watch)
        printf '%s' "true"
        return 0
        ;;
    esac
  done
  printf '%s' "false"
}

plume_services_watch_interval() {
  local arg
  for arg in "$@"; do
    case "${arg}" in
      --watch)
        printf '%s' "2"
        return 0
        ;;
      --watch=*)
        printf '%s' "${arg#*=}"
        return 0
        ;;
    esac
  done
  printf '%s' ""
}

plume_services_watch_header() {
  local command_name="${1:-services}"
  local interval="${2:-2}"
  local now
  now="$(date '+%Y-%m-%d %H:%M:%S %Z')"
  printf 'WATCH             %s\n' "${command_name}"
  printf 'REFRESH           %ss\n' "${interval}"
  printf 'UPDATED_AT        %s\n' "${now}"
  printf '\n'
}

plume_php_versions_with_default() {
  local default_v="${1:-${PLUME_PHP_DEFAULT_VERSION:-${PLUME_PHP_VERSION:-8.3}}}"
  local installed_csv="${2:-${PLUME_PHP_INSTALLED_VERSIONS:-8.1,8.2,8.3}}"

  default_v="$(printf '%s' "${default_v}" | tr -d ' ')"
  installed_csv="$(printf '%s' "${installed_csv}" | tr -d ' ')"

  local merged="${installed_csv}"
  if [[ ",${merged}," != *",${default_v},"* ]]; then
    if [[ -n "${merged}" ]]; then
      merged="${merged},${default_v}"
    else
      merged="${default_v}"
    fi
  fi

  local out=""
  local item
  IFS=',' read -r -a _php_versions_tmp <<< "${merged}"
  for item in "${_php_versions_tmp[@]}"; do
    [[ -z "${item}" ]] && continue
    if [[ ",${out}," == *",${item},"* ]]; then
      continue
    fi
    if [[ -n "${out}" ]]; then
      out="${out},${item}"
    else
      out="${item}"
    fi
  done
  printf '%s' "${out}"
}

plume_services_web_driver() {
  case "${PLUME_WEB_SERVER_DRIVER:-nginx}" in
    nginx|apache2|caddy) printf '%s' "${PLUME_WEB_SERVER_DRIVER:-nginx}" ;;
    *) printf '%s' "nginx" ;;
  esac
}

plume_services_is_web_variant() {
  local service="${1:-}"
  case "${service}" in
    nginx|apache2|caddy) return 0 ;;
    *) return 1 ;;
  esac
}

plume_services_display_names_for_mode() {
  local mode="${1:-$(plume_mode_current)}"
  if [[ "${mode}" == "laradock-bridge" ]]; then
    plume_service_names_for_mode "${mode}"
    return 0
  fi
  local service
  local emitted_web="false"
  while IFS= read -r service; do
    [[ -z "${service}" ]] && continue
    if [[ "${service}" == "web" ]]; then
      if [[ "${emitted_web}" == "false" ]]; then
        printf 'nginx\napache2\ncaddy\n'
        emitted_web="true"
      fi
      continue
    fi
    printf '%s\n' "${service}"
  done < <(plume_service_names_for_mode "${mode}")
}

plume_services_display_enabled() {
  local display_service="$1"
  local mode="${2:-$(plume_mode_current)}"
  if [[ "${mode}" != "laradock-bridge" ]] && plume_services_is_web_variant "${display_service}"; then
    if [[ "${mode}" == "laradock-bridge" ]]; then
      plume_service_enabled_for_mode "${display_service}" "${mode}"
      return 0
    fi
    if [[ "$(plume_service_enabled_for_mode web "${mode}")" == "true" && "$(plume_services_web_driver)" == "${display_service}" ]]; then
      printf '%s' "true"
    else
      printf '%s' "false"
    fi
    return 0
  fi
  plume_service_enabled_for_mode "${display_service}" "${mode}"
}

plume_services_display_status_line() {
  local display_service="$1"
  local mode="${2:-$(plume_mode_current)}"

  if [[ "${mode}" != "laradock-bridge" ]] && plume_services_is_web_variant "${display_service}"; then
    local web_version
    web_version="$(plume_service_version web)"
    if [[ "${mode}" == "laradock-bridge" ]]; then
      local variant_status
      variant_status="$(plume_service_status "${display_service}" "${mode}")"
      local _svc _enabled _running _health _port _version
      IFS=$'\t' read -r _svc _enabled _running _health _port _version <<< "${variant_status}"
      printf '%s\t%s\t%s\t%s\t%s\t%s\n' "${display_service}" "${_enabled}" "${_running}" "${_health}" "${_port}" "${web_version}"
      return 0
    fi
    if [[ "$(plume_services_display_enabled "${display_service}" "${mode}")" == "true" ]]; then
      local web_status
      web_status="$(plume_service_status web "${mode}")"
      local _svc _enabled _running _health _port _version
      IFS=$'\t' read -r _svc _enabled _running _health _port _version <<< "${web_status}"
      printf '%s\t%s\t%s\t%s\t%s\t%s\n' "${display_service}" "true" "${_running}" "${_health}" "${_port}" "${web_version}"
    else
      printf '%s\t%s\t%s\t%s\t%s\t%s\n' "${display_service}" "false" "false" "disabled" "-" "${web_version}"
    fi
    return 0
  fi

  plume_service_status "${display_service}" "${mode}"
}

plume_services_display_health() {
  local display_service="$1"
  local mode="${2:-$(plume_mode_current)}"
  if [[ "${mode}" != "laradock-bridge" ]] && plume_services_is_web_variant "${display_service}"; then
    if [[ "${mode}" == "laradock-bridge" ]]; then
      plume_service_health "${display_service}" "${mode}"
      return 0
    fi
    if [[ "$(plume_services_display_enabled "${display_service}" "${mode}")" == "true" ]]; then
      plume_service_health web "${mode}"
    else
      printf '%s' "disabled"
    fi
    return 0
  fi
  plume_service_health "${display_service}" "${mode}"
}

plume_services_group_name_from_target() {
  local target="${1:-}"
  case "${target}" in
    @*) printf '%s' "${target#@}" ;;
    group:*) printf '%s' "${target#group:}" ;;
    *) return 1 ;;
  esac
}

plume_services_group_members_raw() {
  local group="${1:-}"
  local mode="${2:-$(plume_mode_current)}"
  case "${mode}:${group}" in
    native:web|docker-lite:web)
      printf '%s\n' nginx apache2 caddy
      ;;
    native:db|docker-lite:db)
      printf '%s\n' mariadb mysql postgres phpmyadmin
      ;;
    native:cache|docker-lite:cache)
      printf '%s\n' redis mongodb rabbitmq mongo_webui redis_webui memcached
      ;;
    native:queue|docker-lite:queue)
      printf '%s\n' php_worker horizon supervisor
      ;;
    native:core|docker-lite:core)
      printf '%s\n' php composer nginx apache2 caddy mariadb mysql redis phpmyadmin php_worker horizon supervisor
      ;;
    laradock-bridge:web)
      printf '%s\n' nginx apache2 caddy openresty
      ;;
    laradock-bridge:db)
      printf '%s\n' mariadb mysql postgres postgres-postgis percona mongo mongodb redis redis-cluster memcached rabbitmq clickhouse rethinkdb neo4j nats ssdb mssql phpmyadmin
      ;;
    laradock-bridge:queue)
      printf '%s\n' php-worker laravel-horizon
      ;;
    laradock-bridge:core)
      printf '%s\n' workspace php-fpm php-worker laravel-horizon nginx apache2 caddy openresty mariadb mysql postgres redis phpmyadmin nodejs docker-in-docker
      ;;
    *)
      return 1
      ;;
  esac
}

plume_services_group_members() {
  local group="${1:-}"
  local mode="${2:-$(plume_mode_current)}"
  local service out=""
  while IFS= read -r service; do
    [[ -z "${service}" ]] && continue
    if ! plume_service_exists "${service}" "${mode}"; then
      continue
    fi
    if [[ ",${out}," == *",${service},"* ]]; then
      continue
    fi
    if [[ -n "${out}" ]]; then
      out="${out}"$'\n'"${service}"
    else
      out="${service}"
    fi
  done < <(plume_services_group_members_raw "${group}" "${mode}" || true)
  [[ -n "${out}" ]] || return 1
  printf '%s\n' "${out}"
}

plume_services_group_names_for_mode() {
  local mode="${1:-$(plume_mode_current)}"
  local group out=""
  for group in core web db queue; do
    if plume_services_group_members "${group}" "${mode}" >/dev/null 2>&1; then
      if [[ -n "${out}" ]]; then
        out="${out}"$'\n'"${group}"
      else
        out="${group}"
      fi
    fi
  done
  [[ -n "${out}" ]] || return 1
  printf '%s\n' "${out}"
}

plume_services_laradock_lifecycle_weight() {
  local service="${1:-}"
  local direction="${2:-up}"
  local category="other"
  case "${service}" in
    mariadb|mysql|postgres|postgres-postgis|percona|mongo|mongodb|redis|redis-cluster|memcached|rabbitmq|clickhouse|rethinkdb|neo4j|nats|ssdb|mssql|phpmyadmin)
      category="db"
      ;;
    workspace|php-fpm|php-fpm-*|php)
      category="php"
      ;;
    php-worker|laravel-horizon|horizon|supervisor)
      category="queue"
      ;;
    nginx|apache2|caddy|openresty|traefik|web)
      category="web"
      ;;
  esac
  if [[ "${direction}" == "down" ]]; then
    case "${category}" in
      web) echo "10" ;;
      queue) echo "20" ;;
      php) echo "30" ;;
      db) echo "40" ;;
      *) echo "50" ;;
    esac
  else
    case "${category}" in
      db) echo "10" ;;
      php) echo "20" ;;
      queue) echo "30" ;;
      web) echo "40" ;;
      *) echo "50" ;;
    esac
  fi
}

plume_services_laradock_ordered_targets() {
  local callback="${1:-plume_service_start}"
  local direction="up"
  case "${callback}" in
    plume_service_stop) direction="down" ;;
    *) direction="up" ;;
  esac
  local service weight
  local lines=""
  while IFS= read -r service; do
    [[ -z "${service}" ]] && continue
    weight="$(plume_services_laradock_lifecycle_weight "${service}" "${direction}")"
    if [[ -n "${lines}" ]]; then
      lines="${lines}"$'\n'"${weight}|${service}"
    else
      lines="${weight}|${service}"
    fi
  done < <(plume_services_laradock_resolved_list || true)
  [[ -n "${lines}" ]] || return 1
  printf '%s\n' "${lines}" | sort -t'|' -k1,1n -k2,2 | cut -d'|' -f2
}

plume_services_laradock_desired_cache_refresh() {
  if [[ "${PLUME_LARADOCK_DESIRED_CACHE_READY:-false}" == "true" ]]; then
    return 0
  fi
  PLUME_LARADOCK_DESIRED_CACHE_DATA="$(plume_services_laradock_desired_list 2>/dev/null || true)"
  PLUME_LARADOCK_DESIRED_CACHE_READY="true"
}

plume_services_laradock_resolved_cache_refresh() {
  if [[ "${PLUME_LARADOCK_RESOLVED_CACHE_READY:-false}" == "true" ]]; then
    return 0
  fi
  PLUME_LARADOCK_RESOLVED_CACHE_DATA="$(plume_services_laradock_resolved_list 2>/dev/null || true)"
  PLUME_LARADOCK_RESOLVED_CACHE_READY="true"
}

plume_services_laradock_desired_has() {
  local service="$1"
  plume_services_laradock_desired_cache_refresh
  grep -Fxq "${service}" <<< "${PLUME_LARADOCK_DESIRED_CACHE_DATA:-}"
}

plume_services_laradock_resolved_has() {
  local service="$1"
  plume_services_laradock_resolved_cache_refresh
  grep -Fxq "${service}" <<< "${PLUME_LARADOCK_RESOLVED_CACHE_DATA:-}"
}

cmd_services_supported() {
  local mode
  if ! mode="$(plume_services_parse_mode "$@")"; then
    return 2
  fi

  if [[ "${PLUME_OUTPUT:-text}" == "json" ]]; then
    local first="true"
    local first_group="true"
  printf '{"ok":true,"command":"services supported","data":{"mode":"%s","services":[' "${mode}"
    while IFS= read -r service; do
      [[ -z "${service}" ]] && continue
      if [[ "${first}" == "true" ]]; then
        first="false"
      else
        printf ','
      fi
      printf '{"name":"%s","enabled":%s,"version":"%s","require_supervisor":%s}' \
        "${service}" \
        "$(plume_services_display_enabled "${service}" "${mode}")" \
        "$(if plume_services_is_web_variant "${service}"; then plume_service_version web; else plume_service_version "${service}"; fi)" \
        "$(if [[ "${service}" == "horizon" && "$(plume_bool "${PLUME_HORIZON_REQUIRE_SUPERVISOR:-true}")" == "true" ]]; then printf 'true'; else printf 'false'; fi)"
    done < <(plume_services_display_names_for_mode "${mode}")
    printf '],"groups":['
    while IFS= read -r group; do
      [[ -z "${group}" ]] && continue
      if [[ "${first_group}" == "true" ]]; then
        first_group="false"
      else
        printf ','
      fi
      printf '{"name":"%s"}' "${group}"
    done < <(plume_services_group_names_for_mode "${mode}" || true)
    printf ']} ,"warnings":[],"errors":[]}\n'
    return 0
  fi

  echo "SERVICE           ENABLED"
  echo "----------------- -------"
  while IFS= read -r service; do
    [[ -z "${service}" ]] && continue
    printf '%-17s %s\n' "${service}" "$(plume_services_display_enabled "${service}" "${mode}")"
  done < <(plume_services_display_names_for_mode "${mode}")
  if plume_services_group_names_for_mode "${mode}" >/dev/null 2>&1; then
    echo
    echo "GROUP             MEMBERS"
    echo "----------------- ----------------------------------------"
    while IFS= read -r group; do
      [[ -z "${group}" ]] && continue
      local members
      members="$(plume_services_group_members "${group}" "${mode}" | paste -sd ',' -)"
      printf '%-17s %s\n' "@${group}" "${members}"
    done < <(plume_services_group_names_for_mode "${mode}")
  fi
}

cmd_services_status() {
  local mode
  if ! mode="$(plume_services_parse_mode "$@")"; then
    return 2
  fi
  local watch_interval=""
  local -a watch_args=()
  local arg
  watch_interval="$(plume_services_watch_interval "$@")"
  for arg in "$@"; do
    case "${arg}" in
      --watch|--watch=*) ;;
      *) watch_args+=("${arg}") ;;
    esac
  done
  if [[ -n "${watch_interval}" ]]; then
    if ! printf '%s' "${watch_interval}" | grep -Eq '^[0-9]+$'; then
      plume_err "invalid --watch value: ${watch_interval}"
      return 2
    fi
    if [[ "${PLUME_OUTPUT:-text}" == "json" ]]; then
      plume_err "--watch is not supported with json output"
      return 2
    fi
    if [[ "${PLUME_SERVICES_WATCH_CHILD:-false}" != "true" ]]; then
      while true; do
        if [[ -t 1 ]]; then
          printf '\033[H\033[2J'
        fi
        plume_services_watch_header "services status" "${watch_interval}"
        PLUME_SERVICES_WATCH_CHILD="true" cmd_services_status "${watch_args[@]}"
        sleep "${watch_interval}"
      done
    fi
  fi
  local running_only
  running_only="$(plume_services_status_running_only "$@")"
  local wide
  wide="$(plume_services_status_wide "$@")"
  local target normalized_target target_version_override group_name
  target="$(plume_services_first_positional "$@")"
  target="${target:-all}"
  normalized_target="$(plume_services_target_normalized "${target}" "${mode}")"
  target_version_override="$(plume_services_target_version_override "${target}" "${mode}")"
  group_name="$(plume_services_group_name_from_target "${target}" || true)"
  if [[ "${mode}" == "laradock-bridge" ]]; then
    plume_services_laradock_runtime_prepare "$@" || return 2
  fi
  if [[ "${mode}" == "docker-lite" ]]; then
    local target_path compose_file
    target_path="$(plume_services_workspace_parse_path "$@" || true)"
    if [[ -n "${target_path}" ]]; then
      if [[ "${target_path}" != /* ]]; then
        target_path="$(cd "${target_path}" 2>/dev/null && pwd || true)"
      fi
      if [[ -z "${target_path}" || ! -d "${target_path}" ]]; then
        plume_err "invalid --path for status command: ${target_path}"
        return 2
      fi
      compose_file="${target_path}/docker-compose.yml"
      if [[ ! -f "${compose_file}" ]]; then
        compose_file="${target_path}/compose.yml"
      fi
      if [[ ! -f "${compose_file}" ]]; then
        plume_err "no compose file found under ${target_path} (expected docker-compose.yml or compose.yml)"
        return 2
      fi
      PLUME_RUNTIME_DOCKER_LITE_COMPOSE_FILE="${compose_file}"
      plume_workspace_compose_state_set docker-lite "${compose_file}"
    fi
  fi

  if [[ "${PLUME_OUTPUT:-text}" == "json" ]]; then
    local first="true"
    printf '{"ok":true,"command":"services status","data":{"mode":"%s","services":[' "${mode}"
    if [[ "${target}" == "all" ]]; then
      while IFS= read -r service; do
        [[ -z "${service}" ]] && continue
        local running health port
        local status_line
        status_line="$(plume_services_display_status_line "${service}" "${mode}")"
        local _svc _enabled _running _health _port _version
        IFS=$'\t' read -r _svc _enabled _running _health _port _version <<< "${status_line}"
        running="${_running}"
        health="${_health}"
        if [[ "${mode}" == "docker-lite" ]]; then
          case "${health}" in
            healthy) running="true" ;;
            stopped|disabled) running="false" ;;
          esac
        fi
        if [[ "${running_only}" == "true" && "${running}" != "true" ]]; then
          continue
        fi
        if [[ "${first}" == "true" ]]; then
          first="false"
        else
          printf ','
        fi
        port="${_port}"
        printf '{"name":"%s","version":"%s","enabled":%s,"running":%s,"health":"%s","port":"%s","desired":%s,"resolved":%s,"require_supervisor":%s}' \
          "${service}" \
          "${_version}" \
          "${_enabled}" \
          "${running}" \
          "${health}" \
          "${port}" \
          "$(if [[ "${mode}" == "laradock-bridge" ]] && plume_services_laradock_desired_has "${service}"; then printf 'true'; else printf 'false'; fi)" \
          "$(if [[ "${mode}" == "laradock-bridge" ]] && plume_services_laradock_resolved_has "${service}"; then printf 'true'; else printf 'false'; fi)" \
          "$(if [[ "${service}" == "horizon" && "$(plume_bool "${PLUME_HORIZON_REQUIRE_SUPERVISOR:-true}")" == "true" ]]; then printf 'true'; else printf 'false'; fi)"
      done < <(plume_services_display_names_for_mode "${mode}")
    elif [[ -n "${group_name}" ]]; then
      local first_group_service="true"
      local group_seen="false"
      while IFS= read -r service; do
        [[ -z "${service}" ]] && continue
        group_seen="true"
        local running health port
        local status_line
        status_line="$(plume_services_display_status_line "${service}" "${mode}")"
        local _svc _enabled _running _health _port _version
        IFS=$'\t' read -r _svc _enabled _running _health _port _version <<< "${status_line}"
        running="${_running}"
        health="${_health}"
        if [[ "${mode}" == "docker-lite" ]]; then
          case "${health}" in
            healthy) running="true" ;;
            stopped|disabled) running="false" ;;
          esac
        fi
        if [[ "${running_only}" == "true" && "${running}" != "true" ]]; then
          continue
        fi
        if [[ "${first_group_service}" == "true" ]]; then
          first_group_service="false"
        else
          printf ','
        fi
        port="${_port}"
        printf '{"name":"%s","version":"%s","enabled":%s,"running":%s,"health":"%s","port":"%s","desired":%s,"resolved":%s,"require_supervisor":%s}' \
          "${service}" \
          "${_version}" \
          "${_enabled}" \
          "${running}" \
          "${health}" \
          "${port}" \
          "$(if [[ "${mode}" == "laradock-bridge" ]] && plume_services_laradock_desired_has "${service}"; then printf 'true'; else printf 'false'; fi)" \
          "$(if [[ "${mode}" == "laradock-bridge" ]] && plume_services_laradock_resolved_has "${service}"; then printf 'true'; else printf 'false'; fi)" \
          "$(if [[ "${service}" == "horizon" && "$(plume_bool "${PLUME_HORIZON_REQUIRE_SUPERVISOR:-true}")" == "true" ]]; then printf 'true'; else printf 'false'; fi)"
      done < <(plume_services_group_members "${group_name}" "${mode}" || true)
      if [[ "${group_seen}" != "true" ]]; then
        plume_err "unknown or empty service group: ${group_name}"
        return 2
      fi
    else
      if ! plume_service_exists "${target}" "${mode}" && ! plume_service_exists "${normalized_target}" "${mode}" && ! plume_services_is_web_variant "${target}"; then
        plume_err "unknown service: ${target}"
        return 2
      fi
      local running health port
      local status_line
      if [[ -n "${target_version_override}" ]]; then
        status_line="$(PLUME_SERVICE_VERSION="${target_version_override}" plume_services_display_status_line "${normalized_target}" "${mode}")"
      else
        status_line="$(plume_services_display_status_line "${normalized_target}" "${mode}")"
      fi
      local _svc _enabled _running _health _port _version
      IFS=$'\t' read -r _svc _enabled _running _health _port _version <<< "${status_line}"
      running="${_running}"
      health="${_health}"
      if [[ "${mode}" == "docker-lite" ]]; then
        case "${health}" in
          healthy) running="true" ;;
          stopped|disabled) running="false" ;;
        esac
      fi
      if [[ "${running_only}" == "true" && "${running}" != "true" ]]; then
        printf ']} ,"warnings":[],"errors":[]}\n'
        return 0
      fi
      port="${_port}"
      printf '{"name":"%s","version":"%s","enabled":%s,"running":%s,"health":"%s","port":"%s","desired":%s,"resolved":%s,"require_supervisor":%s}' \
        "${_svc}" \
        "${_version}" \
        "${_enabled}" \
        "${running}" \
        "${health}" \
        "${port}" \
        "$(if [[ "${mode}" == "laradock-bridge" ]] && plume_services_laradock_desired_has "${_svc}"; then printf 'true'; else printf 'false'; fi)" \
        "$(if [[ "${mode}" == "laradock-bridge" ]] && plume_services_laradock_resolved_has "${_svc}"; then printf 'true'; else printf 'false'; fi)" \
        "$(if [[ "${_svc}" == "horizon" && "$(plume_bool "${PLUME_HORIZON_REQUIRE_SUPERVISOR:-true}")" == "true" ]]; then printf 'true'; else printf 'false'; fi)"
    fi
    printf ']} ,"warnings":[],"errors":[]}\n'
    return 0
  fi

  if [[ "${mode}" == "laradock-bridge" ]]; then
    printf 'MODE              %s\n' "${mode}"
    printf 'CONTEXT           %s\n' "${PLUME_RUNTIME_LARADOCK_PATH:-$(plume_mode_path_get laradock-bridge || true)}"
  else
    printf 'MODE              %s\n' "${mode}"
  fi
  if [[ -n "${group_name}" ]]; then
    printf 'GROUP             %s\n' "@${group_name}"
  fi
  if [[ "${running_only}" == "true" ]]; then
    printf 'FILTER            running-only\n'
  fi
  if [[ "${wide}" == "true" ]]; then
    printf 'VIEW              wide\n'
  fi
  if [[ "${mode}" == "laradock-bridge" ]]; then
    echo "SERVICE           ENABLED RUNNING HEALTH   PORT             DESIRED RESOLVED VERSION"
    echo "----------------- ------- ------- -------- ---------------- ------- -------- -------"
  else
    echo "SERVICE           ENABLED RUNNING HEALTH   PORT   VERSION"
    echo "----------------- ------- ------- -------- ------ -------"
  fi
  if [[ "${target}" == "all" ]]; then
    while IFS= read -r service; do
      [[ -z "${service}" ]] && continue
      local status_line
      status_line="$(plume_services_display_status_line "${service}" "${mode}")"
      local _svc _enabled _running _health _port _version
      IFS=$'\t' read -r _svc _enabled _running _health _port _version <<< "${status_line}"
      if [[ "${mode}" == "docker-lite" ]]; then
        case "${_health}" in
          healthy) _running="true" ;;
          stopped|disabled) _running="false" ;;
        esac
      fi
      if [[ "${running_only}" == "true" && "${_running}" != "true" ]]; then
        continue
      fi
      if [[ "${mode}" == "laradock-bridge" ]]; then
        if [[ "${wide}" != "true" ]]; then
          _port="$(plume_services_status_port_text "${_port}")"
        fi
        printf '%-17s %-7s %-7s %-8s %-16s %-7s %-8s %s\n' \
          "${_svc}" "${_enabled}" "${_running}" "${_health}" "${_port}" \
          "$(if plume_services_laradock_desired_has "${_svc}"; then printf 'true'; else printf 'false'; fi)" \
          "$(if plume_services_laradock_resolved_has "${_svc}"; then printf 'true'; else printf 'false'; fi)" \
          "${_version}"
      else
        printf '%-17s %-7s %-7s %-8s %-6s %s\n' "${_svc}" "${_enabled}" "${_running}" "${_health}" "${_port}" "${_version}"
      fi
    done < <(plume_services_display_names_for_mode "${mode}")
    return 0
  fi
  if [[ -n "${group_name}" ]]; then
    local emitted="false"
    while IFS= read -r service; do
      [[ -z "${service}" ]] && continue
      emitted="true"
      local status_line
      status_line="$(plume_services_display_status_line "${service}" "${mode}")"
      local _svc _enabled _running _health _port _version
      IFS=$'\t' read -r _svc _enabled _running _health _port _version <<< "${status_line}"
      if [[ "${mode}" == "docker-lite" ]]; then
        case "${_health}" in
          healthy) _running="true" ;;
          stopped|disabled) _running="false" ;;
        esac
      fi
      if [[ "${running_only}" == "true" && "${_running}" != "true" ]]; then
        continue
      fi
      if [[ "${mode}" == "laradock-bridge" ]]; then
        if [[ "${wide}" != "true" ]]; then
          _port="$(plume_services_status_port_text "${_port}")"
        fi
        printf '%-17s %-7s %-7s %-8s %-16s %-7s %-8s %s\n' \
          "${_svc}" "${_enabled}" "${_running}" "${_health}" "${_port}" \
          "$(if plume_services_laradock_desired_has "${_svc}"; then printf 'true'; else printf 'false'; fi)" \
          "$(if plume_services_laradock_resolved_has "${_svc}"; then printf 'true'; else printf 'false'; fi)" \
          "${_version}"
      else
        printf '%-17s %-7s %-7s %-8s %-6s %s\n' "${_svc}" "${_enabled}" "${_running}" "${_health}" "${_port}" "${_version}"
      fi
    done < <(plume_services_group_members "${group_name}" "${mode}" || true)
    if [[ "${emitted}" != "true" ]]; then
      plume_err "unknown or empty service group: ${group_name}"
      return 2
    fi
    return 0
  fi
  if ! plume_service_exists "${target}" "${mode}" && ! plume_service_exists "${normalized_target}" "${mode}" && ! plume_services_is_web_variant "${target}"; then
    plume_err "unknown service: ${target}"
    return 2
  fi
  local status_line
  if [[ -n "${target_version_override}" ]]; then
    status_line="$(PLUME_SERVICE_VERSION="${target_version_override}" plume_services_display_status_line "${normalized_target}" "${mode}")"
  else
    status_line="$(plume_services_display_status_line "${normalized_target}" "${mode}")"
  fi
  local _svc _enabled _running _health _port _version
  IFS=$'\t' read -r _svc _enabled _running _health _port _version <<< "${status_line}"
  if [[ "${mode}" == "docker-lite" ]]; then
    case "${_health}" in
      healthy) _running="true" ;;
      stopped|disabled) _running="false" ;;
    esac
  fi
  if [[ "${running_only}" == "true" && "${_running}" != "true" ]]; then
    return 0
  fi
  if [[ "${mode}" == "laradock-bridge" ]]; then
    if [[ "${wide}" != "true" ]]; then
      _port="$(plume_services_status_port_text "${_port}")"
    fi
    printf '%-17s %-7s %-7s %-8s %-16s %-7s %-8s %s\n' \
      "${_svc}" "${_enabled}" "${_running}" "${_health}" "${_port}" \
      "$(if plume_services_laradock_desired_has "${_svc}"; then printf 'true'; else printf 'false'; fi)" \
      "$(if plume_services_laradock_resolved_has "${_svc}"; then printf 'true'; else printf 'false'; fi)" \
      "${_version}"
  else
    printf '%-17s %-7s %-7s %-8s %-6s %s\n' "${_svc}" "${_enabled}" "${_running}" "${_health}" "${_port}" "${_version}"
  fi
}

services_each_target() {
  local target="$1"
  local callback="$2"
  local mode="${3:-enabled}"
  local mode_name="${4:-$(plume_mode_current)}"
  local group_name=""

  group_name="$(plume_services_group_name_from_target "${target}" || true)"

  if [[ "${target}" == "all" ]]; then
    local emitted="false"
    local service normalized_service version target_version
    if [[ "${mode_name}" == "laradock-bridge" ]]; then
      local -a started_services=()
      while IFS= read -r service; do
        [[ -z "${service}" ]] && continue
        emitted="true"
        normalized_service="$(plume_service_contract_normalize "${service}" "${mode_name}")"
        target_version="$(plume_services_target_version_override "${service}" "${mode_name}")"
        if [[ -n "${target_version}" ]]; then
          version="$(plume_service_version "${normalized_service}" "${target_version}")"
        else
          version="$(plume_service_version "${normalized_service}" "${PLUME_SERVICE_VERSION:-}")"
        fi
        if [[ ("${callback}" == "plume_service_install" || "${callback}" == "plume_service_start") && "${normalized_service}" == "php" ]]; then
          plume_php_version_normalize "${version}" >/dev/null || return 2
        else
          if ! plume_service_validate_version "${normalized_service}" "${version}"; then
            return 2
          fi
        fi
        if ! plume_service_wrapper_invoke "${mode_name}" "${callback}" "${normalized_service}" "${version}"; then
          if [[ "${callback}" == "plume_service_start" && ${#started_services[@]} -gt 0 ]]; then
            local rollback_service
            plume_warn "laradock-bridge start failed on ${service}; rolling back started services"
            for (( idx=${#started_services[@]}-1; idx>=0; idx-- )); do
              rollback_service="${started_services[$idx]}"
              PLUME_MODE="${mode_name}" PLUME_SERVICE_VERSION="latest" plume_service_stop "${rollback_service}" || {
                plume_warn "rollback stop failed for ${rollback_service}; manual cleanup may be required"
              }
            done
          fi
          return 2
        fi
        if [[ "${callback}" == "plume_service_start" ]]; then
          started_services+=("${normalized_service}")
        fi
      done < <(plume_services_laradock_ordered_targets "${callback}" || true)
      if [[ "${emitted}" != "true" ]]; then
        plume_err "laradock desired service set is empty; use services config add <service|@group>"
        return 2
      fi
      return 0
    fi
    while IFS= read -r service; do
      [[ -z "${service}" ]] && continue
      if [[ "${mode}" == "enabled" && "$(plume_service_enabled_for_mode "${service}" "${mode_name}")" != "true" ]]; then
        continue
      fi
      emitted="true"
      normalized_service="$(plume_service_contract_normalize "${service}" "${mode_name}")"
      target_version="$(plume_services_target_version_override "${service}" "${mode_name}")"
      if [[ -n "${target_version}" ]]; then
        version="$(plume_service_version "${normalized_service}" "${target_version}")"
      else
        version="$(plume_service_version "${normalized_service}" "${PLUME_SERVICE_VERSION:-}")"
      fi
      if [[ ("${callback}" == "plume_service_install" || "${callback}" == "plume_service_start") && "${normalized_service}" == "php" ]]; then
        plume_php_version_normalize "${version}" >/dev/null || return 2
      else
        if ! plume_service_validate_version "${normalized_service}" "${version}"; then
          return 2
        fi
      fi
      plume_service_wrapper_invoke "${mode_name}" "${callback}" "${normalized_service}" "${version}"
    done < <(plume_service_names_for_mode "${mode_name}")
    return 0
  fi

  if [[ -n "${group_name}" ]]; then
    local group_members_found="false"
    local service normalized_service version target_version
    while IFS= read -r service; do
      [[ -z "${service}" ]] && continue
      group_members_found="true"
      if [[ "${mode_name}" != "laradock-bridge" && "${mode}" == "enabled" && "$(plume_service_enabled_for_mode "${service}" "${mode_name}")" != "true" ]]; then
        continue
      fi
      normalized_service="$(plume_service_contract_normalize "${service}" "${mode_name}")"
      target_version="$(plume_services_target_version_override "${service}" "${mode_name}")"
      if [[ -n "${target_version}" ]]; then
        version="$(plume_service_version "${normalized_service}" "${target_version}")"
      else
        version="$(plume_service_version "${normalized_service}" "${PLUME_SERVICE_VERSION:-}")"
      fi
      if [[ ("${callback}" == "plume_service_install" || "${callback}" == "plume_service_start") && "${normalized_service}" == "php" ]]; then
        plume_php_version_normalize "${version}" >/dev/null || return 2
      else
        if ! plume_service_validate_version "${normalized_service}" "${version}"; then
          return 2
        fi
      fi
      plume_service_wrapper_invoke "${mode_name}" "${callback}" "${normalized_service}" "${version}"
    done < <(plume_services_group_members "${group_name}" "${mode_name}" || true)
    if [[ "${group_members_found}" != "true" ]]; then
      plume_err "unknown or empty service group: ${group_name}"
      return 2
    fi
    return 0
  fi

  if ! plume_service_exists "${target}" "${mode_name}"; then
    plume_err "unknown service: ${target}"
    return 2
  fi
  local normalized_target version target_version
  normalized_target="$(plume_service_contract_normalize "${target}" "${mode_name}")"
  target_version="$(plume_services_target_version_override "${target}" "${mode_name}")"
  if [[ -n "${target_version}" ]]; then
    version="$(plume_service_version "${normalized_target}" "${target_version}")"
  else
    version="$(plume_service_version "${normalized_target}" "${PLUME_SERVICE_VERSION:-}")"
  fi
  if [[ ("${callback}" == "plume_service_install" || "${callback}" == "plume_service_start") && "${normalized_target}" == "php" ]]; then
    plume_php_version_normalize "${version}" >/dev/null || return 2
  else
    if ! plume_service_validate_version "${normalized_target}" "${version}"; then
      return 2
    fi
  fi
  plume_service_wrapper_invoke "${mode_name}" "${callback}" "${normalized_target}" "${version}"
}

cmd_services_install() {
  if ! plume_services_parse_version "$@"; then
    return 2
  fi
  local mode target
  if ! mode="$(plume_services_parse_mode "$@")"; then
    return 2
  fi
  if [[ "${mode}" == "native" ]]; then
    plume_require_native_install_privileges || return 2
  fi
  target="$(plume_services_first_positional "$@")"
  target="${target:-}"
  if [[ -z "${target}" ]]; then
    plume_err "service name required (or all)"
    return 2
  fi
  services_each_target "${target}" "plume_service_install" all "${mode}"
  plume_context_lock_activate "services install" "${mode}"
}

cmd_services_up() {
  local mode target
  if ! plume_services_parse_version "$@"; then
    return 2
  fi
  if ! mode="$(plume_services_parse_mode "$@")"; then
    return 2
  fi
  if [[ "${mode}" == "laradock-bridge" ]]; then
    plume_services_laradock_runtime_prepare "$@" || return 2
  fi
  target="$(plume_services_first_positional "$@")"
  target="${target:-}"
  if [[ -z "${target}" ]]; then
    plume_err "service name required (or all)"
    return 2
  fi
  services_each_target "${target}" "plume_service_start" enabled "${mode}"
  plume_context_lock_activate "services up" "${mode}"
}

cmd_services_down() {
  local mode target
  if ! plume_services_parse_version "$@"; then
    return 2
  fi
  if ! mode="$(plume_services_parse_mode "$@")"; then
    return 2
  fi
  if [[ "${mode}" == "laradock-bridge" ]]; then
    plume_services_laradock_runtime_prepare "$@" || return 2
  fi
  target="$(plume_services_first_positional "$@")"
  target="${target:-}"
  if [[ -z "${target}" ]]; then
    plume_err "service name required (or all)"
    return 2
  fi
  services_each_target "${target}" "plume_service_stop" enabled "${mode}"
  plume_context_lock_try_clear_if_idle
}

cmd_services_health() {
  local mode target
  if ! mode="$(plume_services_parse_mode "$@")"; then
    return 2
  fi
  local watch_interval=""
  local -a watch_args=()
  local arg
  watch_interval="$(plume_services_watch_interval "$@")"
  for arg in "$@"; do
    case "${arg}" in
      --watch|--watch=*) ;;
      *) watch_args+=("${arg}") ;;
    esac
  done
  if [[ -n "${watch_interval}" ]]; then
    if ! printf '%s' "${watch_interval}" | grep -Eq '^[0-9]+$'; then
      plume_err "invalid --watch value: ${watch_interval}"
      return 2
    fi
    if [[ "${PLUME_OUTPUT:-text}" == "json" ]]; then
      plume_err "--watch is not supported with json output"
      return 2
    fi
    if [[ "${PLUME_SERVICES_WATCH_CHILD:-false}" != "true" ]]; then
      while true; do
        if [[ -t 1 ]]; then
          printf '\033[H\033[2J'
        fi
        plume_services_watch_header "services health" "${watch_interval}"
        PLUME_SERVICES_WATCH_CHILD="true" cmd_services_health "${watch_args[@]}"
        sleep "${watch_interval}"
      done
    fi
  fi
  local running_only
  running_only="$(plume_services_status_running_only "$@")"
  if [[ "${mode}" == "laradock-bridge" ]]; then
    plume_services_laradock_runtime_prepare "$@" || return 2
  fi
  target="$(plume_services_first_positional "$@")"
  target="${target:-all}"
  normalized_target="$(plume_services_target_normalized "${target}" "${mode}")"
  target_version_override="$(plume_services_target_version_override "${target}" "${mode}")"
  local group_name=""
  group_name="$(plume_services_group_name_from_target "${target}" || true)"

  if [[ "${PLUME_OUTPUT:-text}" == "json" ]]; then
    local first="true"
    printf '{"ok":true,"command":"services health","data":{"mode":"%s","services":[' "${mode}"
    if [[ "${target}" == "all" ]]; then
      while IFS= read -r service; do
        [[ -z "${service}" ]] && continue
        if [[ "${running_only}" == "true" ]] && ! plume_services_target_running "${service}" "${mode}"; then
          continue
        fi
        if [[ "${first}" == "true" ]]; then
          first="false"
        else
          printf ','
        fi
        printf '{"name":"%s","health":"%s"}' "${service}" "$(plume_services_display_health "${service}" "${mode}")"
      done < <(plume_services_display_names_for_mode "${mode}")
    else
      if [[ -n "${group_name}" ]]; then
        local first_group_service="true"
        local group_seen="false"
        while IFS= read -r service; do
          [[ -z "${service}" ]] && continue
          group_seen="true"
          if [[ "${running_only}" == "true" ]] && ! plume_services_target_running "${service}" "${mode}"; then
            continue
          fi
          if [[ "${first_group_service}" == "true" ]]; then
            first_group_service="false"
          else
            printf ','
          fi
          printf '{"name":"%s","health":"%s"}' "${service}" "$(plume_services_display_health "${service}" "${mode}")"
        done < <(plume_services_group_members "${group_name}" "${mode}" || true)
        if [[ "${group_seen}" != "true" ]]; then
          plume_err "unknown or empty service group: ${group_name}"
          return 2
        fi
      elif ! plume_service_exists "${target}" "${mode}" && ! plume_service_exists "${normalized_target}" "${mode}" && ! plume_services_is_web_variant "${target}"; then
        plume_err "unknown service: ${target}"
        return 2
      else
        if [[ "${running_only}" == "true" ]] && ! plume_services_target_running "${normalized_target}" "${mode}" "${target_version_override}"; then
          printf ']},"warnings":[],"errors":[]}\n'
          return 0
        fi
        if [[ -n "${target_version_override}" ]]; then
          printf '{"name":"%s","health":"%s"}' "${normalized_target}" "$(PLUME_SERVICE_VERSION="${target_version_override}" plume_services_display_health "${normalized_target}" "${mode}")"
        else
          printf '{"name":"%s","health":"%s"}' "${normalized_target}" "$(plume_services_display_health "${normalized_target}" "${mode}")"
        fi
      fi
    fi
    printf ']},"warnings":[],"errors":[]}\n'
    return 0
  fi

  if [[ "${mode}" == "laradock-bridge" ]]; then
    printf 'MODE              %s\n' "${mode}"
    printf 'CONTEXT           %s\n' "${PLUME_RUNTIME_LARADOCK_PATH:-$(plume_mode_path_get laradock-bridge || true)}"
  else
    printf 'MODE              %s\n' "${mode}"
  fi
  if [[ "${running_only}" == "true" ]]; then
    printf 'FILTER            running-only\n'
  fi

  if [[ "${target}" == "all" ]]; then
    printf 'SERVICE           HEALTH\n'
    printf '%s\n' '----------------- --------'
    while IFS= read -r service; do
      [[ -z "${service}" ]] && continue
      if [[ "${running_only}" == "true" ]] && ! plume_services_target_running "${service}" "${mode}"; then
        continue
      fi
      printf '%-17s %s\n' "${service}" "$(plume_services_display_health "${service}" "${mode}")"
    done < <(plume_services_display_names_for_mode "${mode}")
    return 0
  fi

  if [[ -n "${group_name}" ]]; then
    printf 'GROUP             %s\n' "@${group_name}"
    printf 'SERVICE           HEALTH\n'
    printf '%s\n' '----------------- --------'
    local emitted="false"
    while IFS= read -r service; do
      [[ -z "${service}" ]] && continue
      emitted="true"
      if [[ "${running_only}" == "true" ]] && ! plume_services_target_running "${service}" "${mode}"; then
        continue
      fi
      printf '%-17s %s\n' "${service}" "$(plume_services_display_health "${service}" "${mode}")"
    done < <(plume_services_group_members "${group_name}" "${mode}" || true)
    if [[ "${emitted}" != "true" ]]; then
      plume_err "unknown or empty service group: ${group_name}"
      return 2
    fi
    return 0
  fi

  if ! plume_service_exists "${target}" "${mode}" && ! plume_service_exists "${normalized_target}" "${mode}" && ! plume_services_is_web_variant "${target}"; then
    plume_err "unknown service: ${target}"
    return 2
  fi
  if [[ "${running_only}" == "true" ]] && ! plume_services_target_running "${normalized_target}" "${mode}" "${target_version_override}"; then
    return 0
  fi
  printf 'SERVICE           HEALTH\n'
  printf '%s\n' '----------------- --------'
  if [[ -n "${target_version_override}" ]]; then
    printf '%-17s %s\n' "${normalized_target}" "$(PLUME_SERVICE_VERSION="${target_version_override}" plume_services_display_health "${normalized_target}" "${mode}")"
  else
    printf '%-17s %s\n' "${normalized_target}" "$(plume_services_display_health "${normalized_target}" "${mode}")"
  fi
}

cmd_services_logs() {
  local mode target normalized_target target_version_override tail_count="30" follow="false" running_only="false"
  if ! mode="$(plume_services_parse_mode "$@")"; then
    return 2
  fi
  follow="$(plume_services_logs_follow "$@")"
  running_only="$(plume_services_status_running_only "$@")"
  if [[ "${mode}" == "laradock-bridge" ]]; then
    plume_services_laradock_runtime_prepare "$@" || return 2
  fi

  local arg
  for arg in "$@"; do
    case "${arg}" in
      --tail=*) tail_count="${arg#*=}" ;;
    esac
  done

  if ! printf '%s' "${tail_count}" | grep -Eq '^[0-9]+$'; then
    plume_err "invalid --tail value: ${tail_count}"
    return 2
  fi

  target="$(plume_services_first_positional "$@")"
  target="${target:-}"
  if [[ -z "${target}" ]]; then
    plume_err "service name required for logs"
    return 2
  fi
  normalized_target="$(plume_services_target_normalized "${target}" "${mode}")"
  target_version_override="$(plume_services_target_version_override "${target}" "${mode}")"

  local group_name=""
  group_name="$(plume_services_group_name_from_target "${target}" || true)"
  local -a services=()
  local service
  if [[ "${target}" == "all" ]]; then
    while IFS= read -r service; do
      [[ -z "${service}" ]] && continue
      services+=("${service}")
    done < <(plume_services_display_names_for_mode "${mode}")
  elif [[ -n "${group_name}" ]]; then
    while IFS= read -r service; do
      [[ -z "${service}" ]] && continue
      services+=("${service}")
    done < <(plume_services_group_members "${group_name}" "${mode}" || true)
    if [[ ${#services[@]} -eq 0 ]]; then
      plume_err "unknown or empty service group: ${group_name}"
      return 2
    fi
  else
    if ! plume_service_exists "${target}" "${mode}" && ! plume_service_exists "${normalized_target}" "${mode}" && ! plume_services_is_web_variant "${target}"; then
      plume_err "unknown service: ${target}"
      return 2
    fi
    services=("${normalized_target}")
  fi

  if [[ "${running_only}" == "true" ]]; then
    local -a filtered=()
    for service in "${services[@]}"; do
      if plume_services_target_running "${service}" "${mode}" "${target_version_override}"; then
        filtered+=("${service}")
      fi
    done
    services=("${filtered[@]}")
  fi

  if [[ "${PLUME_OUTPUT:-text}" == "json" ]]; then
    local first="true"
    printf '{"ok":true,"command":"services logs","data":{"mode":"%s","target":"%s","tail":%s,"follow":%s,"services":[' \
      "${mode}" "${target}" "${tail_count}" "${follow}"
    for service in "${services[@]}"; do
      local content
      if [[ -n "${target_version_override}" && "${service}" == "php" ]]; then
        content="$(PLUME_SERVICE_VERSION="${target_version_override}" plume_service_logs "${service}" "${mode}" "${tail_count}" "false" | sed ':a;N;$!ba;s/\n/\\n/g')"
      else
        content="$(plume_service_logs "${service}" "${mode}" "${tail_count}" "false" | sed ':a;N;$!ba;s/\n/\\n/g')"
      fi
      if [[ "${first}" == "true" ]]; then
        first="false"
      else
        printf ','
      fi
      printf '{"name":"%s","content":"%s"}' "${service}" "${content}"
    done
    printf ']},"warnings":[],"errors":[]}\n'
    return 0
  fi

  if [[ ${#services[@]} -eq 0 ]]; then
    return 0
  fi

  if [[ ("${mode}" == "laradock-bridge" || "${mode}" == "docker-lite") && ${#services[@]} -gt 1 ]]; then
    local compose_file
    local -a compose_services=()
    if [[ "${mode}" == "laradock-bridge" ]]; then
      compose_file="$(plume_laradock_bridge_compose_file_runtime || true)"
      for service in "${services[@]}"; do
        compose_services+=("$(plume_laradock_bridge_service_name "${service}")")
      done
    else
      compose_file="$(plume_docker_lite_compose_file)"
      for service in "${services[@]}"; do
        compose_services+=("$(plume_docker_lite_service_name "${service}")")
      done
    fi
    if [[ -n "${compose_file}" && -f "${compose_file}" ]] && (plume_docker_compose_has_v2 || plume_docker_compose_has_v1); then
      if [[ "${follow}" == "true" ]]; then
        plume_docker_compose_exec "${compose_file}" logs -f --tail "${tail_count}" "${compose_services[@]}"
      else
        plume_docker_compose_exec "${compose_file}" logs --tail "${tail_count}" "${compose_services[@]}"
      fi
      return 0
    fi
  fi

  local printed_header="false"
  for service in "${services[@]}"; do
    if [[ ${#services[@]} -gt 1 ]]; then
      if [[ "${printed_header}" == "true" ]]; then
        printf '\n'
      fi
      printf '==> %s <==\n' "${service}"
      printed_header="true"
    fi
    if [[ -n "${target_version_override}" && "${service}" == "php" ]]; then
      PLUME_SERVICE_VERSION="${target_version_override}" plume_service_logs "${service}" "${mode}" "${tail_count}" "${follow}"
    else
      plume_service_logs "${service}" "${mode}" "${tail_count}" "${follow}"
    fi
  done
}

cmd_services_config() {
  local sub="${1:-show}"
  shift || true

  local mode
  if ! mode="$(plume_services_parse_mode "$@")"; then
    return 2
  fi
  if [[ "${mode}" != "laradock-bridge" ]]; then
    plume_err "services config is currently supported only for --mode=laradock-bridge"
    return 2
  fi
  plume_services_laradock_runtime_prepare "$@" || return 2

  local path target count service members group_name
  path="$(plume_services_laradock_context_key || true)"
  count="$(plume_services_laradock_desired_count "${path}")"

  case "${sub}" in
    show)
      local resolved_count
      resolved_count="$( (plume_services_laradock_resolved_list "${path}" || true) | sed '/^$/d' | wc -l | tr -d ' ' )"
      if [[ "${PLUME_OUTPUT:-text}" == "json" ]]; then
        local first="true"
        local first_resolved="true"
        printf '{"ok":true,"command":"services config show","data":{"mode":"laradock-bridge","context":"%s","desired_count":%s,"resolved_count":%s,"desired_services":[' "${path}" "${count:-0}" "${resolved_count:-0}"
        while IFS= read -r service; do
          [[ -z "${service}" ]] && continue
          if [[ "${first}" == "true" ]]; then
            first="false"
          else
            printf ','
          fi
          printf '{"name":"%s"}' "${service}"
        done < <(plume_services_laradock_desired_list "${path}" || true)
        printf '],"resolved_services":['
        while IFS= read -r service; do
          [[ -z "${service}" ]] && continue
          if [[ "${first_resolved}" == "true" ]]; then
            first_resolved="false"
          else
            printf ','
          fi
          printf '{"name":"%s"}' "${service}"
        done < <(plume_services_laradock_resolved_list "${path}" || true)
        printf ']},"warnings":[],"errors":[]}\n'
        return 0
      fi
      printf 'MODE              %s\n' "laradock-bridge"
      printf 'CONTEXT           %s\n' "${path}"
      printf 'DESIRED_COUNT     %s\n' "${count:-0}"
      printf 'RESOLVED_COUNT    %s\n' "${resolved_count:-0}"
      printf 'DESIRED           ENABLED\n'
      printf '%s\n' '----------------- -------'
      while IFS= read -r service; do
        [[ -z "${service}" ]] && continue
        printf '%-17s %s\n' "${service}" "true"
      done < <(plume_services_laradock_desired_list "${path}" || true)
      if [[ "${count:-0}" == "0" ]]; then
        printf '%s\n' 'no desired services configured'
      fi
      printf '\n'
      printf 'RESOLVED          AUTO\n'
      printf '%s\n' '----------------- -------'
      while IFS= read -r service; do
        [[ -z "${service}" ]] && continue
        if grep -Fxq "${service}" < <(plume_services_laradock_desired_list "${path}" || true); then
          printf '%-17s %s\n' "${service}" "false"
        else
          printf '%-17s %s\n' "${service}" "true"
        fi
      done < <(plume_services_laradock_resolved_list "${path}" || true)
      if [[ "${resolved_count:-0}" == "0" ]]; then
        printf '%s\n' 'no resolved services'
      fi
      ;;
    add)
      target="$(plume_services_first_positional "$@")"
      [[ -n "${target}" ]] || {
        plume_err "services config add requires <service|@group>"
        return 2
      }
      if ! plume_services_laradock_desired_add_target "${target}" "${path}"; then
        plume_err "unable to add desired target: ${target}"
        return 2
      fi
      group_name="$(plume_services_group_name_from_target "${target}" || true)"
      if [[ -n "${group_name}" ]]; then
        members="$(plume_services_group_members "${group_name}" "laradock-bridge" | paste -sd ',' -)"
        plume_info "desired services added for @${group_name}: ${members}"
      else
        plume_info "desired service added: $(plume_laradock_bridge_service_name "${target}")"
      fi
      ;;
    remove)
      target="$(plume_services_first_positional "$@")"
      [[ -n "${target}" ]] || {
        plume_err "services config remove requires <service|@group>"
        return 2
      }
      if ! plume_services_laradock_desired_remove_target "${target}" "${path}"; then
        plume_err "unable to remove desired target: ${target}"
        return 2
      fi
      group_name="$(plume_services_group_name_from_target "${target}" || true)"
      if [[ -n "${group_name}" ]]; then
        plume_info "desired services removed for @${group_name}"
      else
        plume_info "desired service removed: $(plume_laradock_bridge_service_name "${target}")"
      fi
      ;;
    reset|clear)
      plume_state_db_desired_services_clear "laradock-bridge" "${path}"
      plume_info "desired services cleared for ${path}"
      ;;
    *)
      plume_err "unknown services config subcommand: ${sub}"
      return 2
      ;;
  esac
}

plume_services_workspace_collect_images() {
  local compose_file="$1"
  shift || true
  plume_docker_compose_exec "${compose_file}" "$@" config --images 2>/dev/null || return 1
}

plume_services_workspace_parse_path() {
  local arg
  for arg in "$@"; do
    case "${arg}" in
      --path=*)
        printf '%s' "${arg#*=}"
        return 0
        ;;
    esac
  done
  return 1
}

plume_services_laradock_runtime_prepare() {
  local path
  if command -v plume_laradock_bridge_cache_clear >/dev/null 2>&1; then
    plume_laradock_bridge_cache_clear
  fi
  unset PLUME_LARADOCK_DESIRED_CACHE_READY PLUME_LARADOCK_DESIRED_CACHE_DATA PLUME_LARADOCK_RESOLVED_CACHE_READY PLUME_LARADOCK_RESOLVED_CACHE_DATA || true
  path="$(plume_services_workspace_parse_path "$@" || true)"
  if [[ -n "${path}" && "${path}" != /* ]]; then
    path="$(cd "${path}" 2>/dev/null && pwd || true)"
  fi
  if [[ -z "${path}" ]]; then
    path="$(plume_services_laradock_resolve_path "$@" || true)"
  fi
  if ! plume_services_laradock_context_validate "${path}" "true" "false"; then
    return 2
  fi
  export PLUME_RUNTIME_LARADOCK_PATH="${path}"
  export PLUME_RUNTIME_LARADOCK_COMPOSE_FILE
  PLUME_RUNTIME_LARADOCK_COMPOSE_FILE="$(plume_services_laradock_resolve_compose_file "${path}")"
  if command -v plume_laradock_bridge_runtime_cache_refresh >/dev/null 2>&1; then
    plume_laradock_bridge_runtime_cache_refresh >/dev/null 2>&1 || true
  fi
  plume_mode_path_set laradock-bridge "${path}"
  return 0
}

plume_services_laradock_context_key() {
  local path="${1:-${PLUME_RUNTIME_LARADOCK_PATH:-}}"
  if [[ -z "${path}" ]]; then
    path="$(plume_mode_path_get laradock-bridge || true)"
  fi
  [[ -n "${path}" ]] || return 1
  if [[ "${path}" != /* ]]; then
    path="$(cd "${path}" 2>/dev/null && pwd || true)"
  fi
  [[ -n "${path}" ]] || return 1
  printf '%s' "${path}"
}

plume_services_laradock_desired_list() {
  local path
  path="$(plume_services_laradock_context_key "${1:-}" || true)"
  [[ -n "${path}" ]] || return 1
  plume_state_db_desired_services_list "laradock-bridge" "${path}"
}

plume_services_laradock_desired_count() {
  local path
  path="$(plume_services_laradock_context_key "${1:-}" || true)"
  [[ -n "${path}" ]] || {
    printf '%s' "0"
    return 0
  }
  plume_state_db_desired_services_count "laradock-bridge" "${path}"
}

plume_services_laradock_depends_on_direct() {
  local service="$1"
  local compose_file
  compose_file="${PLUME_RUNTIME_LARADOCK_COMPOSE_FILE:-$(plume_services_laradock_resolve_compose_file "$(plume_services_laradock_context_key || true)" || true)}"
  [[ -n "${compose_file}" && -f "${compose_file}" ]] || return 1
  awk -v svc="${service}" '
    BEGIN {
      in_services=0
      target=0
      in_depends=0
      base_indent=-1
      target_indent=-1
      depends_indent=-1
    }
    /^services:/ {
      in_services=1
      next
    }
    in_services == 0 { next }
    /^[^[:space:]#]/ { exit }
    /^[[:space:]]*$/ { next }
    /^[[:space:]]*#/ { next }
    {
      line=$0
      indent=match(line, /[^ ]/) - 1
      if (indent < 0) next
      if (base_indent == -1) base_indent=indent
      if (indent == base_indent) {
        in_depends=0
        depends_indent=-1
        trimmed=line
        sub(/^[[:space:]]+/, "", trimmed)
        current=trimmed
        sub(/:.*/, "", current)
        if (current == svc) {
          target=1
          target_indent=indent
        } else if (target == 1) {
          exit
        }
        next
      }
      if (target != 1) next
      if (indent <= target_indent) exit
      trimmed=line
      sub(/^[[:space:]]+/, "", trimmed)
      if (trimmed ~ /^depends_on:[[:space:]]*$/) {
        in_depends=1
        depends_indent=indent
        next
      }
      if (trimmed ~ /^depends_on:[[:space:]]*\[[^]]*\]/) {
        content=trimmed
        sub(/^depends_on:[[:space:]]*\[/, "", content)
        sub(/\][[:space:]]*$/, "", content)
        gsub(/[[:space:]]+/, "", content)
        n=split(content, parts, ",")
        for (i=1; i<=n; i++) if (parts[i] != "") print parts[i]
        exit
      }
      if (in_depends == 1) {
        if (indent <= depends_indent) {
          in_depends=0
          depends_indent=-1
        } else if (trimmed ~ /^-[[:space:]]+/) {
          dep=trimmed
          sub(/^-[[:space:]]+/, "", dep)
          sub(/[[:space:]]+#.*$/, "", dep)
          sub(/[[:space:]]+$/, "", dep)
          if (dep != "") print dep
          next
        } else if (trimmed ~ /^[A-Za-z0-9_.-]+:[[:space:]]*$/) {
          dep=trimmed
          sub(/:.*/, "", dep)
          if (dep != "") print dep
          next
        }
      }
    }
  ' "${compose_file}" 2>/dev/null | sed '/^$/d'
}

plume_services_laradock_resolved_list() {
  local path queue="" seen="" item dep
  path="$(plume_services_laradock_context_key "${1:-}" || true)"
  [[ -n "${path}" ]] || return 1
  while IFS= read -r item; do
    [[ -z "${item}" ]] && continue
    if [[ ",${seen}," == *",${item},"* ]]; then
      continue
    fi
    seen="${seen:+${seen},}${item}"
    queue="${queue:+${queue}$'\n'}${item}"
  done < <(plume_services_laradock_desired_list "${path}" || true)

  local progress="true"
  while [[ "${progress}" == "true" ]]; do
    progress="false"
    while IFS= read -r item; do
      [[ -z "${item}" ]] && continue
      while IFS= read -r dep; do
        [[ -z "${dep}" ]] && continue
        if [[ ",${seen}," == *",${dep},"* ]]; then
          continue
        fi
        if ! plume_service_exists "${dep}" "laradock-bridge"; then
          continue
        fi
        seen="${seen:+${seen},}${dep}"
        queue="${queue:+${queue}$'\n'}${dep}"
        progress="true"
      done < <(plume_services_laradock_depends_on_direct "${item}" || true)
    done <<< "${queue}"
  done

  [[ -n "${queue}" ]] || return 1
  printf '%s\n' "${queue}" | awk '!seen[$0]++'
}

plume_services_laradock_desired_add_target() {
  local target="$1"
  local path="${2:-}"
  path="$(plume_services_laradock_context_key "${path}" || true)"
  [[ -n "${path}" ]] || return 2
  local group_name mapped emitted="false" service
  group_name="$(plume_services_group_name_from_target "${target}" || true)"
  if [[ -n "${group_name}" ]]; then
    while IFS= read -r service; do
      [[ -z "${service}" ]] && continue
      emitted="true"
      plume_state_db_desired_service_set "laradock-bridge" "${path}" "${service}" "true"
    done < <(plume_services_group_members "${group_name}" "laradock-bridge" || true)
    [[ "${emitted}" == "true" ]] || return 2
    return 0
  fi
  if ! plume_service_exists "${target}" "laradock-bridge"; then
    return 2
  fi
  mapped="$(plume_laradock_bridge_service_name "${target}")"
  plume_state_db_desired_service_set "laradock-bridge" "${path}" "${mapped}" "true"
}

plume_services_laradock_desired_remove_target() {
  local target="$1"
  local path="${2:-}"
  path="$(plume_services_laradock_context_key "${path}" || true)"
  [[ -n "${path}" ]] || return 2
  local group_name mapped emitted="false" service
  group_name="$(plume_services_group_name_from_target "${target}" || true)"
  if [[ -n "${group_name}" ]]; then
    while IFS= read -r service; do
      [[ -z "${service}" ]] && continue
      emitted="true"
      plume_state_db_desired_service_delete "laradock-bridge" "${path}" "${service}"
    done < <(plume_services_group_members "${group_name}" "laradock-bridge" || true)
    [[ "${emitted}" == "true" ]] || return 2
    return 0
  fi
  mapped="$(plume_laradock_bridge_service_name "${target}")"
  plume_state_db_desired_service_delete "laradock-bridge" "${path}" "${mapped}"
}

plume_services_exec_resolve_laradock_service() {
  local target="$1"
  case "${target}" in
    composer) echo "${PLUME_LARADOCK_WORKSPACE_SERVICE:-workspace}" ;;
    php) echo "${PLUME_LARADOCK_PHP_SERVICE:-php-fpm}" ;;
    web) echo "${PLUME_LARADOCK_WEB_SERVICE:-nginx}" ;;
    phpmyadmin) echo "${PLUME_LARADOCK_PHPMYADMIN_SERVICE:-phpmyadmin}" ;;
    supervisor) echo "${PLUME_LARADOCK_SUPERVISOR_SERVICE:-laravel-horizon}" ;;
    horizon) echo "${PLUME_LARADOCK_HORIZON_SERVICE:-laravel-horizon}" ;;
    *) echo "${target}" ;;
  esac
}

cmd_services_exec() {
  local mode
  if ! mode="$(plume_services_parse_mode "$@")"; then
    return 2
  fi
  if [[ "${mode}" == "native" ]]; then
    plume_err "services exec is not supported in native mode"
    return 2
  fi

  local target
  target="$(plume_services_first_positional "$@")"
  if [[ -z "${target}" ]]; then
    plume_err "service name required for exec"
    return 2
  fi

  local default_shell="sh"
  local no_tty="false"
  local after_delim="false"
  local expect_cmd="false"
  local arg
  local target_seen="false"
  local -a exec_args=()
  for arg in "$@"; do
    if [[ "${arg}" == --* && "${arg}" != "--" ]]; then
      # option branch below
      :
    elif [[ "${target_seen}" == "false" ]]; then
      # first positional is target service
      target_seen="true"
      continue
    elif [[ "${after_delim}" == "false" ]]; then
      # shorthand: services exec <service> <cmd> [args...]
      exec_args+=("${arg}")
      continue
    fi
    if [[ "${after_delim}" == "true" ]]; then
      exec_args+=("${arg}")
      continue
    fi
    if [[ "${expect_cmd}" == "true" ]]; then
      default_shell="${arg}"
      expect_cmd="false"
      continue
    fi
    case "${arg}" in
      --)
        after_delim="true"
        ;;
      --cmd=*)
        default_shell="${arg#*=}"
        ;;
      --cmd)
        expect_cmd="true"
        ;;
      --no-tty)
        no_tty="true"
        ;;
    esac
  done
  if [[ "${expect_cmd}" == "true" ]]; then
    plume_err "--cmd requires a value"
    return 2
  fi
  if [[ ${#exec_args[@]} -eq 0 ]]; then
    exec_args=("${default_shell}")
  fi

  local tty_flag=""
  if [[ "${no_tty}" == "true" ]]; then
    tty_flag="-T"
  fi

  local compose_file compose_service target_path
  case "${mode}" in
    docker-lite)
      target_path="$(plume_services_workspace_parse_path "$@" || true)"
      if [[ -n "${target_path}" ]]; then
        if [[ "${target_path}" != /* ]]; then
          target_path="$(cd "${target_path}" 2>/dev/null && pwd || true)"
        fi
        if [[ -z "${target_path}" || ! -d "${target_path}" ]]; then
          plume_err "invalid --path for exec command: ${target_path}"
          return 2
        fi
        compose_file="${target_path}/docker-compose.yml"
        if [[ ! -f "${compose_file}" ]]; then
          compose_file="${target_path}/compose.yml"
        fi
        if [[ ! -f "${compose_file}" ]]; then
          plume_err "no compose file found under ${target_path} (expected docker-compose.yml or compose.yml)"
          return 2
        fi
        PLUME_RUNTIME_DOCKER_LITE_COMPOSE_FILE="${compose_file}"
        plume_workspace_compose_state_set docker-lite "${compose_file}"
      fi
      compose_file="$(plume_docker_lite_compose_file)"
      if [[ -z "${compose_file}" || ! -f "${compose_file}" ]]; then
        plume_err "docker-lite compose file not found (set mode path and run services workspace init)"
        return 2
      fi
      if ! plume_docker_compose_has_v2 && ! plume_docker_compose_has_v1; then
        plume_err "docker compose is required for services exec"
        return 2
      fi
      compose_service="$(plume_docker_lite_service_name "${target}")"
      ;;
    laradock-bridge)
      target_path="$(plume_services_workspace_parse_path "$@" || true)"
      if [[ -n "${target_path}" ]]; then
        if [[ "${target_path}" != /* ]]; then
          target_path="$(cd "${target_path}" 2>/dev/null && pwd || true)"
        fi
      else
        target_path="$(plume_services_laradock_resolve_path "$@" || true)"
      fi
      if ! plume_services_laradock_context_validate "${target_path}" "true" "false"; then
        return 2
      fi
      compose_file="$(plume_services_laradock_resolve_compose_file "${target_path}")"
      compose_service="$(plume_services_exec_resolve_laradock_service "${target}")"
      if ! plume_docker_compose_has_v2 && ! plume_docker_compose_has_v1; then
        plume_err "docker compose is required for services exec"
        return 2
      fi
      ;;
    *)
      plume_err "services exec unsupported mode: ${mode}"
      return 2
      ;;
  esac

  if [[ -n "${tty_flag}" ]]; then
    plume_docker_compose_exec "${compose_file}" exec "${tty_flag}" "${compose_service}" "${exec_args[@]}"
  else
    plume_docker_compose_exec "${compose_file}" exec "${compose_service}" "${exec_args[@]}"
  fi
}

cmd_services_containers() {
  local mode
  if ! mode="$(plume_services_parse_mode "$@")"; then
    return 2
  fi
  if [[ "${mode}" == "native" ]]; then
    plume_err "services containers is supported only for docker-lite|laradock-bridge"
    return 2
  fi
  if ! plume_docker_compose_has_v2 && ! plume_docker_compose_has_v1; then
    plume_err "docker compose is required for services containers"
    return 2
  fi

  local compose_file=""
  local target_path=""
  local target=""
  target="$(plume_services_first_positional "$@")"
  target="${target:-}"

  case "${mode}" in
    docker-lite)
      target_path="$(plume_services_workspace_parse_path "$@" || true)"
      if [[ -n "${target_path}" ]]; then
        if [[ "${target_path}" != /* ]]; then
          target_path="$(cd "${target_path}" 2>/dev/null && pwd || true)"
        fi
        if [[ -z "${target_path}" || ! -d "${target_path}" ]]; then
          plume_err "invalid --path for containers command: ${target_path}"
          return 2
        fi
        compose_file="${target_path}/docker-compose.yml"
        if [[ ! -f "${compose_file}" ]]; then
          compose_file="${target_path}/compose.yml"
        fi
        if [[ ! -f "${compose_file}" ]]; then
          plume_err "no compose file found under ${target_path} (expected docker-compose.yml or compose.yml)"
          return 2
        fi
        PLUME_RUNTIME_DOCKER_LITE_COMPOSE_FILE="${compose_file}"
        plume_workspace_compose_state_set docker-lite "${compose_file}"
      fi
      compose_file="$(plume_docker_lite_compose_file)"
      if [[ -z "${compose_file}" || ! -f "${compose_file}" ]]; then
        plume_err "docker-lite compose file not found (set mode path and run services workspace init)"
        return 2
      fi
      ;;
    laradock-bridge)
      target_path="$(plume_services_workspace_parse_path "$@" || true)"
      if [[ -n "${target_path}" ]]; then
        if [[ "${target_path}" != /* ]]; then
          target_path="$(cd "${target_path}" 2>/dev/null && pwd || true)"
        fi
      else
        target_path="$(plume_services_laradock_resolve_path "$@" || true)"
      fi
      if ! plume_services_laradock_context_validate "${target_path}" "true" "false"; then
        return 2
      fi
      compose_file="$(plume_services_laradock_resolve_compose_file "${target_path}")"
      ;;
    *)
      plume_err "services containers unsupported mode: ${mode}"
      return 2
      ;;
  esac

  if [[ -n "${target}" ]]; then
    plume_docker_compose_exec "${compose_file}" ps "${target}"
  else
    plume_docker_compose_exec "${compose_file}" ps
  fi
}

plume_services_workspace_has_flag() {
  local needle="$1"
  shift
  local arg
  for arg in "$@"; do
    if [[ "${arg}" == "${needle}" ]]; then
      return 0
    fi
  done
  return 1
}

cmd_services_workspace_init() {
  local mode
  if ! mode="$(plume_services_parse_mode "$@")"; then
    return 2
  fi
  if [[ "${mode}" != "docker-lite" ]]; then
    plume_err "workspace init is supported only for --mode=docker-lite"
    return 2
  fi

  local target_path
  target_path="$(plume_services_workspace_parse_path "$@" || true)"
  if [[ -z "${target_path}" ]]; then
    target_path="$(plume_mode_path_get docker-lite || true)"
    if [[ -z "${target_path}" ]]; then
      plume_err "workspace init requires --path=/abs/or/relative/dir (or set mode path: mode path set docker-lite <dir>)"
      return 2
    fi
  fi
  if [[ "${target_path}" != /* ]]; then
    target_path="$(cd "${target_path}" 2>/dev/null && pwd || true)"
  fi
  if [[ -z "${target_path}" || ! -d "${target_path}" ]]; then
    plume_err "invalid path for workspace init: ${target_path}"
    return 2
  fi

  local force="false"
  if plume_services_workspace_has_flag "--force" "$@"; then
    force="true"
  fi

  local compose_target="${target_path}/docker-compose.yml"
  local env_target="${target_path}/.env.docker-lite"
  local nginx_target="${target_path}/conf/nginx.conf"
  local apache_target="${target_path}/conf/apache2.conf"
  local caddy_target="${target_path}/conf/Caddyfile"
  local -a context_dirs=(
    "workspace"
    "php-fpm"
    "nginx"
    "apache2"
    "caddy"
    "mariadb"
    "mysql"
    "phpmyadmin"
    "postgres"
    "redis"
    "laravel-horizon"
  )

  local template_compose="${ROOT_DIR}/templates/docker-lite/docker-compose.template.yml"
  local template_nginx="${ROOT_DIR}/templates/docker-lite/conf/nginx.conf"
  local template_apache="${ROOT_DIR}/templates/docker-lite/conf/apache2.conf"
  local template_caddy="${ROOT_DIR}/templates/docker-lite/conf/Caddyfile"
  local template_base="${ROOT_DIR}/templates/docker-lite"

  if [[ ! -f "${template_compose}" ]]; then
    plume_err "docker-lite template not found: ${template_compose}"
    return 2
  fi

  if [[ -f "${compose_target}" && "${force}" != "true" ]]; then
    plume_err "docker-compose.yml already exists at ${compose_target} (use --force to overwrite)"
    return 2
  fi

  mkdir -p \
    "$(dirname "${nginx_target}")" \
    "$(dirname "${apache_target}")" \
    "$(dirname "${caddy_target}")"

  cp "${template_compose}" "${compose_target}"
  cp "${template_nginx}" "${nginx_target}"
  cp "${template_apache}" "${apache_target}"
  cp "${template_caddy}" "${caddy_target}"
  local ctx
  for ctx in "${context_dirs[@]}"; do
    if [[ -d "${template_base}/${ctx}" ]]; then
      rm -rf "${target_path:?}/${ctx}"
      cp -R "${template_base}/${ctx}" "${target_path}/${ctx}"
    fi
  done

  local default_php_version="${PLUME_PHP_VERSION:-${PLUME_PHP_DEFAULT_VERSION:-8.3}}"
  local normalized_php_versions
  normalized_php_versions="$(plume_php_versions_with_default "${PLUME_PHP_DEFAULT_VERSION:-${default_php_version}}" "${PLUME_PHP_INSTALLED_VERSIONS:-8.1,8.2,8.3}")"
  local default_php_service="php-fpm"

  if [[ ! -f "${env_target}" || "${force}" == "true" ]]; then
    cat > "${env_target}" <<EOF
# Plume docker-lite generated stub
PLUME_PROJECT_NAME=$(basename "${target_path}")
PLUME_APP_ROOT=${target_path}
PLUME_DOCKER_LITE_COMPOSE_REQUIRED=true
PLUME_WEB_SERVER_DRIVER=${PLUME_WEB_SERVER_DRIVER:-nginx}
PLUME_WEB_SERVER_VERSION=${PLUME_WEB_SERVER_VERSION:-stable}
PLUME_WEB_PORT=${PLUME_WEB_PORT:-80}
PLUME_WEB_HTTPS_PORT=${PLUME_WEB_HTTPS_PORT:-443}
PLUME_PHP_VERSION=${default_php_version}
PLUME_PHP_DEFAULT_VERSION=${PLUME_PHP_DEFAULT_VERSION:-${default_php_version}}
PLUME_PHP_INSTALLED_VERSIONS=${normalized_php_versions}
PLUME_COMPOSER_VERSION=${PLUME_COMPOSER_VERSION:-2}
WORKSPACE_USER=${WORKSPACE_USER:-plume}
WORKSPACE_PUID=${WORKSPACE_PUID:-1000}
WORKSPACE_PGID=${WORKSPACE_PGID:-1000}
WORKSPACE_TIMEZONE=${WORKSPACE_TIMEZONE:-UTC}
WORKSPACE_INSTALL_ZSH=${WORKSPACE_INSTALL_ZSH:-false}
WORKSPACE_INSTALL_OH_MY_ZSH=${WORKSPACE_INSTALL_OH_MY_ZSH:-false}
WORKSPACE_INSTALL_NODE=${WORKSPACE_INSTALL_NODE:-false}
WORKSPACE_NODE_VERSION=${WORKSPACE_NODE_VERSION:-20}
WORKSPACE_NPM_REGISTRY=${WORKSPACE_NPM_REGISTRY:-}
WORKSPACE_NVM_NODEJS_ORG_MIRROR=${WORKSPACE_NVM_NODEJS_ORG_MIRROR:-}
PLUME_MARIADB_VERSION=${PLUME_MARIADB_VERSION:-11.0}
PLUME_MYSQL_VERSION=${PLUME_MYSQL_VERSION:-8.0}
PLUME_PHPMYADMIN_VERSION=${PLUME_PHPMYADMIN_VERSION:-latest}
PLUME_POSTGRES_VERSION=${PLUME_POSTGRES_VERSION:-16}
PLUME_REDIS_VERSION=${PLUME_REDIS_VERSION:-7}
PLUME_DOCKER_LITE_PHPMYADMIN_IMAGE=${PLUME_DOCKER_LITE_PHPMYADMIN_IMAGE:-phpmyadmin/phpmyadmin:${PLUME_PHPMYADMIN_VERSION:-latest}}
MYSQL_ALLOW_EMPTY_PASSWORD=${MYSQL_ALLOW_EMPTY_PASSWORD:-no}
MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD:-${PLUME_DB_ROOT_PASSWORD:-root}}
MYSQL_DATABASE=${MYSQL_DATABASE:-${PLUME_DB_DATABASE:-plume}}
MYSQL_USER=${MYSQL_USER:-${PLUME_DB_USERNAME:-plume}}
MYSQL_PASSWORD=${MYSQL_PASSWORD:-${PLUME_DB_PASSWORD:-plume}}
MYSQL_TIMEZONE=${MYSQL_TIMEZONE:-${WORKSPACE_TIMEZONE:-UTC}}
MARIADB_ROOT_PASSWORD=${MARIADB_ROOT_PASSWORD:-${PLUME_DB_ROOT_PASSWORD:-root}}
MARIADB_DATABASE=${MARIADB_DATABASE:-${PLUME_DB_DATABASE:-plume}}
MARIADB_USER=${MARIADB_USER:-${PLUME_DB_USERNAME:-plume}}
MARIADB_PASSWORD=${MARIADB_PASSWORD:-${PLUME_DB_PASSWORD:-plume}}
MARIADB_TIMEZONE=${MARIADB_TIMEZONE:-${WORKSPACE_TIMEZONE:-UTC}}
PMA_DB_ENGINE=${PMA_DB_ENGINE:-mariadb}
PMA_USER=${PMA_USER:-default}
PMA_PASSWORD=${PMA_PASSWORD:-secret}
PMA_ROOT_PASSWORD=${PMA_ROOT_PASSWORD:-secret}
PMA_ARBITRARY=${PMA_ARBITRARY:-1}
PMA_DB_PORT=${PMA_DB_PORT:-3306}
PMA_ABSOLUTE_URI=${PMA_ABSOLUTE_URI:-}
PMA_PORT=${PMA_PORT:-8081}
PMA_MAX_EXECUTION_TIME=${PMA_MAX_EXECUTION_TIME:-600}
PMA_MEMORY_LIMIT=${PMA_MEMORY_LIMIT:-256M}
PMA_UPLOAD_LIMIT=${PMA_UPLOAD_LIMIT:-2G}
PLUME_DOCKER_LITE_NGINX_CONF=./conf/nginx.conf
PLUME_DOCKER_LITE_APACHE_CONF=./conf/apache2.conf
PLUME_DOCKER_LITE_CADDYFILE=./conf/Caddyfile
PLUME_DOCKER_LITE_PHP_SERVICE=php-fpm
EOF
  fi

  plume_workspace_compose_state_set docker-lite "${compose_target}"
  plume_mode_path_set docker-lite "${target_path}"

  if [[ "${PLUME_OUTPUT:-text}" == "json" ]]; then
    printf '{"ok":true,"command":"services workspace init","data":{"path":"%s","compose":"%s","env":"%s","default_php_version":"%s","default_php_service":"%s"},"warnings":[],"errors":[]}\n' \
      "${target_path}" "${compose_target}" "${env_target}" "${default_php_version}" "${default_php_service}"
    return 0
  fi

  plume_info "docker-lite stub generated at ${target_path}"
  plume_info "compose file: ${compose_target}"
  plume_info "env stub: ${env_target}"
  plume_info "next: ./plume.sh services workspace up --mode=docker-lite"
}

cmd_services_workspace_reinit() {
  local mode
  if ! mode="$(plume_services_parse_mode "$@")"; then
    return 2
  fi
  if [[ "${mode}" != "docker-lite" ]]; then
    plume_err "workspace reinit is supported only for --mode=docker-lite"
    return 2
  fi
  if ! plume_require_yes_for_critical "${mode}" "critical.workspace.reinit" "mode=${mode}" "Use --yes services workspace reinit --mode=docker-lite"; then
    return 2
  fi

  local target_path
  target_path="$(plume_services_workspace_parse_path "$@" || true)"
  if [[ -z "${target_path}" ]]; then
    target_path="$(plume_mode_path_get docker-lite || true)"
    if [[ -z "${target_path}" ]]; then
      plume_err "workspace reinit requires --path=/abs/or/relative/dir (or set mode path: mode path set docker-lite <dir>)"
      return 2
    fi
  fi
  if [[ "${target_path}" != /* ]]; then
    target_path="$(cd "${target_path}" 2>/dev/null && pwd || true)"
  fi
  if [[ -z "${target_path}" || ! -d "${target_path}" ]]; then
    plume_err "invalid path for workspace reinit: ${target_path}"
    return 2
  fi

  local compose_file=""
  if [[ -f "${target_path}/docker-compose.yml" ]]; then
    compose_file="${target_path}/docker-compose.yml"
  elif [[ -f "${target_path}/compose.yml" ]]; then
    compose_file="${target_path}/compose.yml"
  fi

  if [[ -n "${compose_file}" ]] && (plume_docker_compose_has_v2 || plume_docker_compose_has_v1); then
    plume_docker_compose_exec "${compose_file}" down --remove-orphans || true
  fi

  rm -f "${target_path}/docker-compose.yml" "${target_path}/compose.yml" "${target_path}/.env.docker-lite"
  rm -rf "${target_path}/conf"
  rm -rf \
    "${target_path}/workspace" \
    "${target_path}/php-fpm" \
    "${target_path}/nginx" \
    "${target_path}/apache2" \
    "${target_path}/caddy" \
    "${target_path}/mariadb" \
    "${target_path}/mysql" \
    "${target_path}/phpmyadmin" \
    "${target_path}/postgres" \
    "${target_path}/redis" \
    "${target_path}/laravel-horizon"

  cmd_services_workspace_init --mode=docker-lite --path="${target_path}" --force
}

plume_services_workspace_path_key() {
  local target_path="$1"
  printf '%s' "${target_path}" | tr '/: ' '___'
}

plume_services_workspace_snapshot_file() {
  local target_path="$1"
  printf '%s' "$(plume_state_dir)/workspace_snapshot_docker-lite_$(plume_services_workspace_path_key "${target_path}").env"
}

plume_services_sha256() {
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 | awk '{print $1}'
    return 0
  fi
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum | awk '{print $1}'
    return 0
  fi
  cat >/dev/null
  printf '%s\n' "nohash"
}

plume_services_hash_files() {
  local base="$1"
  shift || true
  local files=("$@")
  if [[ ${#files[@]} -eq 0 ]]; then
    printf '%s\n' ""
    return 0
  fi
  local f
  {
    for f in "${files[@]}"; do
      [[ -f "${f}" ]] || continue
      local rel
      rel="${f#${base}/}"
      printf '%s\n' "${rel}"
      cat "${f}"
      printf '\n'
    done
  } | plume_services_sha256
}

plume_services_workspace_collect_context_files() {
  local target_path="$1"
  find "${target_path}" \
    \( -path "${target_path}/workspace/*" -o \
       -path "${target_path}/php-fpm/*" -o \
       -path "${target_path}/nginx/*" -o \
       -path "${target_path}/apache2/*" -o \
       -path "${target_path}/caddy/*" -o \
       -path "${target_path}/mariadb/*" -o \
       -path "${target_path}/mysql/*" -o \
       -path "${target_path}/phpmyadmin/*" -o \
       -path "${target_path}/postgres/*" -o \
       -path "${target_path}/redis/*" -o \
       -path "${target_path}/laravel-horizon/*" \) \
    -type f 2>/dev/null | sort
}

plume_services_workspace_collect_config_files() {
  local target_path="$1"
  find "${target_path}" \
    \( -path "${target_path}/docker-compose.yml" -o \
       -path "${target_path}/compose.yml" -o \
       -path "${target_path}/.env.docker-lite" -o \
       -path "${target_path}/conf/*" \) \
    -type f 2>/dev/null | sort
}

plume_services_workspace_build_env_hash() {
  local env_file="$1"
  [[ -f "${env_file}" ]] || {
    printf '%s\n' ""
    return 0
  }
  (
    grep -E '^(WORKSPACE_.*|PLUME_PHP_.*|PLUME_COMPOSER_VERSION|PLUME_WEB_SERVER_VERSION|PLUME_MARIADB_VERSION|PLUME_MYSQL_VERSION|PLUME_POSTGRES_VERSION|PLUME_REDIS_VERSION|PLUME_PHPMYADMIN_VERSION|PLUME_DOCKER_LITE_.*_IMAGE)=' "${env_file}" || true
  ) | LC_ALL=C sort | plume_services_sha256
}

plume_services_workspace_snapshot_get() {
  local file="$1"
  local key="$2"
  [[ -f "${file}" ]] || return 1
  local line
  line="$(grep -E "^${key}=" "${file}" || true)"
  [[ -n "${line}" ]] || return 1
  printf '%s' "${line#*=}"
}

plume_services_workspace_snapshot_set() {
  local file="$1"
  local config_hash="$2"
  local context_hash="$3"
  local build_env_hash="$4"
  mkdir -p "$(dirname "${file}")"
  cat > "${file}" <<EOF
config_hash=${config_hash}
context_hash=${context_hash}
build_env_hash=${build_env_hash}
updated_at=$(date '+%Y-%m-%d %H:%M:%S')
EOF
}

cmd_services_workspace_apply() {
  local mode
  if ! mode="$(plume_services_parse_mode "$@")"; then
    return 2
  fi
  if [[ "${mode}" != "docker-lite" ]]; then
    plume_err "workspace apply is supported only for --mode=docker-lite"
    return 2
  fi

  local target_path
  target_path="$(plume_services_workspace_parse_path "$@" || true)"
  if [[ -z "${target_path}" ]]; then
    target_path="$(plume_mode_path_get docker-lite || true)"
    if [[ -z "${target_path}" ]]; then
      plume_err "workspace apply requires --path=/abs/or/relative/dir (or set mode path: mode path set docker-lite <dir>)"
      return 2
    fi
  fi
  if [[ "${target_path}" != /* ]]; then
    target_path="$(cd "${target_path}" 2>/dev/null && pwd || true)"
  fi
  if [[ -z "${target_path}" || ! -d "${target_path}" ]]; then
    plume_err "invalid path for workspace apply: ${target_path}"
    return 2
  fi

  local compose_file=""
  if [[ -f "${target_path}/docker-compose.yml" ]]; then
    compose_file="${target_path}/docker-compose.yml"
  elif [[ -f "${target_path}/compose.yml" ]]; then
    compose_file="${target_path}/compose.yml"
  fi
  if [[ -z "${compose_file}" || ! -f "${compose_file}" ]]; then
    plume_err "no compose file found under ${target_path} (expected docker-compose.yml or compose.yml)"
    return 2
  fi
  if ! plume_docker_compose_has_v2 && ! plume_docker_compose_has_v1; then
    plume_err "docker compose is required for workspace apply"
    return 2
  fi

  local -a profile_args=()
  local arg next_is_profile="false"
  for arg in "$@"; do
    if [[ "${next_is_profile}" == "true" ]]; then
      profile_args+=(--profile "${arg}")
      next_is_profile="false"
      continue
    fi
    case "${arg}" in
      --profile=*) profile_args+=(--profile "${arg#*=}") ;;
      --profile) next_is_profile="true" ;;
    esac
  done
  if [[ "${next_is_profile}" == "true" ]]; then
    plume_err "--profile requires a value"
    return 2
  fi
  if [[ ${#profile_args[@]} -eq 0 ]]; then
    while IFS= read -r arg; do
      [[ -n "${arg}" ]] && profile_args+=(--profile "${arg}")
    done < <(plume_services_workspace_default_profiles)
  fi
  local -a up_targets=()
  local t
  while IFS= read -r t; do
    [[ -n "${t}" ]] && up_targets+=("${t}")
  done < <(plume_services_workspace_extra_targets "${compose_file}")
  export "PLUME_PHP_VERSION=${PLUME_PHP_DEFAULT_VERSION:-${PLUME_PHP_VERSION:-8.3}}"
  export "PLUME_PHP_INSTALLED_VERSIONS=$(plume_php_versions_with_default "${PLUME_PHP_DEFAULT_VERSION:-${PLUME_PHP_VERSION:-8.3}}" "${PLUME_PHP_INSTALLED_VERSIONS:-8.1,8.2,8.3}")"

  local config_hash context_hash build_env_hash env_file
  local -a _cfg_files=()
  local -a _ctx_files=()
  local _f
  env_file="${target_path}/.env.docker-lite"
  while IFS= read -r _f; do
    [[ -n "${_f}" ]] && _cfg_files+=("${_f}")
  done < <(plume_services_workspace_collect_config_files "${target_path}")
  while IFS= read -r _f; do
    [[ -n "${_f}" ]] && _ctx_files+=("${_f}")
  done < <(plume_services_workspace_collect_context_files "${target_path}")
  config_hash="$(plume_services_hash_files "${target_path}" ${_cfg_files[@]+"${_cfg_files[@]}"})"
  context_hash="$(plume_services_hash_files "${target_path}" ${_ctx_files[@]+"${_ctx_files[@]}"})"
  build_env_hash="$(plume_services_workspace_build_env_hash "${env_file}")"

  local snapshot_file old_config old_context old_build_env
  snapshot_file="$(plume_services_workspace_snapshot_file "${target_path}")"
  old_config="$(plume_services_workspace_snapshot_get "${snapshot_file}" config_hash || true)"
  old_context="$(plume_services_workspace_snapshot_get "${snapshot_file}" context_hash || true)"
  old_build_env="$(plume_services_workspace_snapshot_get "${snapshot_file}" build_env_hash || true)"

  local running_ids running="false"
  running_ids="$(plume_docker_compose_exec "${compose_file}" ps -q 2>/dev/null || true)"
  [[ -n "${running_ids}" ]] && running="true"

  local action="noop"
  if [[ -z "${old_config}" && -z "${old_context}" && -z "${old_build_env}" ]]; then
    if [[ "${running}" == "true" ]]; then
      action="recreate"
    else
      action="up"
    fi
  elif [[ "${context_hash}" != "${old_context}" || "${build_env_hash}" != "${old_build_env}" ]]; then
    action="build"
  elif [[ "${config_hash}" != "${old_config}" ]]; then
    action="recreate"
  elif [[ "${running}" != "true" ]]; then
    action="up"
  fi

  case "${action}" in
    build)
      plume_info "workspace apply: detected build-impacting changes -> up -d --force-recreate --build"
      plume_docker_compose_exec "${compose_file}" "${profile_args[@]}" up -d --force-recreate --build ${up_targets[@]+"${up_targets[@]}"} || return 2
      ;;
    recreate)
      plume_info "workspace apply: detected config changes -> up -d --force-recreate"
      plume_docker_compose_exec "${compose_file}" "${profile_args[@]}" up -d --force-recreate ${up_targets[@]+"${up_targets[@]}"} || return 2
      ;;
    up)
      plume_info "workspace apply: containers are down -> up -d"
      plume_docker_compose_exec "${compose_file}" "${profile_args[@]}" up -d ${up_targets[@]+"${up_targets[@]}"} || return 2
      ;;
    noop)
      plume_info "workspace apply: no changes detected; nothing to do"
      ;;
  esac

  if ! plume_services_workspace_reconcile_php_matrix "${compose_file}" "${action}"; then
    plume_err "workspace apply: php-fpm matrix reconcile failed"
    return 2
  fi
  if ! plume_services_workspace_reconcile_web_driver "${compose_file}" "${profile_args[@]}"; then
    plume_err "workspace apply: web driver reconcile failed"
    return 2
  fi

  plume_services_workspace_snapshot_set "${snapshot_file}" "${config_hash}" "${context_hash}" "${build_env_hash}"
  plume_workspace_compose_state_set docker-lite "${compose_file}"
  plume_mode_path_set docker-lite "${target_path}"
  plume_context_lock_activate "services workspace apply" "docker-lite" "${target_path}"
}

plume_services_workspace_suggest_images() {
  local image="$1"
  local repo="${image%%:*}"
  [[ -n "${repo}" ]] || return 0

  if ! command -v docker >/dev/null 2>&1; then
    return 0
  fi

  local results
  results="$(docker search --limit 5 "${repo}" 2>/dev/null | awk 'NR>1 {print $1}' | head -n 5 || true)"
  if [[ -n "${results}" ]]; then
    plume_warn "similar images for '${image}':"
    local candidate
    while IFS= read -r candidate; do
      [[ -n "${candidate}" ]] && plume_warn " - ${candidate}"
    done <<< "${results}"
  fi

  if [[ "${image}" == *:* ]]; then
    plume_warn "try default tag as fallback: ${repo}:latest"
  fi
}

plume_services_workspace_preflight_images() {
  local compose_file="$1"
  shift || true
  local images
  images="$(plume_services_workspace_collect_images "${compose_file}" "$@" || true)"
  if [[ -z "${images}" ]]; then
    plume_warn "could not resolve compose images; skipping image preflight"
    return 0
  fi

  local img
  while IFS= read -r img; do
    [[ -z "${img}" ]] && continue
    if docker image inspect "${img}" >/dev/null 2>&1; then
      plume_info "docker-lite preflight image found: ${img}"
      continue
    fi
    plume_warn "docker-lite preflight image missing: ${img}; pulling"
    if ! docker pull "${img}" >/dev/null 2>&1; then
      plume_err "docker-lite preflight pull failed: ${img}"
      plume_services_workspace_suggest_images "${img}"
      return 2
    fi
  done <<< "${images}"
}

plume_services_workspace_selected_web_service() {
  case "${PLUME_WEB_SERVER_DRIVER:-nginx}" in
    apache2) printf '%s' "apache2" ;;
    caddy) printf '%s' "caddy" ;;
    nginx|*) printf '%s' "nginx" ;;
  esac
}

plume_services_workspace_default_profiles() {
  local web
  web="$(plume_services_workspace_selected_web_service)"
  printf '%s\n' "core"
  printf '%s\n' "web-${web}"
}

plume_services_workspace_reconcile_web_driver() {
  local compose_file="$1"
  shift || true
  local -a compose_args=("$@")
  local selected web
  selected="$(plume_services_workspace_selected_web_service)"

  for web in nginx apache2 caddy; do
    plume_services_compose_has_service "${compose_file}" "${web}" || continue
    if [[ "${web}" == "${selected}" ]]; then
      plume_docker_compose_exec "${compose_file}" "${compose_args[@]}" up -d "${web}" || return 2
    else
      plume_docker_compose_exec "${compose_file}" "${compose_args[@]}" rm -f -s "${web}" || true
    fi
  done
}

plume_services_workspace_extra_targets() {
  local compose_file="$1"
  local selected target
  selected="$(plume_services_workspace_selected_web_service)"
  if [[ "${selected}" == "nginx" ]]; then
    return 0
  fi
  for target in workspace php-fpm mariadb "${selected}"; do
    if plume_services_compose_has_service "${compose_file}" "${target}"; then
      printf '%s\n' "${target}"
    fi
  done
}

plume_services_compose_has_service() {
  local compose_file="$1"
  local service="$2"
  [[ -f "${compose_file}" ]] || return 1
  grep -Eq "^[[:space:]]{2}${service}:[[:space:]]*" "${compose_file}"
}

plume_services_workspace_compose_php_services() {
  local compose_file="$1"
  [[ -f "${compose_file}" ]] || return 0
  awk '
    /^[[:space:]]{2}php-fpm:[[:space:]]*$/ {print "php-fpm"}
    /^[[:space:]]{2}php[0-9]+-fpm:[[:space:]]*$/ {
      gsub(/^[[:space:]]{2}/, "", $0)
      gsub(/:[[:space:]]*$/, "", $0)
      print $0
    }
  ' "${compose_file}"
}

plume_services_workspace_desired_php_services() {
  local default_v installed_csv merged item normalized compact
  default_v="${PLUME_PHP_DEFAULT_VERSION:-${PLUME_PHP_VERSION:-8.3}}"
  installed_csv="$(plume_php_versions_with_default "${default_v}" "${PLUME_PHP_INSTALLED_VERSIONS:-8.1,8.2,8.3}")"
  merged="${installed_csv},${default_v}"

  printf '%s\n' "php-fpm"
  local -a versions=()
  IFS=',' read -r -a versions <<< "${merged}"
  for item in "${versions[@]-}"; do
    normalized="$(printf '%s' "${item}" | tr -d '[:space:]')"
    [[ -z "${normalized}" ]] && continue
    [[ "${normalized}" == "${default_v}" ]] && continue
    compact="$(printf '%s' "${normalized}" | tr -d '.')"
    [[ -z "${compact}" ]] && continue
    printf 'php%s-fpm\n' "${compact}"
  done | awk '!seen[$0]++'
}

plume_services_workspace_reconcile_php_matrix() {
  local compose_file="$1"
  local action="${2:-up}"

  local -a desired=()
  local -a existing=()
  local -a desired_existing=()
  local -a obsolete=()
  local svc

  while IFS= read -r svc; do
    [[ -n "${svc}" ]] && desired+=("${svc}")
  done < <(plume_services_workspace_desired_php_services)

  while IFS= read -r svc; do
    [[ -n "${svc}" ]] && existing+=("${svc}")
  done < <(plume_services_workspace_compose_php_services "${compose_file}")

  for svc in ${desired[@]+"${desired[@]}"}; do
    if plume_services_compose_has_service "${compose_file}" "${svc}"; then
      desired_existing+=("${svc}")
    fi
  done

  for svc in ${existing[@]+"${existing[@]}"}; do
    if [[ " ${desired_existing[*]-} " != *" ${svc} "* ]]; then
      obsolete+=("${svc}")
    fi
  done

  local desired_count=0
  for svc in ${desired_existing[@]+"${desired_existing[@]}"}; do
    ((desired_count += 1))
  done

  if [[ ${desired_count} -gt 0 ]]; then
    plume_info "docker-lite php matrix desired: ${desired_existing[*]-}"
    case "${action}" in
      build)
        plume_docker_compose_exec "${compose_file}" up -d --force-recreate --build ${desired_existing[@]+"${desired_existing[@]}"} || return 2
        ;;
      recreate)
        plume_docker_compose_exec "${compose_file}" up -d --force-recreate ${desired_existing[@]+"${desired_existing[@]}"} || return 2
        ;;
      up|noop|*)
        plume_docker_compose_exec "${compose_file}" up -d ${desired_existing[@]+"${desired_existing[@]}"} || return 2
        ;;
    esac
  fi

  local obsolete_count=0
  for svc in ${obsolete[@]+"${obsolete[@]}"}; do
    ((obsolete_count += 1))
  done

  if [[ ${obsolete_count} -gt 0 ]]; then
    plume_info "docker-lite php matrix obsolete: ${obsolete[*]-}"
    plume_docker_compose_exec "${compose_file}" rm -f -s ${obsolete[@]+"${obsolete[@]}"} || true
  fi
}

plume_services_workspace_mark_all_stopped() {
  local mode="${1:-docker-lite}"
  local service
  while IFS= read -r service; do
    [[ -z "${service}" ]] && continue
    plume_services_runtime_set "${service}" "running" "false" "${mode}"
  done < <(plume_service_names_for_mode "${mode}")
}

cmd_services_workspace() {
  local action="${1:-status}"
  shift || true

  local mode
  if ! mode="$(plume_services_parse_mode "$@")"; then
    return 2
  fi

  if [[ "${mode}" != "docker-lite" ]]; then
    plume_err "workspace command is currently supported only for --mode=docker-lite"
    return 2
  fi

  if [[ "${action}" == "init" ]]; then
    cmd_services_workspace_init --mode="${mode}" "$@"
    return $?
  fi
  if [[ "${action}" == "reinit" ]]; then
    cmd_services_workspace_reinit --mode="${mode}" "$@"
    return $?
  fi
  if [[ "${action}" == "apply" ]]; then
    cmd_services_workspace_apply --mode="${mode}" "$@"
    return $?
  fi

  local target_path compose_file explicit_path="false"
  target_path="$(plume_services_workspace_parse_path "$@" || true)"
  if [[ -n "${target_path}" ]]; then
    explicit_path="true"
  else
    target_path="$(plume_mode_path_get docker-lite || true)"
  fi
  if [[ -n "${target_path}" ]]; then
    if [[ "${target_path}" != /* ]]; then
      target_path="$(cd "${target_path}" 2>/dev/null && pwd || true)"
    fi
    if [[ -z "${target_path}" || ! -d "${target_path}" ]]; then
      if [[ "${explicit_path}" == "true" ]]; then
        plume_err "invalid --path for workspace command: ${target_path}"
        return 2
      fi
      plume_mode_path_clear docker-lite
      target_path=""
    fi
  fi
  if [[ -n "${target_path}" ]]; then
    compose_file="${target_path}/docker-compose.yml"
    if [[ ! -f "${compose_file}" ]]; then
      compose_file="${target_path}/compose.yml"
    fi
    if [[ ! -f "${compose_file}" ]]; then
      if [[ "${explicit_path}" == "true" ]]; then
        plume_err "no compose file found under ${target_path} (expected docker-compose.yml or compose.yml)"
        return 2
      fi
      plume_mode_path_clear docker-lite
      target_path=""
      compose_file=""
    fi
    if [[ -n "${compose_file}" ]]; then
      PLUME_RUNTIME_DOCKER_LITE_COMPOSE_FILE="${compose_file}"
    fi
  fi

  compose_file="$(plume_docker_lite_compose_exec_required)" || return 2
  plume_workspace_compose_state_set docker-lite "${compose_file}"
  if [[ -n "${target_path}" ]]; then
    plume_mode_path_set docker-lite "${target_path}"
  fi

  local -a profile_args=()
  local arg next_is_profile="false"
  for arg in "$@"; do
    if [[ "${next_is_profile}" == "true" ]]; then
      profile_args+=(--profile "${arg}")
      next_is_profile="false"
      continue
    fi
    case "${arg}" in
      --profile=*)
        profile_args+=(--profile "${arg#*=}")
        ;;
      --profile)
        next_is_profile="true"
        ;;
    esac
  done
  if [[ "${next_is_profile}" == "true" ]]; then
    plume_err "--profile requires a value"
    return 2
  fi
  if [[ ${#profile_args[@]} -eq 0 ]]; then
    # Profile-driven template'de no service selected hatasini engelle.
    while IFS= read -r arg; do
      [[ -n "${arg}" ]] && profile_args+=(--profile "${arg}")
    done < <(plume_services_workspace_default_profiles)
  fi
  local -a up_targets=()
  local t
  while IFS= read -r t; do
    [[ -n "${t}" ]] && up_targets+=("${t}")
  done < <(plume_services_workspace_extra_targets "${compose_file}")
  export "PLUME_PHP_VERSION=${PLUME_PHP_DEFAULT_VERSION:-${PLUME_PHP_VERSION:-8.3}}"
  export "PLUME_PHP_INSTALLED_VERSIONS=$(plume_php_versions_with_default "${PLUME_PHP_DEFAULT_VERSION:-${PLUME_PHP_VERSION:-8.3}}" "${PLUME_PHP_INSTALLED_VERSIONS:-8.1,8.2,8.3}")"

  case "${action}" in
    up|refresh|rebuild)
      local force_recreate_build="false"
      if [[ "${action}" == "refresh" || "${action}" == "rebuild" ]]; then
        force_recreate_build="true"
      fi
      local workspace_root snapshot_file env_file current_build_env_hash old_build_env_hash
      workspace_root="$(dirname "${compose_file}")"
      snapshot_file="$(plume_services_workspace_snapshot_file "${workspace_root}")"
      env_file="${workspace_root}/.env.docker-lite"
      current_build_env_hash="$(plume_services_workspace_build_env_hash "${env_file}")"
      old_build_env_hash="$(plume_services_workspace_snapshot_get "${snapshot_file}" build_env_hash || true)"
      if [[ "${action}" == "up" && -n "${old_build_env_hash}" && "${current_build_env_hash}" != "${old_build_env_hash}" ]]; then
        force_recreate_build="true"
        plume_info "workspace up: detected php/workspace env change -> up -d --force-recreate --build"
      fi
      local allocated_web_port="" allocated_web_https_port="" web_port_env_key="" web_https_port_env_key=""
      local had_web_port_env="false" old_web_port_env=""
      local had_web_https_port_env="false" old_web_https_port_env=""
      local had_global_web_port="false" old_global_web_port=""
      local had_global_web_https_port="false" old_global_web_https_port=""
      if [[ "$(plume_service_enabled web)" == "true" ]]; then
        allocated_web_port="$(plume_docker_lite_resolve_port "web" "" "web" "$(plume_service_default_port web)")" || return 2
        allocated_web_https_port="$(plume_docker_lite_resolve_port "web" "443" "web_https" "$(plume_service_default_https_port web)")" || return 2
        if [[ -n "${allocated_web_port}" ]]; then
          plume_services_ports_set web "${allocated_web_port}" docker-lite
          web_port_env_key="$(plume_docker_lite_port_env_key web)"
          if [[ -n "${web_port_env_key}" ]]; then
            if [[ -n "${!web_port_env_key+x}" ]]; then
              had_web_port_env="true"
              old_web_port_env="${!web_port_env_key}"
            fi
            export "${web_port_env_key}=${allocated_web_port}"
          fi
          if [[ -n "${PLUME_WEB_PORT+x}" ]]; then
            had_global_web_port="true"
            old_global_web_port="${PLUME_WEB_PORT}"
          fi
          export "PLUME_WEB_PORT=${allocated_web_port}"
        fi
        if [[ -n "${allocated_web_https_port}" ]]; then
          plume_services_ports_set web_https "${allocated_web_https_port}" docker-lite
          web_https_port_env_key="$(plume_docker_lite_web_https_port_env_key)"
          if [[ -n "${web_https_port_env_key}" ]]; then
            if [[ -n "${!web_https_port_env_key+x}" ]]; then
              had_web_https_port_env="true"
              old_web_https_port_env="${!web_https_port_env_key}"
            fi
            export "${web_https_port_env_key}=${allocated_web_https_port}"
          fi
          if [[ -n "${PLUME_WEB_HTTPS_PORT+x}" ]]; then
            had_global_web_https_port="true"
            old_global_web_https_port="${PLUME_WEB_HTTPS_PORT}"
          fi
          export "PLUME_WEB_HTTPS_PORT=${allocated_web_https_port}"
        fi
      fi

      if ! plume_services_workspace_preflight_images "${compose_file}" "${profile_args[@]}"; then
        if [[ "${had_web_port_env}" == "true" ]]; then
          export "${web_port_env_key}=${old_web_port_env}"
        elif [[ -n "${web_port_env_key}" ]]; then
          unset "${web_port_env_key}" || true
        fi
        if [[ "${had_global_web_port}" == "true" ]]; then
          export "PLUME_WEB_PORT=${old_global_web_port}"
        elif [[ -n "${allocated_web_port}" ]]; then
          unset PLUME_WEB_PORT || true
        fi
        if [[ "${had_web_https_port_env}" == "true" ]]; then
          export "${web_https_port_env_key}=${old_web_https_port_env}"
        elif [[ -n "${web_https_port_env_key}" ]]; then
          unset "${web_https_port_env_key}" || true
        fi
        if [[ "${had_global_web_https_port}" == "true" ]]; then
          export "PLUME_WEB_HTTPS_PORT=${old_global_web_https_port}"
        elif [[ -n "${allocated_web_https_port}" ]]; then
          unset PLUME_WEB_HTTPS_PORT || true
        fi
        return 2
      fi
      if [[ "${force_recreate_build}" == "true" ]]; then
        plume_docker_compose_exec "${compose_file}" "${profile_args[@]}" up -d --force-recreate --build ${up_targets[@]+"${up_targets[@]}"} || {
          if [[ "${had_web_port_env}" == "true" ]]; then
            export "${web_port_env_key}=${old_web_port_env}"
          elif [[ -n "${web_port_env_key}" ]]; then
            unset "${web_port_env_key}" || true
          fi
          if [[ "${had_global_web_port}" == "true" ]]; then
            export "PLUME_WEB_PORT=${old_global_web_port}"
          elif [[ -n "${allocated_web_port}" ]]; then
            unset PLUME_WEB_PORT || true
          fi
          if [[ "${had_web_https_port_env}" == "true" ]]; then
            export "${web_https_port_env_key}=${old_web_https_port_env}"
          elif [[ -n "${web_https_port_env_key}" ]]; then
            unset "${web_https_port_env_key}" || true
          fi
          if [[ "${had_global_web_https_port}" == "true" ]]; then
            export "PLUME_WEB_HTTPS_PORT=${old_global_web_https_port}"
          elif [[ -n "${allocated_web_https_port}" ]]; then
            unset PLUME_WEB_HTTPS_PORT || true
          fi
          return 2
        }
      else
        plume_docker_compose_exec "${compose_file}" "${profile_args[@]}" up -d ${up_targets[@]+"${up_targets[@]}"} || {
          if [[ "${had_web_port_env}" == "true" ]]; then
            export "${web_port_env_key}=${old_web_port_env}"
          elif [[ -n "${web_port_env_key}" ]]; then
            unset "${web_port_env_key}" || true
          fi
          if [[ "${had_global_web_port}" == "true" ]]; then
            export "PLUME_WEB_PORT=${old_global_web_port}"
          elif [[ -n "${allocated_web_port}" ]]; then
            unset PLUME_WEB_PORT || true
          fi
          if [[ "${had_web_https_port_env}" == "true" ]]; then
            export "${web_https_port_env_key}=${old_web_https_port_env}"
          elif [[ -n "${web_https_port_env_key}" ]]; then
            unset "${web_https_port_env_key}" || true
          fi
          if [[ "${had_global_web_https_port}" == "true" ]]; then
            export "PLUME_WEB_HTTPS_PORT=${old_global_web_https_port}"
          elif [[ -n "${allocated_web_https_port}" ]]; then
            unset PLUME_WEB_HTTPS_PORT || true
          fi
          return 2
        }
      fi

      local php_reconcile_action="up"
      if [[ "${force_recreate_build}" == "true" ]]; then
        php_reconcile_action="build"
      fi
      if ! plume_services_workspace_reconcile_php_matrix "${compose_file}" "${php_reconcile_action}"; then
        if [[ "${had_web_port_env}" == "true" ]]; then
          export "${web_port_env_key}=${old_web_port_env}"
        elif [[ -n "${web_port_env_key}" ]]; then
          unset "${web_port_env_key}" || true
        fi
        if [[ "${had_global_web_port}" == "true" ]]; then
          export "PLUME_WEB_PORT=${old_global_web_port}"
        elif [[ -n "${allocated_web_port}" ]]; then
          unset PLUME_WEB_PORT || true
        fi
        if [[ "${had_web_https_port_env}" == "true" ]]; then
          export "${web_https_port_env_key}=${old_web_https_port_env}"
        elif [[ -n "${web_https_port_env_key}" ]]; then
          unset "${web_https_port_env_key}" || true
        fi
        if [[ "${had_global_web_https_port}" == "true" ]]; then
          export "PLUME_WEB_HTTPS_PORT=${old_global_web_https_port}"
        elif [[ -n "${allocated_web_https_port}" ]]; then
          unset PLUME_WEB_HTTPS_PORT || true
        fi
        plume_err "workspace ${action}: php-fpm matrix reconcile failed"
        return 2
      fi
      if ! plume_services_workspace_reconcile_web_driver "${compose_file}" "${profile_args[@]}"; then
        plume_err "workspace ${action}: web driver reconcile failed"
        return 2
      fi

      if [[ -n "${current_build_env_hash}" ]]; then
        local config_hash context_hash _f
        local -a _cfg_files=()
        local -a _ctx_files=()
        while IFS= read -r _f; do
          [[ -n "${_f}" ]] && _cfg_files+=("${_f}")
        done < <(plume_services_workspace_collect_config_files "${workspace_root}")
        while IFS= read -r _f; do
          [[ -n "${_f}" ]] && _ctx_files+=("${_f}")
        done < <(plume_services_workspace_collect_context_files "${workspace_root}")
        config_hash="$(plume_services_hash_files "${workspace_root}" ${_cfg_files[@]+"${_cfg_files[@]}"})"
        context_hash="$(plume_services_hash_files "${workspace_root}" ${_ctx_files[@]+"${_ctx_files[@]}"})"
        plume_services_workspace_snapshot_set "${snapshot_file}" "${config_hash}" "${context_hash}" "${current_build_env_hash}"
      fi

      plume_context_lock_activate "services workspace ${action}" "docker-lite" "${target_path:-}"
      if [[ "${had_web_port_env}" == "true" ]]; then
        export "${web_port_env_key}=${old_web_port_env}"
      elif [[ -n "${web_port_env_key}" ]]; then
        unset "${web_port_env_key}" || true
      fi
      if [[ "${had_global_web_port}" == "true" ]]; then
        export "PLUME_WEB_PORT=${old_global_web_port}"
      elif [[ -n "${allocated_web_port}" ]]; then
        unset PLUME_WEB_PORT || true
      fi
      if [[ "${had_web_https_port_env}" == "true" ]]; then
        export "${web_https_port_env_key}=${old_web_https_port_env}"
      elif [[ -n "${web_https_port_env_key}" ]]; then
        unset "${web_https_port_env_key}" || true
      fi
      if [[ "${had_global_web_https_port}" == "true" ]]; then
        export "PLUME_WEB_HTTPS_PORT=${old_global_web_https_port}"
      elif [[ -n "${allocated_web_https_port}" ]]; then
        unset PLUME_WEB_HTTPS_PORT || true
      fi
      ;;
    down)
      plume_docker_compose_exec "${compose_file}" down || return 2
      plume_services_workspace_mark_all_stopped docker-lite
      plume_context_lock_try_clear_if_idle
      ;;
    status)
      plume_docker_compose_exec "${compose_file}" "${profile_args[@]}" ps || return 2
      ;;
    *)
      plume_err "unknown workspace action: ${action} (use init|reinit|apply|up|refresh|rebuild|down|status)"
      return 2
      ;;
  esac
}

plume_services_laradock_parse_path() {
  local arg
  for arg in "$@"; do
    case "${arg}" in
      --path=*)
        printf '%s' "${arg#*=}"
        return 0
        ;;
    esac
  done
  return 1
}

plume_services_laradock_parse_repo() {
  local arg
  for arg in "$@"; do
    case "${arg}" in
      --repo=*)
        printf '%s' "${arg#*=}"
        return 0
        ;;
    esac
  done
  return 1
}

plume_services_laradock_parse_branch() {
  local arg
  for arg in "$@"; do
    case "${arg}" in
      --branch=*)
        printf '%s' "${arg#*=}"
        return 0
        ;;
    esac
  done
  return 1
}

plume_services_laradock_resolve_path() {
  local path
  path="$(plume_services_laradock_parse_path "$@" || true)"
  if [[ -z "${path}" ]]; then
    path="$(plume_mode_path_get laradock-bridge || true)"
  fi
  if [[ -z "${path}" ]]; then
    return 1
  fi
  if [[ "${path}" != /* ]]; then
    path="$(cd "${path}" 2>/dev/null && pwd || true)"
  fi
  printf '%s' "${path}"
}

plume_services_laradock_context_error() {
  local reason="$1"
  case "${reason}" in
    missing-path)
      plume_err "laradock path is not configured; use './plume.sh mode path set laradock-bridge <path>' or pass --path=<laradock-dir>"
      ;;
    invalid-path)
      plume_err "invalid laradock path"
      ;;
    missing-compose)
      plume_err "laradock compose file not found under configured path"
      ;;
    missing-env)
      plume_err "laradock .env not found under configured path"
      ;;
    *)
      plume_err "invalid laradock context"
      ;;
  esac
}

plume_services_laradock_resolve_compose_file() {
  local path="$1"
  if [[ -n "${PLUME_LARADOCK_COMPOSE_FILE:-}" ]]; then
    printf '%s' "${PLUME_LARADOCK_COMPOSE_FILE}"
    return 0
  fi
  if [[ -f "${path}/docker-compose.yml" ]]; then
    printf '%s' "${path}/docker-compose.yml"
    return 0
  fi
  if [[ -f "${path}/compose.yml" ]]; then
    printf '%s' "${path}/compose.yml"
    return 0
  fi
  return 1
}

plume_services_laradock_context_validate() {
  local path="$1"
  local require_env="${2:-false}"
  local require_git="${3:-false}"

  if [[ -z "${path}" ]]; then
    plume_services_laradock_context_error "missing-path"
    return 2
  fi
  if [[ ! -d "${path}" ]]; then
    plume_services_laradock_context_error "invalid-path"
    return 2
  fi

  local compose_file env_file
  compose_file="$(plume_services_laradock_resolve_compose_file "${path}" || true)"
  if [[ -z "${compose_file}" || ! -f "${compose_file}" ]]; then
    plume_services_laradock_context_error "missing-compose"
    return 2
  fi

  if [[ "${require_env}" == "true" ]]; then
    env_file="${path}/.env"
    if [[ ! -f "${env_file}" ]]; then
      plume_services_laradock_context_error "missing-env"
      return 2
    fi
  fi

  if [[ "${require_git}" == "true" && ! -d "${path}/.git" ]]; then
    plume_err "laradock path is not a git repository: ${path}"
    return 2
  fi

  return 0
}

plume_services_laradock_env_value() {
  local env_file="$1"
  local key="$2"
  [[ -f "${env_file}" ]] || return 1
  awk -F'=' -v k="${key}" '
    $1 == k {
      val=$2
      sub(/^[[:space:]]+/, "", val)
      sub(/[[:space:]]+$/, "", val)
      gsub(/^"/, "", val); gsub(/"$/, "", val)
      gsub(/^'\''/, "", val); gsub(/'\''$/, "", val)
      print val
      exit
    }
  ' "${env_file}"
}

cmd_services_laradock_init() {
  local mode
  if ! mode="$(plume_services_parse_mode "$@")"; then
    return 2
  fi
  if [[ "${mode}" != "laradock-bridge" ]]; then
    plume_err "services laradock init is supported only for --mode=laradock-bridge"
    return 2
  fi
  if ! command -v git >/dev/null 2>&1; then
    plume_err "git is required for laradock init"
    return 2
  fi

  local path repo branch
  path="$(plume_services_laradock_resolve_path "$@")"
  repo="$(plume_services_laradock_parse_repo "$@" || true)"
  branch="$(plume_services_laradock_parse_branch "$@" || true)"
  [[ -n "${repo}" ]] || repo="https://github.com/laradock/laradock.git"
  [[ -n "${branch}" ]] || branch="master"

  if [[ -z "${path}" ]]; then
    plume_services_laradock_context_error "missing-path"
    return 2
  fi

  if [[ ! -d "${path}" ]]; then
    mkdir -p "$(dirname "${path}")"
    git clone --depth=1 --branch "${branch}" "${repo}" "${path}" >/dev/null 2>&1 || {
      plume_err "failed to clone laradock repo: ${repo}"
      return 2
    }
  else
    if [[ -d "${path}/.git" ]]; then
      git -C "${path}" remote set-url origin "${repo}" >/dev/null 2>&1 || true
      git -C "${path}" fetch origin "${branch}" >/dev/null 2>&1 || true
      git -C "${path}" checkout "${branch}" >/dev/null 2>&1 || true
      git -C "${path}" pull --ff-only origin "${branch}" >/dev/null 2>&1 || true
    fi
  fi

  if ! plume_services_laradock_context_validate "${path}" "false" "false"; then
    return 2
  fi

  if [[ ! -f "${path}/.env" && -f "${path}/.env.example" ]]; then
    cp "${path}/.env.example" "${path}/.env"
  fi

  plume_mode_path_set laradock-bridge "${path}"
  plume_state_db_append_event "laradock-bridge" "" "laradock.init" "path=${path},repo=${repo},branch=${branch}"
  plume_info "laradock initialized at ${path}"
}

cmd_services_laradock_sync() {
  local mode
  if ! mode="$(plume_services_parse_mode "$@")"; then
    return 2
  fi
  if [[ "${mode}" != "laradock-bridge" ]]; then
    plume_err "services laradock sync is supported only for --mode=laradock-bridge"
    return 2
  fi
  if ! command -v git >/dev/null 2>&1; then
    plume_err "git is required for laradock sync"
    return 2
  fi

  local path repo branch
  path="$(plume_services_laradock_resolve_path "$@")"
  repo="$(plume_services_laradock_parse_repo "$@" || true)"
  branch="$(plume_services_laradock_parse_branch "$@" || true)"
  [[ -n "${repo}" ]] || repo="https://github.com/laradock/laradock.git"
  [[ -n "${branch}" ]] || branch="$(git -C "${path}" rev-parse --abbrev-ref HEAD 2>/dev/null || echo master)"

  if ! plume_services_laradock_context_validate "${path}" "false" "true"; then
    return 2
  fi

  git -C "${path}" remote set-url origin "${repo}" >/dev/null 2>&1 || true
  git -C "${path}" fetch origin "${branch}" >/dev/null 2>&1 || {
    plume_err "failed to fetch ${repo} (${branch})"
    return 2
  }
  git -C "${path}" checkout "${branch}" >/dev/null 2>&1 || true
  git -C "${path}" pull --ff-only origin "${branch}" >/dev/null 2>&1 || {
    plume_err "failed to pull ${repo} (${branch})"
    return 2
  }

  plume_mode_path_set laradock-bridge "${path}"
  plume_state_db_append_event "laradock-bridge" "" "laradock.sync" "path=${path},repo=${repo},branch=${branch}"
  plume_info "laradock synced: ${path} (${branch})"
}

cmd_services_laradock_check() {
  local mode
  if ! mode="$(plume_services_parse_mode "$@")"; then
    return 2
  fi
  if [[ "${mode}" != "laradock-bridge" ]]; then
    plume_err "services laradock check is supported only for --mode=laradock-bridge"
    return 2
  fi

  local path compose_file env_file
  path="$(plume_services_laradock_resolve_path "$@")"
  if ! plume_services_laradock_context_validate "${path}" "true" "false"; then
    return 2
  fi
  compose_file="$(plume_services_laradock_resolve_compose_file "${path}")"
  env_file="${path}/.env"

  local -a required_services=(
    "nginx"
    "apache2"
    "caddy"
    "mariadb"
    "mysql"
    "phpmyadmin"
    "php-fpm"
    "redis"
    "laravel-horizon"
    "php-worker"
    "workspace"
  )
  local svc missing=0
  for svc in "${required_services[@]}"; do
    if ! plume_services_compose_has_service "${compose_file}" "${svc}"; then
      plume_err "laradock service missing in compose: ${svc}"
      missing=1
    fi
  done
  if [[ "${missing}" -ne 0 ]]; then
    return 2
  fi

  local app_host app_container app_abs
  app_host="$(plume_services_laradock_env_value "${env_file}" "APP_CODE_PATH_HOST" || true)"
  app_container="$(plume_services_laradock_env_value "${env_file}" "APP_CODE_PATH_CONTAINER" || true)"
  [[ -n "${app_host}" ]] || app_host="../"
  [[ -n "${app_container}" ]] || app_container="/var/www"

  if [[ "${app_container}" != "/var/www" ]]; then
    plume_err "APP_CODE_PATH_CONTAINER must be /var/www for strict bridge parity (got: ${app_container})"
    return 2
  fi

  if [[ "${app_host}" != /* ]]; then
    app_abs="$(cd "${path}" 2>/dev/null && cd "${app_host}" 2>/dev/null && pwd || true)"
  else
    app_abs="${app_host}"
  fi
  if [[ -z "${app_abs}" || ! -d "${app_abs}" ]]; then
    plume_err "APP_CODE_PATH_HOST does not resolve to a valid directory: ${app_host}"
    return 2
  fi

  local id record mode_of_site site_path offscope=0
  while IFS= read -r id; do
    [[ -z "${id}" ]] && continue
    record="$(plume_sites_file "${id}")"
    mode_of_site="$(plume_sites_record_value "${record}" mode)"
    [[ "${mode_of_site}" == "laradock-bridge" ]] || continue
    site_path="$(plume_sites_record_value "${record}" path)"
    if [[ "${site_path}" != "${app_abs}"* ]]; then
      plume_err "site path is outside APP_CODE_PATH_HOST scope: ${id} -> ${site_path} (scope: ${app_abs})"
      offscope=1
    fi
  done < <(plume_sites_index_ids)
  if [[ "${offscope}" -ne 0 ]]; then
    return 2
  fi

  if plume_services_compose_has_service "${compose_file}" "docker-in-docker"; then
    plume_info "optional service detected: docker-in-docker"
  fi

  plume_mode_path_set laradock-bridge "${path}"
  plume_state_db_append_event "laradock-bridge" "" "laradock.check" "path=${path},app_root=${app_abs}"
  plume_info "laradock check passed: path=${path}, app_root=${app_abs}, container_root=${app_container}"
}

cmd_services_laradock() {
  local action="${1:-check}"
  shift || true
  case "${action}" in
    init)
      cmd_services_laradock_init "$@"
      ;;
    sync)
      cmd_services_laradock_sync "$@"
      ;;
    check)
      cmd_services_laradock_check "$@"
      ;;
    *)
      plume_err "unknown laradock action: ${action} (use init|sync|check)"
      return 2
      ;;
  esac
}

cmd_services_web_sync_config() {
  local target_port="" dry_run="false" do_reload="false"
  local arg
  for arg in "$@"; do
    case "${arg}" in
      --port=*) target_port="${arg#*=}" ;;
      --dry-run) dry_run="true" ;;
      --reload) do_reload="true" ;;
      *)
        plume_err "unknown services web sync-config option: ${arg}"
        return 2
        ;;
    esac
  done
  if [[ -z "${target_port}" ]]; then
    target_port="${PLUME_NATIVE_NGINX_HTTP_PORT:-80}"
  fi
  plume_native_nginx_sync_main_config "${target_port}" "${dry_run}" "${do_reload}"
}

cmd_services_web_port() {
  local target_port="${1:-80}"
  shift || true
  local dry_run="false" do_reload="false"
  local arg
  for arg in "$@"; do
    case "${arg}" in
      --dry-run) dry_run="true" ;;
      --reload) do_reload="true" ;;
      *)
        plume_err "unknown services web port option: ${arg}"
        return 2
        ;;
    esac
  done
  plume_native_nginx_sync_main_config "${target_port}" "${dry_run}" "${do_reload}"
}

cmd_services_web() {
  local action="${1:-}"
  shift || true
  case "${action}" in
    sync-config)
      cmd_services_web_sync_config "$@"
      ;;
    port)
      cmd_services_web_port "$@"
      ;;
    *)
      plume_err "unknown services web action: ${action} (use sync-config|port)"
      return 2
      ;;
  esac
}

cmd_services_redis_sync_config() {
  local dry_run="false" do_reload="false"
  local arg
  for arg in "$@"; do
    case "${arg}" in
      --dry-run) dry_run="true" ;;
      --reload) do_reload="true" ;;
      *)
        plume_err "unknown services redis sync-config option: ${arg}"
        return 2
        ;;
    esac
  done
  plume_native_redis_sync_config "${dry_run}" "${do_reload}"
}

cmd_services_redis() {
  local action="${1:-}"
  shift || true
  case "${action}" in
    sync-config)
      cmd_services_redis_sync_config "$@"
      ;;
    *)
      plume_err "unknown services redis action: ${action} (use sync-config)"
      return 2
      ;;
  esac
}

cmd_services_manifest() {
  local action="${1:-show}"
  shift || true
  case "${action}" in
    show)
      plume_services_manifest_print_effective
      return 0
      ;;
    *)
      plume_err "unknown services manifest action: ${action} (use show)"
      return 2
      ;;
  esac
}

cmd_services_provision() {
  local from_manifest="false" dry_run="false"
  local arg
  for arg in "$@"; do
    case "${arg}" in
      --from-manifest) from_manifest="true" ;;
      --dry-run) dry_run="true" ;;
      *)
        plume_err "unknown services provision option: ${arg}"
        return 2
        ;;
    esac
  done
  if [[ "${from_manifest}" != "true" ]]; then
    plume_err "services provision requires --from-manifest (see docs/operations/services-manifest.md)"
    return 2
  fi
  plume_services_manifest_provision_services "${dry_run}"
}

cmd_services_url() {
  local mode service url
  if ! mode="$(plume_services_parse_mode "$@")"; then
    return 2
  fi
  service="$(plume_services_first_positional "$@")"
  if [[ -z "${service}" ]]; then
    plume_err "services url requires <service> (phpmyadmin|mongo_webui|redis_webui|rabbitmq|mailpit)"
    return 2
  fi
  service="$(plume_service_contract_normalize "${service}" "${mode}")"
  if [[ "${mode}" != "native" ]]; then
    plume_err "services url is native-only in Phase 17 (service=${service})"
    return 2
  fi
  if ! url="$(plume_native_host_service_url "${service}" 2>/dev/null)"; then
    port="$(plume_service_default_port "${service}" 2>/dev/null || true)"
    if [[ -n "${port}" ]]; then
      printf 'url=http://127.0.0.1:%s\n' "${port}"
      return 0
    fi
    plume_err "no url mapping for service: ${service}"
    return 2
  fi
  printf 'url=%s\n' "${url}"
}

cmd_services_credentials() {
  local mode service
  if ! mode="$(plume_services_parse_mode "$@")"; then
    return 2
  fi
  service="$(plume_services_first_positional "$@")"
  if [[ -z "${service}" ]]; then
    plume_err "services credentials requires <service> (postgres|mariadb|mysql|mongodb|redis|rabbitmq|mongo_webui|redis_webui)"
    return 2
  fi
  service="$(plume_service_contract_normalize "${service}" "${mode}")"
  if [[ "${mode}" != "native" ]]; then
    plume_err "services credentials is native-only in Phase 17"
    return 2
  fi
  case "${service}" in
    postgres|mariadb|mysql|mongodb|redis|rabbitmq|mongo_webui|redis_webui) ;;
    *)
      plume_err "credentials not supported for service: ${service}"
      return 2
      ;;
  esac
  if ! plume_native_host_print_credentials "${service}"; then
    plume_err "no credentials stored for ${service}; run services install ${service} --mode=native"
    return 2
  fi
}

plume_services_restart_one() {
  local mode="$1"
  local service="$2"
  if [[ "${service}" == "redis" ]] && plume_native_redis_manage_config_enabled; then
    plume_native_redis_sync_config "false" "false" || true
  fi
  PLUME_MODE="${mode}" plume_service_stop "${service}" || true
  PLUME_MODE="${mode}" plume_service_start "${service}"
}

cmd_services_restart() {
  local mode target
  if ! plume_services_parse_version "$@"; then
    return 2
  fi
  if ! mode="$(plume_services_parse_mode "$@")"; then
    return 2
  fi
  if [[ "${mode}" == "laradock-bridge" ]]; then
    plume_services_laradock_runtime_prepare "$@" || return 2
  fi
  target="$(plume_services_first_positional "$@")"
  target="${target:-}"
  if [[ -z "${target}" ]]; then
    plume_err "service name required (or all-enabled)"
    return 2
  fi
  services_each_target "${target}" "plume_services_restart_one_wrapper" enabled "${mode}"
  plume_context_lock_activate "services restart" "${mode}"
}

plume_services_restart_one_wrapper() {
  local service="$1"
  plume_services_restart_one "${PLUME_MODE:-native}" "${service}"
}

cmd_services_env_show() {
  local mode service key val
  if ! mode="$(plume_services_parse_mode "$@")"; then
    return 2
  fi
  service="$(plume_services_first_positional "$@")"
  if [[ -z "${service}" ]]; then
    plume_err "services env show requires <service> (redis|mongodb|rabbitmq|mongo_webui|redis_webui)"
    return 2
  fi
  service="$(plume_service_contract_normalize "${service}" "${mode}")"
  if ! plume_stack_service_env_keys_for_service "${service}" >/dev/null 2>&1; then
    plume_err "env show not supported for service: ${service}"
    return 2
  fi
  while IFS= read -r key; do
    [[ -n "${key}" ]] || continue
    val="${!key:-}"
    printf '%s=%s\n' "${key}" "${val}"
  done < <(plume_stack_service_env_keys_for_service "${service}")
}

cmd_services_env_set() {
  local mode service assignment restart="false"
  local resolved key value affected
  if ! mode="$(plume_services_parse_mode "$@")"; then
    return 2
  fi
  local -a args=("$@")
  local arg
  for arg in "${args[@]}"; do
    case "${arg}" in
      --restart) restart="true" ;;
    esac
  done
  service="$(plume_services_first_positional "$@")"
  assignment="$(plume_services_second_positional "$@")"
  if [[ -z "${service}" || -z "${assignment}" ]]; then
    plume_err "services env set requires <service> <KEY=VALUE|short=VALUE>"
    return 2
  fi
  service="$(plume_service_contract_normalize "${service}" "${mode}")"
  if ! resolved="$(plume_stack_service_env_resolve_assignment "${service}" "${assignment}")"; then
    plume_err "unknown env assignment for ${service}: ${assignment}"
    plume_info "use: ./plume.sh services env show ${service} --mode=native"
    return 2
  fi
  key="${resolved%%=*}"
  value="${resolved#*=}"
  plume_stack_service_env_write_and_export "${key}" "${value}" || return $?
  if [[ "${restart}" == "true" ]]; then
    while IFS= read -r affected; do
      [[ -n "${affected}" ]] || continue
      plume_services_restart_one "${mode}" "${affected}" || return $?
    done < <(plume_stack_service_env_affected_services "${key}")
  else
    plume_info "restart to apply: ./plume.sh services restart ${service} --mode=${mode}"
    if plume_stack_service_env_affected_services "${key}" >/dev/null 2>&1; then
      while IFS= read -r affected; do
        [[ -n "${affected}" && "${affected}" != "${service}" ]] || continue
        plume_info "  also restart: ./plume.sh services restart ${affected} --mode=${mode}"
      done < <(plume_stack_service_env_affected_services "${key}")
    fi
  fi
}

cmd_services_env() {
  local sub="${1:-show}"
  shift || true
  case "${sub}" in
    show) cmd_services_env_show "$@" ;;
    set) cmd_services_env_set "$@" ;;
    *)
      plume_err "unknown services env subcommand: ${sub} (use show|set)"
      return 2
      ;;
  esac
}

cmd_services_update() {
  plume_require_root
  local mode
  if ! mode="$(plume_services_parse_mode "$@")"; then
    return 2
  fi
  if ! plume_require_yes_for_critical "${mode}" "critical.services.update" "mode=${mode}" "Use --yes services update"; then
    return 2
  fi
  if ! plume_services_parse_version "$@"; then
    return 2
  fi

  local changed=0
  local service
  while IFS= read -r service; do
    [[ -z "${service}" ]] && continue
    local prev curr
    prev="$(plume_services_prev_enabled "${service}")"
    curr="$(plume_service_enabled "${service}")"
    if [[ "${prev}" == "false" && "${curr}" == "true" ]]; then
      plume_info "reconcile enable detected: ${service}"
      PLUME_MODE="${mode}" PLUME_SERVICE_VERSION="${PLUME_SERVICE_VERSION}" plume_service_install "${service}"
      PLUME_MODE="${mode}" PLUME_SERVICE_VERSION="${PLUME_SERVICE_VERSION}" plume_service_start "${service}"
      changed=1
    fi
  done < <(plume_service_names_for_mode "${mode}")
  plume_services_write_state "${mode}"

  if [[ "${changed}" -eq 0 ]]; then
    plume_info "no false->true service toggle detected"
  fi
}

plume_service_wrapper_invoke() {
  local mode="$1"
  local callback="$2"
  local service="$3"
  local version="${4:-latest}"
  service="$(plume_service_contract_normalize "${service}" "${mode}")"
  PLUME_MODE="${mode}" PLUME_SERVICE_VERSION="${version}" "${callback}" "${service}"
}

cmd_services() {
  local sub="${1:-supported}"
  shift || true
  case "${sub}" in
    config)
      cmd_services_config "$@"
      ;;
    supported)
      cmd_services_supported "$@"
      ;;
    status)
      cmd_services_status "$@"
      ;;
    install)
      cmd_services_install "$@"
      ;;
    up)
      cmd_services_up "$@"
      ;;
    down)
      cmd_services_down "$@"
      ;;
    restart)
      cmd_services_restart "$@"
      ;;
    env)
      cmd_services_env "$@"
      ;;
    health)
      cmd_services_health "$@"
      ;;
    logs)
      cmd_services_logs "$@"
      ;;
    exec)
      cmd_services_exec "$@"
      ;;
    containers)
      cmd_services_containers "$@"
      ;;
    laradock)
      cmd_services_laradock "$@"
      ;;
    workspace)
      cmd_services_workspace "$@"
      ;;
    web)
      cmd_services_web "$@"
      ;;
    redis)
      cmd_services_redis "$@"
      ;;
    manifest)
      cmd_services_manifest "$@"
      ;;
    provision)
      cmd_services_provision "$@"
      ;;
    url)
      cmd_services_url "$@"
      ;;
    credentials)
      cmd_services_credentials "$@"
      ;;
    update)
      cmd_services_update "$@"
      ;;
    *)
      plume_err "unknown services subcommand: ${sub}"
      return 2
      ;;
  esac
}
