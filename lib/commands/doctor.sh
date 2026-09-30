#!/usr/bin/env bash
set -euo pipefail

plume_doctor_parse_mode() {
  local mode
  mode="$(plume_mode_current)"
  local arg
  for arg in "$@"; do
    case "${arg}" in
      --mode=*) mode="${arg#*=}" ;;
    esac
  done
  case "${mode}" in
    native|docker-lite|laradock-bridge) ;;
    *)
      plume_err "invalid mode for doctor: ${mode}"
      return 2
      ;;
  esac
  printf '%s' "${mode}"
}

plume_doctor_has_flag() {
  local wanted="$1"
  shift
  local arg
  for arg in "$@"; do
    [[ "${arg}" == "${wanted}" ]] && return 0
  done
  return 1
}

plume_doctor_run_check() {
  local name="$1"
  local critical="$2"
  local detail="$3"
  shift 3
  local result="ok"
  if ! "$@" >/dev/null 2>&1; then
    result="fail"
    if [[ "${critical}" == "true" ]]; then
      PLUME_DOCTOR_CRITICAL_FAIL=1
    fi
  fi
  printf '%-18s %-8s %-8s %s\n' "${name}" "${result}" "${critical}" "${detail}"
}

plume_doctor_web_print_line() {
  local name="$1"
  local result="$2"
  local critical="$3"
  local detail="$4"
  if [[ "${result}" == "FAIL" && "${critical}" == "true" ]]; then
    PLUME_DOCTOR_WEB_CRITICAL_FAIL=1
  fi
  printf '%-22s %-6s %-8s %s\n' "${name}" "${result}" "${critical}" "${detail}"
}

plume_doctor_web_driver() {
  case "${PLUME_WEB_SERVER_DRIVER:-nginx}" in
    nginx|apache2|caddy) printf '%s' "${PLUME_WEB_SERVER_DRIVER:-nginx}" ;;
    *) printf '%s' "nginx" ;;
  esac
}

plume_doctor_web_binary_path() {
  local driver="$1"
  case "${driver}" in
    nginx)
      if declare -F plume_sites_native_nginx_bin >/dev/null 2>&1; then
        plume_sites_native_nginx_bin
        return 0
      fi
      command -v nginx 2>/dev/null || true
      ;;
    apache2)
      if command -v apachectl >/dev/null 2>&1; then
        command -v apachectl
      elif command -v httpd >/dev/null 2>&1; then
        command -v httpd
      fi
      ;;
    caddy)
      command -v caddy 2>/dev/null || true
      ;;
  esac
}

plume_doctor_web_init_state() {
  local driver="$1"
  local svc=""
  case "${driver}" in
    nginx) svc="nginx" ;;
    apache2) svc="apache2" ;;
    caddy) svc="caddy" ;;
  esac
  if [[ -z "${svc}" ]]; then
    printf '%s' "unknown"
    return 0
  fi
  if command -v brew >/dev/null 2>&1 && declare -F plume_native_host_brew_service_name >/dev/null 2>&1; then
    local brew_svc
    brew_svc="$(plume_native_host_brew_service_name "${svc}" 2>/dev/null || true)"
    if [[ -n "${brew_svc}" ]]; then
      local line state
      line="$(HOMEBREW_NO_AUTO_UPDATE=1 brew services list 2>/dev/null | awk -v svc="${brew_svc}" '$1==svc {print $2; exit}' || true)"
      case "${line}" in
        started) printf '%s' "started"; return 0 ;;
        stopped|"") printf '%s' "stopped"; return 0 ;;
        *) printf '%s' "${line}"; return 0 ;;
      esac
    fi
  fi
  if command -v systemctl >/dev/null 2>&1 && declare -F plume_native_host_systemd_unit >/dev/null 2>&1; then
    local unit
    unit="$(plume_native_host_systemd_unit "${svc}" 2>/dev/null || true)"
    if [[ -n "${unit}" ]]; then
      if systemctl is-active --quiet "${unit}.service" 2>/dev/null; then
        printf '%s' "active"
        return 0
      fi
      if systemctl is-active --quiet "${unit}" 2>/dev/null; then
        printf '%s' "active"
        return 0
      fi
      printf '%s' "inactive"
      return 0
    fi
  fi
  printf '%s' "unknown"
}

plume_doctor_web_port_detail() {
  local port="$1"
  local proc=""
  if ! plume_service_port_in_use "${port}"; then
    printf 'port %s not listening' "${port}"
    return 0
  fi
  if command -v lsof >/dev/null 2>&1; then
    proc="$(lsof -nP -iTCP:"${port}" -sTCP:LISTEN 2>/dev/null | awk 'NR==2 {print $1; exit}' || true)"
  fi
  if [[ -n "${proc}" ]]; then
    printf 'port %s listening (%s)' "${port}" "${proc}"
  else
    printf 'port %s listening' "${port}"
  fi
}

plume_doctor_web_homebrew_port80_hint() {
  local effective_port="$1"
  printf 'plumectl services web ensure (or browse :%s); plumectl site check <site-id> for url_http' "${effective_port}"
}

plume_doctor_web_strict_include_checks() {
  local mode="$1"
  local driver="$2"
  local strict_reload="$3"
  local missing="0" stale="0" checked="0"
  local id file server port cache_conf target_conf include_dir
  if [[ "${mode}" != "native" || "${strict_reload}" != "true" ]]; then
    plume_doctor_web_print_line "strict-includes" "SKIP" "false" "strict-on-reload disabled or non-native mode"
    return 0
  fi
  include_dir="$(plume_sites_native_include_dir_for_server "${driver}" 2>/dev/null || true)"
  if [[ -z "${include_dir}" ]]; then
    plume_doctor_web_print_line "strict-includes" "WARN" "false" "include directory not resolved (set PLUME_NGINX_INCLUDE_DIR)"
    return 0
  fi
  while IFS= read -r id; do
    [[ -z "${id}" ]] && continue
    file="$(plume_sites_file "${id}")"
    [[ -f "${file}" ]] || continue
    server="$(plume_sites_record_value "${file}" server)"
    [[ "${server}" == "${driver}" ]] || continue
    cache_conf="$(plume_sites_cache_dir "${server}" "${mode}")/${id}.conf"
    [[ -f "${cache_conf}" ]] || continue
    checked=$((checked + 1))
    target_conf="${include_dir}/${id}.conf"
    if [[ ! -f "${target_conf}" ]]; then
      missing=$((missing + 1))
      continue
    fi
    if ! cmp -s "${cache_conf}" "${target_conf}" 2>/dev/null; then
      stale=$((stale + 1))
    fi
  done < <(plume_sites_index_ids)

  if [[ "${checked}" -eq 0 ]]; then
    plume_doctor_web_print_line "strict-includes" "SKIP" "false" "no published ${driver} snippets in registry cache"
    return 0
  fi
  if [[ "${missing}" -gt 0 ]]; then
    plume_doctor_web_print_line "strict-includes" "FAIL" "true" "${missing}/${checked} strict target missing under ${include_dir}"
    return 0
  fi
  if [[ "${stale}" -gt 0 ]]; then
    plume_doctor_web_print_line "strict-includes" "WARN" "false" "${stale}/${checked} strict target differs from plume cache (republish --reload)"
    return 0
  fi
  plume_doctor_web_print_line "strict-includes" "PASS" "true" "${checked} strict include(s) present and match cache"
}

plume_doctor_web_macos_site_path_tcc() {
  local summary=""
  if [[ "$(uname -s 2>/dev/null)" != "Darwin" ]]; then
    plume_doctor_web_print_line "macos-site-tcc" "SKIP" "false" "macOS-only check"
    return 0
  fi
  if ! declare -F plume_sites_macos_tcc_sensitive_site_summary >/dev/null 2>&1; then
    plume_doctor_web_print_line "macos-site-tcc" "SKIP" "false" "site registry helper unavailable"
    return 0
  fi
  summary="$(plume_sites_macos_tcc_sensitive_site_summary)"
  if [[ -z "${summary}" ]]; then
    plume_doctor_web_print_line "macos-site-tcc" "PASS" "false" "no site paths under Desktop/Documents/Downloads"
    return 0
  fi
  plume_doctor_web_print_line "macos-site-tcc" "WARN" "false" "TCC may block nginx/php-fpm (${summary}) — Full Disk Access or move project; $(plume_macos_permissions_doctor_hint)"
}

cmd_doctor_web() {
  local mode strict driver enabled web_bin init_state registry_port effective_port https_port
  local sites_total sites_port80 listener_eff listener_80 listener_443 detail result crit
  mode="$(plume_doctor_parse_mode "$@")" || return 2
  strict="false"
  local arg
  for arg in "$@"; do
    case "${arg}" in
      --strict) strict="true" ;;
      --mode=*) ;;
      *)
        plume_err "unknown doctor web option: ${arg}"
        return 2
        ;;
    esac
  done

  PLUME_DOCTOR_WEB_CRITICAL_FAIL=0
  driver="$(plume_doctor_web_driver)"
  enabled="$(plume_bool "${PLUME_WEB_SERVER_ENABLED:-true}")"

  printf 'MODE              %s\n' "${mode}"
  printf 'STRICT            %s\n' "${strict}"
  printf 'DRIVER            %s\n' "${driver}"
  printf 'WEB_ENABLED       %s\n' "${enabled}"
  echo "CHECK                 RESULT CRITICAL DETAIL"
  echo "---------------------- ------ -------- ----------------------------------------"

  if [[ "${enabled}" != "true" ]]; then
    plume_doctor_web_print_line "web-enabled" "SKIP" "false" "PLUME_WEB_SERVER_ENABLED=false"
    echo "OVERALL               OK"
    return 0
  fi

  plume_doctor_web_print_line "web-enabled" "PASS" "false" "PLUME_WEB_SERVER_ENABLED=true"

  if [[ "${mode}" != "native" ]]; then
    plume_doctor_web_print_line "native-binary" "SKIP" "false" "use services status for ${mode} web container"
    plume_doctor_web_print_line "init-system" "SKIP" "false" "brew/systemd checks are native-only"
    registry_port="$(plume_service_default_port web)"
    effective_port="$(plume_sites_effective_http_port "${registry_port}" "${mode}")"
    https_port="$(plume_service_default_https_port web)"
    [[ -n "${https_port}" ]] || https_port="443"
    detail="$(plume_doctor_web_port_detail "${effective_port}")"
    if plume_service_port_in_use "${effective_port}"; then
      plume_doctor_web_print_line "listener-effective" "PASS" "true" "${detail} (registry/effective ${registry_port}->${effective_port})"
    else
      plume_doctor_web_print_line "listener-effective" "FAIL" "true" "${detail} (registry/effective ${registry_port}->${effective_port})"
    fi
    detail="$(plume_doctor_web_port_detail "80")"
    if plume_service_port_in_use "80"; then
      plume_doctor_web_print_line "listener-80" "PASS" "false" "${detail}"
    else
      plume_doctor_web_print_line "listener-80" "WARN" "false" "${detail}"
    fi
    detail="$(plume_doctor_web_port_detail "${https_port}")"
    if plume_service_port_in_use "${https_port}"; then
      plume_doctor_web_print_line "listener-https" "PASS" "false" "${detail}"
    else
      plume_doctor_web_print_line "listener-https" "WARN" "false" "${detail} (no TLS listener)"
    fi
    plume_doctor_web_print_line "strict-includes" "SKIP" "false" "native strict include checks skipped"
    plume_doctor_web_print_line "sites-port80" "SKIP" "false" "registry port-80 cross-check skipped in ${mode}"
    if [[ "${PLUME_DOCTOR_WEB_CRITICAL_FAIL}" -ne 0 ]]; then
      echo "OVERALL               FAIL"
      if [[ "${strict}" == "true" ]]; then
        return 2
      fi
      return 0
    fi
    echo "OVERALL               OK"
    return 0
  fi

  web_bin="$(plume_doctor_web_binary_path "${driver}")"
  if [[ -n "${web_bin}" ]]; then
    plume_doctor_web_print_line "native-binary" "PASS" "true" "${driver} binary: ${web_bin}"
  else
    plume_doctor_web_print_line "native-binary" "FAIL" "true" "${driver} binary not found in PATH or brew prefix"
  fi

  init_state="$(plume_doctor_web_init_state "${driver}")"
  case "${init_state}" in
    started|active)
      plume_doctor_web_print_line "init-system" "PASS" "true" "${driver} service ${init_state} (brew/systemd)"
      ;;
    stopped|inactive)
      plume_doctor_web_print_line "init-system" "FAIL" "true" "${driver} service ${init_state} (brew services start ${driver})"
      ;;
    *)
      plume_doctor_web_print_line "init-system" "WARN" "false" "service state ${init_state} (could not detect brew/systemd)"
      ;;
  esac

  registry_port="${PLUME_WEB_PORT:-80}"
  effective_port="$(plume_sites_effective_http_port "${registry_port}" "${mode}")"
  https_port="${PLUME_WEB_HTTPS_PORT:-443}"

  detail="$(plume_doctor_web_port_detail "${effective_port}")"
  if plume_service_port_in_use "${effective_port}"; then
    plume_doctor_web_print_line "listener-effective" "PASS" "true" "${detail} (registry ${registry_port}, effective ${effective_port})"
  else
    plume_doctor_web_print_line "listener-effective" "FAIL" "true" "${detail} (registry ${registry_port}, effective ${effective_port})"
  fi

  detail="$(plume_doctor_web_port_detail "80")"
  if plume_service_port_in_use "80"; then
    plume_doctor_web_print_line "listener-80" "PASS" "false" "${detail}"
  else
    if [[ "${registry_port}" == "80" && "${effective_port}" != "80" ]]; then
      plume_doctor_web_print_line "listener-80" "WARN" "false" "${detail}; $(plume_doctor_web_homebrew_port80_hint "${effective_port}")"
    else
      plume_doctor_web_print_line "listener-80" "WARN" "false" "${detail}"
    fi
  fi

  detail="$(plume_doctor_web_port_detail "${https_port}")"
  if plume_service_port_in_use "${https_port}"; then
    plume_doctor_web_print_line "listener-https" "PASS" "false" "${detail}"
  else
    plume_doctor_web_print_line "listener-https" "WARN" "false" "${detail} (optional unless TLS sites use ${https_port})"
  fi

  strict_reload="$(plume_bool "${PLUME_SITE_NGINX_STRICT_ON_RELOAD:-true}")"
  if [[ "${driver}" == "nginx" ]]; then
    plume_doctor_web_strict_include_checks "${mode}" "${driver}" "${strict_reload}"
  else
    plume_doctor_web_print_line "strict-includes" "SKIP" "false" "nginx strict include check skipped (driver=${driver})"
  fi

  sites_total=0
  sites_port80=0
  while IFS= read -r id; do
    [[ -z "${id}" ]] && continue
    local file port
    file="$(plume_sites_file "${id}")"
    [[ -f "${file}" ]] || continue
    sites_total=$((sites_total + 1))
    port="$(plume_sites_record_value "${file}" port)"
    [[ -n "${port}" ]] || port="80"
    if [[ "${port}" == "80" ]]; then
      sites_port80=$((sites_port80 + 1))
    fi
  done < <(plume_sites_index_ids)

  if [[ "${sites_port80}" -gt 0 ]] && ! plume_service_port_in_use "80"; then
    plume_doctor_web_print_line "sites-port80" "WARN" "false" "${sites_port80}/${sites_total} site(s) registry port 80 but nothing listens on 80 — $(plume_doctor_web_homebrew_port80_hint "${effective_port}")"
  elif [[ "${sites_port80}" -gt 0 ]]; then
    plume_doctor_web_print_line "sites-port80" "PASS" "false" "${sites_port80}/${sites_total} site(s) on registry port 80; port 80 is listening"
  else
    plume_doctor_web_print_line "sites-port80" "PASS" "false" "${sites_total} site(s); none require registry port 80"
  fi

  plume_doctor_web_macos_site_path_tcc

  if [[ "${PLUME_DOCTOR_WEB_CRITICAL_FAIL}" -ne 0 ]]; then
    echo "OVERALL               FAIL"
    if [[ "${strict}" == "true" ]]; then
      return 2
    fi
    return 0
  fi
  echo "OVERALL               OK"
}

cmd_doctor_check() {
  local mode deep
  mode="$(plume_doctor_parse_mode "$@")" || return 2
  deep="false"
  if plume_doctor_has_flag "--deep" "$@"; then
    deep="true"
  fi

  PLUME_DOCTOR_CRITICAL_FAIL=0

  printf 'MODE              %s\n' "${mode}"
  printf 'DEEP              %s\n' "${deep}"
  echo "CHECK              RESULT   CRITICAL DETAIL"
  echo "------------------ -------- -------- ----------------------------------------"

  plume_doctor_run_check "state-dir" "true" "state dir writable" test -w "$(plume_state_dir)"
  plume_doctor_run_check "state-db" "true" "sqlite state db ready" test -f "$(plume_state_db_file)"
  plume_doctor_run_check "services-registry" "true" "service registry readable" plume_service_names_for_mode "${mode}"

  if [[ "${mode}" == "laradock-bridge" ]]; then
    plume_doctor_run_check "laradock-context" "true" "laradock path/compose validation" plume_services_laradock_runtime_prepare --mode="${mode}"
  fi

  if [[ "${mode}" == "docker-lite" ]]; then
    plume_doctor_run_check "docker-compose" "false" "docker compose availability (optional in beta)" plume_docker_compose_has_v2
  fi

  if [[ "${deep}" == "true" ]]; then
    plume_doctor_run_check "services-health" "true" "health collector path" cmd_services_health --mode="${mode}" --running
    if [[ "${mode}" == "laradock-bridge" || "${mode}" == "docker-lite" ]]; then
      plume_doctor_run_check "sync-state" "false" "runtime sync state pass" cmd_sync_state --mode="${mode}"
    fi
  fi

  if [[ "${PLUME_DOCTOR_CRITICAL_FAIL}" -ne 0 ]]; then
    echo "OVERALL            FAIL"
    return 2
  fi
  echo "OVERALL            OK"
}

cmd_doctor_services() {
  cmd_services_status "$@"
}

cmd_doctor_ports() {
  local mode
  mode="$(plume_doctor_parse_mode "$@")" || return 2
  local service status_line _svc _enabled _running _health _port _version
  printf 'MODE              %s\n' "${mode}"
  echo "SERVICE           RUNNING PORTS"
  echo "----------------- ------- ----------------"
  while IFS= read -r service; do
    [[ -z "${service}" ]] && continue
    status_line="$(plume_services_display_status_line "${service}" "${mode}")"
    IFS=$'\t' read -r _svc _enabled _running _health _port _version <<< "${status_line}"
    if [[ -z "${_port}" || "${_port}" == "-" ]]; then
      continue
    fi
    if [[ "${mode}" == "docker-lite" ]]; then
      case "${_health}" in
        healthy) _running="true" ;;
        stopped|disabled) _running="false" ;;
      esac
    fi
    printf '%-17s %-7s %s\n' "${_svc}" "${_running}" "${_port}"
  done < <(plume_services_display_names_for_mode "${mode}")
}

cmd_doctor_php() {
  local strict="false"
  local arg
  for arg in "$@"; do
    case "${arg}" in
      --strict) strict="true" ;;
      --mode=*) ;;
      *)
        plume_err "unknown doctor php option: ${arg}"
        return 2
        ;;
    esac
  done

  local versions default_v version mm compact cli_bin fpm_bin cli_ok fpm_ok role
  versions="$(plume_php_versions_csv_normalize "${PLUME_PHP_INSTALLED_VERSIONS}")" || return 2
  default_v="$(plume_php_version_normalize "${PLUME_PHP_DEFAULT_VERSION:-${PLUME_PHP_VERSION:-8.3}}")" || return 2

  local failed="0"
  printf 'STRICT            %s\n' "${strict}"
  printf 'DEFAULT           %s\n' "${default_v}"
  echo "VERSION  ROLE     CLI        FPM        CLI_BIN  FPM_BIN"
  echo "-------- -------- ---------- ---------- -------- --------"

  IFS=',' read -r -a _doctor_php_versions <<< "${versions}"
  for version in "${_doctor_php_versions[@]}"; do
    version="$(printf '%s' "${version}" | sed 's/^ *//;s/ *$//')"
    [[ -n "${version}" ]] || continue
    mm="$(plume_php_version_major_minor "${version}" || true)"
    compact="$(printf '%s' "${mm}" | tr -d '.')"
    role="extra"
    if [[ "${version}" == "${default_v}" ]]; then
      role="default"
    fi
    cli_bin="$(plume_php_find_cli_bin "${version}" || true)"
    fpm_bin="$(plume_php_find_fpm_bin "${version}" || true)"
    cli_ok="missing"
    fpm_ok="missing"
    [[ -n "${cli_bin}" ]] && cli_ok="ok"
    [[ -n "${fpm_bin}" ]] && fpm_ok="ok"
    if [[ "${cli_ok}" != "ok" || "${fpm_ok}" != "ok" ]]; then
      failed="1"
    fi
    printf '%-8s %-8s %-10s %-10s %-8s %-8s\n' "php${compact}" "${role}" "${cli_ok}" "${fpm_ok}" "$(if [[ -n "${cli_bin}" ]]; then printf 'yes'; else printf 'no'; fi)" "$(if [[ -n "${fpm_bin}" ]]; then printf 'yes'; else printf 'no'; fi)"
  done

  if [[ "$(uname -s 2>/dev/null)" == "Darwin" ]] && declare -F plume_sites_macos_tcc_sensitive_site_summary >/dev/null 2>&1; then
    local tcc_summary=""
    tcc_summary="$(plume_sites_macos_tcc_sensitive_site_summary)"
    if [[ -n "${tcc_summary}" ]]; then
      printf 'MACOS_TCC           WARN     php-fpm may fail with "No input file specified" (%s) — %s\n' "${tcc_summary}" "$(plume_macos_permissions_doctor_hint)"
    else
      printf 'MACOS_TCC           PASS     no registered sites under Desktop/Documents/Downloads\n'
    fi
  fi

  if [[ "${failed}" == "1" ]]; then
    if [[ "${strict}" == "true" ]]; then
      return 2
    fi
    return 0
  fi
}

cmd_doctor_php_ext() {
  local strict="false"
  local arg
  for arg in "$@"; do
    case "${arg}" in
      --strict) strict="true" ;;
      --mode=*) ;;
      *)
        plume_err "unknown doctor php-ext option: ${arg}"
        return 2
        ;;
    esac
  done
  cmd_php_ext_doctor "$(if [[ "${strict}" == "true" ]]; then printf '%s' "--strict"; fi)"
}

cmd_doctor_web_fix_ports() {
  local dry_run="false" do_reload="false"
  local arg
  for arg in "$@"; do
    case "${arg}" in
      --dry-run) dry_run="true" ;;
      --reload) do_reload="true" ;;
      --mode=*) ;;
      *)
        plume_err "unknown doctor web fix-ports option: ${arg}"
        return 2
        ;;
    esac
  done
  plume_native_nginx_sync_main_config "${PLUME_NATIVE_NGINX_HTTP_PORT:-80}" "${dry_run}" "${do_reload}"
}

plume_doctor_supervisor_print_line() {
  local name="$1"
  local result="$2"
  local critical="$3"
  local detail="$4"
  if [[ "${result}" == "FAIL" && "${critical}" == "true" ]]; then
    PLUME_DOCTOR_SUPERVISOR_CRITICAL_FAIL=1
  fi
  if [[ "${result}" == "WARN" ]]; then
    PLUME_DOCTOR_SUPERVISOR_NEEDS_UPGRADE=1
  fi
  printf '%-22s %-6s %-8s %s\n' "${name}" "${result}" "${critical}" "${detail}"
}

cmd_doctor_supervisor() {
  local mode strict needs_upgrade="false"
  mode="$(plume_doctor_parse_mode "$@")" || return 2
  strict="false"
  local arg
  for arg in "$@"; do
    case "${arg}" in
      --strict) strict="true" ;;
      --mode=*) ;;
      *)
        plume_err "unknown doctor supervisor option: ${arg}"
        return 2
        ;;
    esac
  done

  PLUME_DOCTOR_SUPERVISOR_CRITICAL_FAIL=0
  PLUME_DOCTOR_SUPERVISOR_NEEDS_UPGRADE=0

  if declare -F plume_host_profile_supervisor_persist >/dev/null 2>&1; then
    plume_host_profile_supervisor_persist || true
  fi

  printf 'MODE              %s\n' "${mode}"
  printf 'STRICT            %s\n' "${strict}"
  echo "CHECK                 RESULT CRITICAL DETAIL"
  echo "---------------------- ------ -------- ----------------------------------------"

  if [[ "${mode}" != "native" ]]; then
    plume_doctor_supervisor_print_line "native-only" "SKIP" "false" "supervisor doctor is native-focused"
    echo "OVERALL               OK"
    return 0
  fi

  local cached_pm cached_runtime schema binary version unit_state legacy
  cached_pm="$(plume_host_profile_read_value package_manager 2>/dev/null || true)"
  cached_runtime="$(plume_host_profile_read_value supervisor_runtime 2>/dev/null || true)"
  if [[ -n "${cached_pm}" ]]; then
    plume_doctor_supervisor_print_line "host-cache" "PASS" "false" "package_manager=${cached_pm} runtime=${cached_runtime:-unknown}"
  else
    plume_doctor_supervisor_print_line "host-cache" "WARN" "false" "host.env cache incomplete — run: init host --force"
  fi

  binary="$(plume_native_supervisor_binary 2>/dev/null || true)"
  if [[ -n "${binary}" ]] && [[ -x "${binary}" ]]; then
    plume_doctor_supervisor_print_line "binary" "PASS" "true" "supervisord: ${binary}"
  else
    plume_doctor_supervisor_print_line "binary" "FAIL" "true" "supervisord not found (brew install supervisor / apt install supervisor)"
  fi

  if [[ -n "${binary}" ]]; then
    version="$(plume_native_supervisor_version_detect 2>/dev/null || true)"
    if [[ -n "${version}" ]]; then
      plume_doctor_supervisor_print_line "version" "PASS" "false" "${version}"
    else
      plume_doctor_supervisor_print_line "version" "WARN" "false" "could not parse supervisord version"
    fi
  fi

  if command -v supervisorctl >/dev/null 2>&1; then
    plume_doctor_supervisor_print_line "supervisorctl" "PASS" "false" "$(command -v supervisorctl)"
  else
    plume_doctor_supervisor_print_line "supervisorctl" "FAIL" "true" "supervisorctl not in PATH"
  fi

  unit_state="$(plume_native_supervisor_system_unit_state 2>/dev/null || true)"
  case "${unit_state}" in
    started|active)
      plume_doctor_supervisor_print_line "system-unit" "PASS" "true" "supervisor ${unit_state}"
      ;;
    stopped|inactive)
      plume_doctor_supervisor_print_line "system-unit" "WARN" "true" "supervisor ${unit_state} — run: services up supervisor"
      ;;
    *)
      plume_doctor_supervisor_print_line "system-unit" "WARN" "false" "state ${unit_state}"
      ;;
  esac

  legacy="false"
  if plume_native_supervisor_legacy_running; then
    legacy="true"
    plume_doctor_supervisor_print_line "legacy-daemon" "WARN" "false" "Plume-owned supervisord still running — migrate: services supervisor upgrade --force --yes"
  else
    plume_doctor_supervisor_print_line "legacy-daemon" "PASS" "false" "no legacy Plume supervisord"
  fi

  if plume_native_supervisor_package_upgrade_available; then
    plume_doctor_supervisor_print_line "package-upgrade" "WARN" "false" "supervisor package upgrade available"
  else
    plume_doctor_supervisor_print_line "package-upgrade" "PASS" "false" "package up to date (or not installed via pm)"
  fi

  schema="$(plume_host_profile_read_value supervisor_config_schema 2>/dev/null || true)"
  if [[ "${schema}" == "${PLUME_SUPERVISOR_CONFIG_SCHEMA:-1}" && "${legacy}" != "true" ]]; then
    plume_doctor_supervisor_print_line "config-schema" "PASS" "false" "schema=${schema}"
  else
    plume_doctor_supervisor_print_line "config-schema" "WARN" "false" "schema=${schema:-missing} or legacy runtime — run upgrade --force"
  fi

  local reg_line reg_name reg_path missing="0" total="0"
  while IFS= read -r reg_line; do
    [[ -z "${reg_line}" ]] && continue
    total=$((total + 1))
    reg_name="${reg_line%%|*}"
    reg_path="${reg_line#*|}"; reg_path="${reg_path%%|*}"
    if [[ ! -f "${reg_path}" ]]; then
      missing=$((missing + 1))
    fi
  done < <(plume_native_supervisor_registry_list 2>/dev/null || true)
  if [[ "${total}" -eq 0 ]]; then
    plume_doctor_supervisor_print_line "programs-registry" "SKIP" "false" "no Plume-managed programs registered"
  elif [[ "${missing}" -gt 0 ]]; then
    plume_doctor_supervisor_print_line "programs-registry" "WARN" "false" "${missing}/${total} registry conf missing on disk"
  else
    plume_doctor_supervisor_print_line "programs-registry" "PASS" "false" "${total} program(s) registered"
  fi

  if [[ "$(plume_service_enabled_for_mode horizon native 2>/dev/null || echo false)" == "true" ]]; then
    local site_id prog_name hst total=0 running=0 fail="false"
    while IFS= read -r site_id; do
      [[ -z "${site_id}" ]] && continue
      total=$((total + 1))
      prog_name="$(plume_native_horizon_program_name_for_site "${site_id}")"
      hst="$(plume_native_supervisor_program_status "${prog_name}" 2>/dev/null || true)"
      if printf '%s' "${hst}" | grep -Eq 'RUNNING|STARTING'; then
        running=$((running + 1))
        plume_doctor_supervisor_print_line "horizon-program:${site_id}" "PASS" "false" "${prog_name} RUNNING"
      elif [[ "${unit_state}" == "started" || "${unit_state}" == "active" ]]; then
        plume_doctor_supervisor_print_line "horizon-program:${site_id}" "WARN" "false" "${prog_name} not RUNNING — plumectl services logs horizon --site=${site_id}; restart: plumectl services restart horizon --site=${site_id}"
      else
        fail="true"
        plume_doctor_supervisor_print_line "horizon-program:${site_id}" "FAIL" "true" "supervisor down; ${prog_name} enabled — plumectl services up supervisor && plumectl services up horizon --site=${site_id}"
      fi
    done < <(plume_native_horizon_resolve_targets 2>/dev/null || true)

    if [[ "${total}" -eq 0 ]]; then
      hst="$(plume_native_supervisor_program_status plume-horizon 2>/dev/null || true)"
      if printf '%s' "${hst}" | grep -Eq 'RUNNING|STARTING'; then
        plume_doctor_supervisor_print_line "horizon-program" "PASS" "false" "plume-horizon RUNNING (legacy)"
      elif [[ "${unit_state}" == "started" || "${unit_state}" == "active" ]]; then
        plume_doctor_supervisor_print_line "horizon-program" "WARN" "false" "plume-horizon not RUNNING — plumectl services logs horizon; plumectl services restart horizon"
      else
        plume_doctor_supervisor_print_line "horizon-program" "FAIL" "true" "supervisor down; horizon enabled — plumectl services up supervisor && plumectl services up horizon"
      fi
    elif [[ "${fail}" == "true" ]]; then
      :
    elif [[ "${running}" -lt "${total}" ]]; then
      :
    fi
  else
    plume_doctor_supervisor_print_line "horizon-program" "SKIP" "false" "horizon not enabled"
  fi

  if plume_native_supervisor_doctor_needs_upgrade; then
    needs_upgrade="true"
    echo "REMEDIATION           run: plumectl services supervisor upgrade --force --yes"
  fi

  if [[ "${PLUME_DOCTOR_SUPERVISOR_CRITICAL_FAIL}" -ne 0 ]]; then
    echo "OVERALL               FAIL"
    if [[ "${strict}" == "true" ]]; then
      return 2
    fi
    return 0
  fi
  echo "OVERALL               OK"
  if [[ "${needs_upgrade}" == "true" && "${strict}" == "true" ]]; then
    return 2
  fi
}

plume_doctor_workspace_print_line() {
  local name="$1"
  local result="$2"
  local critical="$3"
  local detail="$4"
  if [[ "${result}" == "FAIL" && "${critical}" == "true" ]]; then
    PLUME_DOCTOR_WORKSPACE_CRITICAL_FAIL=1
  fi
  printf '%-18s %-6s %-8s %s\n' "${name}" "${result}" "${critical}" "${detail}"
}

cmd_doctor_workspace() {
  local mode strict="false"
  local arg bin path
  mode="$(plume_doctor_parse_mode "$@")" || return 2
  for arg in "$@"; do
    case "${arg}" in
      --strict) strict="true" ;;
      --mode=*) ;;
      *)
        plume_err "unknown doctor workspace option: ${arg}"
        return 2
        ;;
    esac
  done

  PLUME_DOCTOR_WORKSPACE_CRITICAL_FAIL=0

  printf 'MODE              %s\n' "${mode}"
  printf 'STRICT            %s\n' "${strict}"
  echo "CHECK              RESULT CRITICAL DETAIL"
  echo "------------------ ------ -------- ----------------------------------------"

  case "${mode}" in
    native)
      bin="$(plume_workspace_composer_bin 2>/dev/null || echo composer)"
      if command -v "${bin}" >/dev/null 2>&1 || [[ -x "${bin}" ]]; then
        plume_doctor_workspace_print_line "composer" "PASS" "false" "${bin}"
      else
        plume_doctor_workspace_print_line "composer" "WARN" "false" "not in PATH — install Composer or set PLUME_COMPOSER_BIN"
      fi

      bin="$(plume_workspace_npm_bin 2>/dev/null || echo npm)"
      if command -v "${bin}" >/dev/null 2>&1 || [[ -x "${bin}" ]]; then
        plume_doctor_workspace_print_line "npm" "PASS" "false" "${bin}"
      else
        plume_doctor_workspace_print_line "npm" "WARN" "false" "not in PATH — install Node.js or set PLUME_NPM_BIN"
      fi

      bin="$(plume_workspace_node_bin 2>/dev/null || echo node)"
      if command -v "${bin}" >/dev/null 2>&1 || [[ -x "${bin}" ]]; then
        plume_doctor_workspace_print_line "node" "PASS" "false" "${bin}"
      else
        plume_doctor_workspace_print_line "node" "WARN" "false" "not in PATH — install Node.js or set PLUME_NODE_BIN"
      fi

      if declare -F plume_laravel_resolve_php_bin >/dev/null 2>&1 \
        && path="$(plume_laravel_resolve_php_bin 2>/dev/null || true)" \
        && [[ -n "${path}" ]] \
        && { command -v "${path}" >/dev/null 2>&1 || [[ -x "${path}" ]]; }; then
        plume_doctor_workspace_print_line "php-for-composer" "PASS" "false" "${path}"
      else
        plume_doctor_workspace_print_line "php-for-composer" "WARN" "false" "php missing — composer may fail (php list|install)"
      fi

      plume_doctor_workspace_print_line "cli" "PASS" "false" "plumectl composer|npm|node (D-154)"
      ;;
    docker-lite|laradock-bridge)
      plume_doctor_workspace_print_line "workspace" "PASS" "false" "use plumectl composer|npm|node --mode=${mode} (workspace container)"
      ;;
    *)
      plume_doctor_workspace_print_line "mode" "FAIL" "true" "unsupported mode ${mode}"
      ;;
  esac

  if [[ "${PLUME_DOCTOR_WORKSPACE_CRITICAL_FAIL}" -ne 0 ]]; then
    echo "OVERALL            FAIL"
    if [[ "${strict}" == "true" ]]; then
      return 2
    fi
    return 0
  fi
  echo "OVERALL            OK"
}

cmd_doctor() {
  local sub="${1:-check}"
  shift || true
  case "${sub}" in
    check) cmd_doctor_check "$@" ;;
    services) cmd_doctor_services "$@" ;;
    ports) cmd_doctor_ports "$@" ;;
    php) cmd_doctor_php "$@" ;;
    php-ext) cmd_doctor_php_ext "$@" ;;
    web)
      if [[ "${1:-}" == "fix-ports" ]]; then
        shift || true
        cmd_doctor_web_fix_ports "$@"
      else
        cmd_doctor_web "$@"
      fi
      ;;
    supervisor) cmd_doctor_supervisor "$@" ;;
    workspace) cmd_doctor_workspace "$@" ;;
    host) cmd_doctor_host "$@" ;;
    onboarding) cmd_doctor_onboarding "$@" ;;
    *)
      plume_err "unknown doctor subcommand: ${sub} (use check|services|ports|php|php-ext|web|web fix-ports|supervisor|workspace|host|onboarding)"
      return 2
      ;;
  esac
}
